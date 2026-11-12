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
    struct Presentation {
        let view: UIView
        let size: CGSize
        let isTemplate: Bool
    }

    @Published private(set) var presentation: Presentation?
    @Published var isHidden = false

    private let slotID: String
    private var didRequest = false
    private var requestedWidth: CGFloat = 0
    private let cardHeight: CGFloat = 164

    #if canImport(BUAdSDK)
    private var nativeManager: BUNativeAdsManager?
    private var nativeAd: BUNativeAd?
    private var templateManager: BUNativeExpressAdManager?
    private var templateView: BUNativeExpressAdView?
    #endif

    init(slotID: String = AppConstants.drawFeedSlotID) {
        self.slotID = slotID
        super.init()
    }

    func loadIfNeeded(width: CGFloat) {
        guard !didRequest, !isHidden, width.isFinite, width > 0 else { return }
        guard ConsentStore.agreementAccepted, !AppConstants.isAdDisabled else {
            isHidden = true
            return
        }
        didRequest = true
        requestedWidth = width

        #if canImport(BUAdSDK)
        if PangleAdManager.shared.isSDKInitialized() {
            loadNative()
        } else {
            PangleAdManager.shared.initialize { [weak self] success in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if success { self.loadNative() } else { self.isHidden = true }
                }
            }
        }
        #else
        isHidden = true
        #endif
    }
}

#if canImport(BUAdSDK)
extension PangleDrawFeedAdLoader: @preconcurrency BUMNativeAdsManagerDelegate, @preconcurrency BUNativeExpressAdViewDelegate, BUCustomEventProtocol {
    private func makeSlot() -> BUAdSlot {
        let slot = BUAdSlot()
        slot.id = slotID
        slot.adType = .feed
        slot.position = .feed
        let imageSize = BUSize(by: .feed690_388)
        slot.imgSize = imageSize
        slot.imgSizeArray = [imageSize]
        slot.mediation.mutedIfCan = true
        slot.ext = [
            BUMAdLoadingParamNAIsMute: true,
            BUMAdLoadingParamIsClickable: true
        ]
        return slot
    }

    private func loadNative() {
        let slot = makeSlot()
        slot.adSize = CGSize(width: requestedWidth, height: cardHeight)
        let iconSize = BUSize()
        iconSize.width = 100
        iconSize.height = 100
        slot.iconSize = iconSize
        let manager = BUNativeAdsManager(slot: slot)
        manager.adSize = slot.adSize
        if let presenter = PangleAdRootViewController.current() {
            manager.mediation?.rootViewController = presenter
        }
        manager.delegate = self
        nativeManager = manager
        manager.loadAdData(withCount: 1)
    }

    private func hideAd(reason: String) {
        isHidden = true
        presentation = nil
        nativeAd?.unregisterView()
        nativeAd = nil
        let previousManager = nativeManager
        nativeManager = nil
        previousManager?.mediation?.destory()
        print("csjad draw_feed_hidden slotID=\(slotID), reason=\(reason)")
    }

    private func loadTemplate(reason: String) {
        guard templateManager == nil, !isHidden else { return }
        presentation = nil
        nativeAd?.unregisterView()
        nativeAd = nil
        let previousManager = nativeManager
        nativeManager = nil
        previousManager?.mediation?.destory()

        print("csjad draw_feed_template_fallback slotID=\(slotID), reason=\(reason)")
        let manager = BUNativeExpressAdManager(
            slot: makeSlot(), adSize: CGSize(width: requestedWidth, height: 0)
        )
        manager.delegate = self
        templateManager = manager
        manager.loadAdData(withCount: 1)
    }

    func nativeAdsManagerSuccess(toLoad adsManager: BUNativeAdsManager, nativeAds: [BUNativeAd]?) {
        guard nativeManager === adsManager else { return }
        guard let ad = nativeAds?.first, let mediation = ad.mediation,
              !mediation.isExpressAd, mediation.isReady else {
            loadTemplate(reason: "No ready self-rendered creative")
            return
        }

        let canvas = mediation.canvasView
        guard canvas.hasSupportActionBtn, configure(canvas) else {
            loadTemplate(reason: "Creative does not provide display media and a configurable CTA")
            return
        }
        nativeAd = ad
        ad.rootViewController = PangleAdRootViewController.current()
        ad.registerContainer(canvas, withClickableViews: [canvas.callToActionBtn])
        canvas.registerClickableViews([canvas.callToActionBtn])
        presentation = Presentation(
            view: canvas,
            size: CGSize(width: requestedWidth, height: cardHeight),
            isTemplate: false
        )
    }

    func nativeAdsManager(_ adsManager: BUNativeAdsManager, didFailWithError error: Error?) {
        guard nativeManager === adsManager else { return }
        loadTemplate(reason: error?.localizedDescription ?? "Native ad load failed")
    }

