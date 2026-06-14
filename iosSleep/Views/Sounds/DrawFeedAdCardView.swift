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
                        if let adView = loader.adView {
                            NativeAdRepresentable(adView: adView)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topLeading) {
                                    Text("广告")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.black.opacity(0.35))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
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
                .aspectRatio(1.52, contentMode: .fit)
            }
        }
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let adView: UIView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.addSubview(adView)
        adView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            adView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            adView.topAnchor.constraint(equalTo: container.topAnchor),
            adView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
