import Foundation
import AVFoundation
import SwiftUI
import UIKit
import WebKit

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
            slot.adType = .feed
            slot.position = .feed
            slot.imgSize = BUSize(by: .feed690_388)
            slot.mediation.mutedIfCan = true
            slot.ext = [BUMAdLoadingParamNAIsMute: true]

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
        muteAdMedia(in: view)
        adView = view
        print("csjad draw_feed_load_success slotID=\(slotID)")
    }

    func nativeExpressAdFail(toLoad nativeExpressAdManager: BUNativeExpressAdManager, error: Error?) {
        isHidden = true
        print("csjad draw_feed_load_fail slotID=\(slotID), error=\(error?.localizedDescription ?? "unknown")")
    }

    @objc(nativeExpressAdViewRenderSuccess:)
    func nativeExpressAdViewRenderSuccess(_ nativeExpressAdView: BUNativeExpressAdView) {
        muteAdMedia(in: nativeExpressAdView)
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

    private func muteAdMedia(in view: UIView) {
        muteLayers(in: view.layer)
        muteWebVideo(in: view)
        view.subviews.forEach { muteAdMedia(in: $0) }
    }

    private func muteLayers(in layer: CALayer) {
        if let playerLayer = layer as? AVPlayerLayer {
            playerLayer.player?.isMuted = true
            playerLayer.player?.volume = 0
        }
        layer.sublayers?.forEach { muteLayers(in: $0) }
    }

    private func muteWebVideo(in view: UIView) {
        guard let webView = view as? WKWebView else { return }
        let script = """
        document.querySelectorAll('video,audio').forEach(function(media) {
            media.muted = true;
            media.volume = 0;
        });
        """
        webView.evaluateJavaScript(script)
    }
}
#endif
