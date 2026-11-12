import SwiftUI
import UIKit

struct DrawFeedAdCardView: View {
    @StateObject private var loader = PangleDrawFeedAdLoader()

    var body: some View {
        Group {
            if loader.isHidden {
                EmptyView()
            } else {
                GeometryReader { proxy in
                    Group {
                        if let presentation = loader.presentation {
                            NativeAdRepresentable(presentation: presentation)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topLeading) {
                                    Text("广告")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.black.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                    .onAppear {
                        loader.loadIfNeeded(width: max(proxy.size.width, 150))
                    }
                }
                .aspectRatio(adAspectRatio, contentMode: .fit)
            }
        }
    }

    private var adAspectRatio: CGFloat {
        guard let size = loader.presentation?.size else { return 2.2 }
        return size.width / size.height
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let presentation: PangleDrawFeedAdLoader.Presentation

    func makeUIView(context: Context) -> AdContainerView {
        AdContainerView()
    }

    func updateUIView(_ uiView: AdContainerView, context: Context) {
        uiView.show(presentation)
    }
}

private final class AdContainerView: UIView {
    private var presentation: PangleDrawFeedAdLoader.Presentation?

    func show(_ presentation: PangleDrawFeedAdLoader.Presentation) {
        guard self.presentation?.view !== presentation.view else { return }
        self.presentation?.view.removeFromSuperview()
        self.presentation = presentation
        clipsToBounds = true
        addSubview(presentation.view)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let presentation, bounds.width > 0, bounds.height > 0 else { return }
        let adView = presentation.view
        if presentation.isTemplate {
            let size = presentation.size
            let scale = min(bounds.width / size.width, bounds.height / size.height)
            adView.bounds.size = size
            adView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            adView.transform = CGAffineTransform(scaleX: scale, y: scale)
        } else {
            adView.frame = bounds
        }
    }
}