    private func configure(_ canvas: BUMCanvasView) -> Bool {
        guard let data = canvas.data else { return false }
        let video = canvas.mediaView
        let imageURL = data.imageAry?.first?.imageURL.flatMap { URL(string: $0) }
        guard video != nil || imageURL != nil || canvas.imageView.image != nil else { return false }

        canvas.backgroundColor = UIColor(white: 0.10, alpha: 1)
        let mediaArea = UIView()
        mediaArea.backgroundColor = .black
        let media = video ?? canvas.imageView
        canvas.imageView.contentMode = .scaleAspectFit
        media.contentMode = .scaleAspectFit
        media.clipsToBounds = true
        muteAdMedia(in: media)

        let title = canvas.titleLabel
        title.text = data.adTitle
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .white
        title.numberOfLines = 2

        let detail = canvas.descLabel
        detail.text = data.adDescription
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = UIColor(white: 0.70, alpha: 1)
        detail.numberOfLines = 2

        let button = canvas.callToActionBtn
        button.setTitle("查看详情", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.backgroundColor = UIColor(white: 0.18, alpha: 1)
        button.layer.cornerRadius = 8

        let details = UIStackView(arrangedSubviews: [title, detail, button])
        details.axis = .vertical
        details.spacing = 8
        details.setCustomSpacing(12, after: detail)
        [mediaArea, details].forEach {
            canvas.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        mediaArea.addSubview(media)
        media.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mediaArea.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            mediaArea.topAnchor.constraint(equalTo: canvas.topAnchor),
            mediaArea.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
            mediaArea.widthAnchor.constraint(equalTo: canvas.widthAnchor, multiplier: 0.56),
            details.leadingAnchor.constraint(equalTo: mediaArea.trailingAnchor, constant: 12),
            details.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -12),
            details.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),
            details.topAnchor.constraint(greaterThanOrEqualTo: canvas.topAnchor, constant: 8),
            details.bottomAnchor.constraint(lessThanOrEqualTo: canvas.bottomAnchor, constant: -8),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])

        if video != nil {
            // Give the SDK video the creative's aspect ratio so its player does not crop.
            let width = data.videoResolutionWidth
            let height = data.videoResolutionHeight
            let isPortrait = data.imageMode.rawValue == 15 || data.imageMode.rawValue == 2002
            let ratio = width > 0 && height > 0 ? CGFloat(width) / CGFloat(height) : (isPortrait ? 9.0 / 16.0 : 16.0 / 9.0)
            let fillWidth = media.widthAnchor.constraint(equalTo: mediaArea.widthAnchor)
            fillWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                media.centerXAnchor.constraint(equalTo: mediaArea.centerXAnchor),
                media.centerYAnchor.constraint(equalTo: mediaArea.centerYAnchor),
                media.widthAnchor.constraint(lessThanOrEqualTo: mediaArea.widthAnchor),
                media.heightAnchor.constraint(lessThanOrEqualTo: mediaArea.heightAnchor),
                media.widthAnchor.constraint(equalTo: media.heightAnchor, multiplier: ratio),
                fillWidth
            ])
        } else {
            NSLayoutConstraint.activate([
                media.leadingAnchor.constraint(equalTo: mediaArea.leadingAnchor),
                media.trailingAnchor.constraint(equalTo: mediaArea.trailingAnchor),
                media.topAnchor.constraint(equalTo: mediaArea.topAnchor),
                media.bottomAnchor.constraint(equalTo: mediaArea.bottomAnchor)
            ])
            if let imageURL, canvas.imageView.image == nil {
                URLSession.shared.dataTask(with: imageURL) { [weak self, weak imageView = canvas.imageView] bytes, _, _ in
                    let image = bytes.flatMap { UIImage(data: $0) }
                    DispatchQueue.main.async {
                        guard let self, let imageView else { return }
                        if let image {
                            imageView.image = image
                        } else {
                            self.loadTemplate(reason: "Creative image could not be loaded")
                        }
                    }
                }.resume()
            }
        }
        return true
    }

    func nativeExpressAdSuccess(toLoad manager: BUNativeExpressAdManager, views: [BUNativeExpressAdView]) {
        guard templateManager === manager, !isHidden else { return }
        guard let view = views.first else {
            hideAd(reason: "Template response was empty")
            return
        }
        templateView = view
        view.rootViewController = PangleAdRootViewController.current()
        view.render()
    }

    func nativeExpressAdFail(toLoad manager: BUNativeExpressAdManager, error: Error?) {
        guard templateManager === manager else { return }
        hideAd(reason: error?.localizedDescription ?? "Template ad load failed")
    }

    func nativeExpressAdViewRenderSuccess(_ view: BUNativeExpressAdView) {
        guard templateView === view, !isHidden else { return }
        let size = view.bounds.size
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            hideAd(reason: "Template rendered without a usable size")
            return
        }
        muteAdMedia(in: view)
        presentation = Presentation(view: view, size: size, isTemplate: true)
        print("csjad draw_feed_template_render_success slotID=\(slotID)")
    }

    func nativeExpressAdViewRenderFail(_ view: BUNativeExpressAdView, error: Error?) {
        guard templateView === view else { return }
        hideAd(reason: error?.localizedDescription ?? "Template ad render failed")
    }

    func nativeExpressAdView(_ view: BUNativeExpressAdView, dislikeWithReason filterWords: [BUDislikeWords]) {
        guard templateView === view else { return }
        presentation = nil
        templateView = nil
        isHidden = true
    }

    private func muteAdMedia(in view: UIView) {
        if let mediaView = view as? BUMediaAdView {
            // 信息流视频区域应响应广告点击，不作为播放/暂停控制器。
            mediaView.drawVideoClickEnable = false
        }
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
