import Foundation
import SwiftUI
import UIKit

#if canImport(BUAdSDK)
import BUAdSDK
#endif

@MainActor
final class PangleDrawFeedAdLoader: NSObject, ObservableObject {
    @Published var adView: UIView?
    @Published var isHidden = false

    private let slotID: String

    #if canImport(BUAdSDK)
    private var manager: BUNativeExpressAdManager?
    #endif

    init(slotID: String = AppConstants.drawFeedSlotID) {
        self.slotID = slotID
        super.init()
    }

    func loadIfNeeded(width: CGFloat) {
        guard adView == nil, !isHidden else { return }
        guard ConsentStore.agreementAccepted, !AppConstants.isAdDisabled else { return }

        #if canImport(BUAdSDK)
        let startLoad = { [weak self] in
            guard let self else { return }
            let slot = BUAdSlot()
            slot.id = self.slotID
            slot.adType = .drawVideo
            slot.position = .feed
            slot.imgSize = BUSize(by: .feed690_388)

            let manager = BUNativeExpressAdManager(slot: slot, adSize: CGSize(width: width, height: 0))
            manager.delegate = self
            self.manager = manager
            manager.loadAdData(withCount: 1)
            print("csjad draw_feed_load_start slotID=\(self.slotID)")
        }

        if PangleAdManager.shared.isSDKInitialized() {
            startLoad()
        } else {
            PangleAdManager.shared.initialize { success in
                guard success else { return }
                DispatchQueue.main.async(execute: startLoad)
            }
        }
        #endif
    }
}

#if canImport(BUAdSDK)
extension PangleDrawFeedAdLoader: BUNativeExpressAdViewDelegate, BUCustomEventProtocol {
    func nativeExpressAdSuccess(toLoad nativeExpressAdManager: BUNativeExpressAdManager, views: [BUNativeExpressAdView]) {
        guard let view = views.first else { return }
        view.rootViewController = PangleAdRootViewController.current()
        view.render()
        adView = view
        print("csjad draw_feed_load_success slotID=\(slotID)")
    }

    func nativeExpressAdFail(toLoad nativeExpressAdManager: BUNativeExpressAdManager, error: Error?) {
        isHidden = true
        print("csjad draw_feed_load_fail slotID=\(slotID), error=\(error?.localizedDescription ?? "unknown")")
    }

    @objc(nativeExpressAdViewRenderSuccess:)
    func nativeExpressAdViewRenderSuccess(_ nativeExpressAdView: BUNativeExpressAdView) {
        adView = nativeExpressAdView
    }

    @objc(nativeExpressAdViewRenderFail:error:)
    func nativeExpressAdViewRenderFail(_ nativeExpressAdView: BUNativeExpressAdView, error: Error?) {
        isHidden = true
        print("csjad draw_feed_render_fail slotID=\(slotID), error=\(error?.localizedDescription ?? "unknown")")
    }

    @objc(nativeExpressAdView:dislikeWithReason:)
    func nativeExpressAdView(_ nativeExpressAdView: BUNativeExpressAdView, dislikeWithReason filterWords: [BUDislikeWords]?) {
        isHidden = true
        adView = nil
    }
}
#endif
