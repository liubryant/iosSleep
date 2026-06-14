import AppTrackingTransparency
import Foundation

@MainActor
final class AppSDKManager: ObservableObject {
    static let shared = AppSDKManager()

    private var didStartSDKFlow = false

    private init() {}

    /// 启动三方 SDK。合规要求：只能在用户同意《用户协议》《隐私政策》后调用。
    func startIfAllowed(showSplash: Bool = true, completion: (() -> Void)? = nil) {
        guard ConsentStore.agreementAccepted else {
            completion?()
            return
        }
        guard !didStartSDKFlow else {
            completion?()
            return
        }
        didStartSDKFlow = true

        requestTrackingAuthorizationIfNeeded { [weak self] in
            guard self != nil else { return }
            UMengAnalytics.shared.initialize()
            PangleAdManager.shared.initialize { success in
                guard showSplash, success else {
                    completion?()
                    return
                }
                DispatchQueue.main.async {
                    PangleSplashAdManager.shared.loadAndShowDefaultSplashAd { shown, error in
                        if let error {
                            print("Splash ad failed: \(error.localizedDescription)")
                        } else {
                            print("Splash ad shown: \(shown)")
                        }
                        completion?()
                    }
                }
            }
        }
    }

    private func requestTrackingAuthorizationIfNeeded(completion: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async(execute: completion)
        }
    }
}
