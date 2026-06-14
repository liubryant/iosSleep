import Foundation
import UIKit

#if canImport(BUAdSDK)
import BUAdSDK
#endif

final class PangleSplashAdManager: NSObject {
    static let shared = PangleSplashAdManager()

    #if canImport(BUAdSDK)
    private var splashAd: BUSplashAd?
    #endif

    private var isLoading = false
    private var didRequestSplashThisSession = false
    private var completionHandler: ((Bool, Error?) -> Void)?

    var shouldRequestSplashThisSession: Bool {
        !didRequestSplashThisSession && !isLoading
    }

    private override init() {
        super.init()
    }

    func resetSplashRequestState() {
        didRequestSplashThisSession = false
    }

    func cancelSplashAd() {
        isLoading = false
        completionHandler = nil
        #if canImport(BUAdSDK)
        splashAd?.mediation?.destoryAd()
        splashAd = nil
        #endif
    }

    func loadAndShowDefaultSplashAd(completion: ((Bool, Error?) -> Void)? = nil) {
        loadAndShowSplashAd(slotID: AppConstants.splashSlotID, completion: completion)
    }

    func loadAndShowSplashAd(
        slotID: String,
        tolerateTimeout: TimeInterval = 3.0,
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        guard ConsentStore.agreementAccepted else {
            completion?(false, nil)
            return
        }
        guard shouldRequestSplashThisSession else {
            completion?(false, nil)
            return
        }
        guard !AppConstants.isAdDisabled else {
            didRequestSplashThisSession = true
            completion?(false, nil)
            return
        }

        #if canImport(BUAdSDK)
        guard PangleAdManager.shared.isSDKInitialized() else {
            PangleAdManager.shared.initialize { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.loadAndShowSplashAd(slotID: slotID, tolerateTimeout: tolerateTimeout, completion: completion)
                    } else {
                        let error = NSError(domain: "PangleSplashAdManager", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "GroMore SDK 初始化失败"
                        ])
                        completion?(false, error)
                    }
                }
            }
            return
        }

        guard !isLoading else { return }
        didRequestSplashThisSession = true
        isLoading = true
        completionHandler = completion

        print("csjad splash_load_start appID=\(AppConstants.pangleAppID), slotID=\(slotID), timeout=\(tolerateTimeout)")
        let slotAd = BUAdSlot()
        slotAd.id = slotID
        splashAd = BUSplashAd(slot: slotAd, adSize: UIScreen.main.bounds.size)
        splashAd?.delegate = self
        splashAd?.tolerateTimeout = tolerateTimeout
        splashAd?.loadData()
        #else
        didRequestSplashThisSession = true
        let error = NSError(domain: "PangleSplashAdManager", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "GroMore SDK 未安装，请先执行 pod install"
        ])
        completion?(false, error)
        #endif
    }

    private func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }
}

#if canImport(BUAdSDK)
extension PangleSplashAdManager: BUMSplashAdDelegate {
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        guard let root = rootViewController() else {
            isLoading = false
            let error = NSError(domain: "PangleSplashAdManager", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "未找到 rootViewController"
            ])
            completionHandler?(false, error)
            completionHandler = nil
            return
        }
        splashAd.showSplashView(inRootViewController: root)
    }

    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        isLoading = false
        print("csjad splash_load_fail appID=\(AppConstants.pangleAppID), slotID=\(AppConstants.splashSlotID), code=\(error?.code ?? -1), error=\(error?.localizedDescription ?? "unknown")")
        let nsError = NSError(domain: "PangleSplashAdManager", code: Int(error?.code ?? -1), userInfo: [
            NSLocalizedDescriptionKey: error?.localizedDescription ?? "开屏广告加载失败"
        ])
        completionHandler?(false, nsError)
        completionHandler = nil
    }

    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {}

    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        isLoading = false
        completionHandler?(false, error)
        completionHandler = nil
    }

    func splashAdWillShow(_ splashAd: BUSplashAd) {}

    func splashAdDidShow(_ splashAd: BUSplashAd) {
        isLoading = false
    }

    func splashAdDidClick(_ splashAd: BUSplashAd) {}

    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        isLoading = false
        splashAd.mediation?.destoryAd()
        self.splashAd = nil
        completionHandler?(true, nil)
        completionHandler = nil
    }

    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {}

    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {}

    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {}

    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
        isLoading = false
        completionHandler?(false, error)
        completionHandler = nil
    }
}
#endif
