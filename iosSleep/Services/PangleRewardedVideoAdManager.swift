import Foundation
import UIKit

#if canImport(BUAdSDK)
import BUAdSDK
#endif

@MainActor
final class PangleRewardedVideoAdManager: NSObject {
    static let shared = PangleRewardedVideoAdManager()

    #if canImport(BUAdSDK)
    private var rewardedAd: BUNativeExpressRewardedVideoAd?
    #endif

    private var completion: ((Bool) -> Void)?
    private var didGrantReward = false

    private override init() {
        super.init()
    }

    func showForRecordingAccess(completion: @escaping (Bool) -> Void) {
        guard ConsentStore.agreementAccepted, !AppConstants.isAdDisabled else {
            completion(true)
            return
        }

        self.completion = completion
        didGrantReward = false

        #if canImport(BUAdSDK)
        let startLoad = { [weak self] in
            guard let self else { return }

            let model = BURewardedVideoModel()
            model.userId = "timesleep-user"

            let ad = BUNativeExpressRewardedVideoAd(slotID: AppConstants.rewardedVideoSlotID, rewardedVideoModel: model)
            ad.delegate = self
            self.rewardedAd = ad
            ad.loadData()
            print("csjad reward_load_start slotID=\(AppConstants.rewardedVideoSlotID)")
        }

        if PangleAdManager.shared.isSDKInitialized() {
            startLoad()
        } else {
            PangleAdManager.shared.initialize { [weak self] success in
                guard let self else { return }
                guard success else {
                    DispatchQueue.main.async {
                        self.finish(granted: false)
                    }
                    return
                }
                DispatchQueue.main.async(execute: startLoad)
            }
        }
        #else
        completion(true)
        #endif
    }

    private func finish(granted: Bool) {
        completion?(granted)
        completion = nil
        rewardedAd = nil
        didGrantReward = false
    }
}

#if canImport(BUAdSDK)
extension PangleRewardedVideoAdManager: BUMNativeExpressRewardedVideoAdDelegate {
    @objc(nativeExpressRewardedVideoAdDidLoad:)
    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("csjad reward_load_success slotID=\(AppConstants.rewardedVideoSlotID)")
    }

    @objc(nativeExpressRewardedVideoAdDidDownLoadVideo:)
    func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        guard let root = PangleAdRootViewController.current() else {
            finish(granted: false)
            return
        }

        if rewardedVideoAd.mediation?.isReady == false {
            finish(granted: false)
            return
        }

        _ = rewardedVideoAd.show(fromRootViewController: root)
    }

    @objc(nativeExpressRewardedVideoAd:didFailWithError:)
    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        print("csjad reward_load_fail slotID=\(AppConstants.rewardedVideoSlotID), error=\(error?.localizedDescription ?? "unknown")")
        finish(granted: false)
    }

    @objc(nativeExpressRewardedVideoAdDidClickSkip:)
    func nativeExpressRewardedVideoAdDidClickSkip(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        didGrantReward = true
    }

    @objc(nativeExpressRewardedVideoAdDidPlayFinish:didFailWithError:)
    func nativeExpressRewardedVideoAdDidPlayFinish(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        didGrantReward = true
    }

    @objc(nativeExpressRewardedVideoAdDidClose:)
    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        finish(granted: didGrantReward)
    }

    @objc(nativeExpressRewardedVideoAdDidShowFailed:error:)
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
        print("csjad reward_show_fail slotID=\(AppConstants.rewardedVideoSlotID), error=\(error.localizedDescription)")
        finish(granted: false)
    }
}
#endif
