import Foundation

#if canImport(BUAdSDK)
import BUAdSDK
#endif

final class PangleAdManager {
    static let shared = PangleAdManager()

    private var isInitialized = false
    private var isInitializing = false
    private var pendingCallbacks: [(Bool) -> Void] = []

    private init() {}

    /// 初始化 GroMore/穿山甲。合规要求：只能在用户同意《用户协议》《隐私政策》后调用。
    func initialize(completion: ((Bool) -> Void)? = nil) {
        guard ConsentStore.agreementAccepted else {
            completion?(false)
            return
        }
        guard !isInitialized else {
            completion?(true)
            return
        }

        if let completion {
            pendingCallbacks.append(completion)
        }

        guard !isInitializing else { return }
        isInitializing = true

        #if canImport(BUAdSDK)
        let configuration = BUAdSDKConfiguration()
        configuration.appID = AppConstants.pangleAppID
        configuration.themeStatus = NSNumber(integerLiteral: 0)
        configuration.useMediation = true
        configuration.mediation.limitPersonalAds = NSNumber(integerLiteral: 0)
        configuration.mediation.limitProgrammaticAds = NSNumber(integerLiteral: 0)
        configuration.mediation.forbiddenIDFA = NSNumber(integerLiteral: 0)

        #if DEBUG
        configuration.sdkdebug = true
        configuration.debugLog = NSNumber(value: 1)
        #endif

        print("csjad sdk_start appID=\(AppConstants.pangleAppID), useMediation=true")
        BUAdSDKManager.start(asyncCompletionHandler: { [weak self] success, error in
            if success {
                self?.isInitialized = true
                print("csjad sdk_init_success appID=\(AppConstants.pangleAppID), sdkVersion=\(BUAdSDKManager.sdkVersion)")
            } else {
                print("csjad sdk_init_fail appID=\(AppConstants.pangleAppID), error=\(error?.localizedDescription ?? "unknown")")
            }
            self?.finishPendingCallbacks(success: success)
        })
        #else
        print("GroMore SDK is not installed. Run pod install first.")
        finishPendingCallbacks(success: false)
        #endif
    }

    func isSDKInitialized() -> Bool {
        isInitialized
    }

    private func finishPendingCallbacks(success: Bool) {
        isInitializing = false
        let callbacks = pendingCallbacks
        pendingCallbacks.removeAll()
        callbacks.forEach { $0(success) }
    }
}
