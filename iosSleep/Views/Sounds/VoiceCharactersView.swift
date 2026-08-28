import SwiftUI
import WebKit

struct VoiceCharactersView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VoiceCharactersWebView(onClose: { dismiss() })
            .ignoresSafeArea()
            .appEdgeSwipeBack()
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
    }
}

private struct VoiceCharactersWebView: UIViewRepresentable {
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 247 / 255, green: 246 / 255, blue: 251 / 255, alpha: 1)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        if let pageURL = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "VoiceCharacters"
        ) {
            webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(
                "<meta name='viewport' content='width=device-width'><p style='padding:40px;font:16px -apple-system;color:#555'>人物介绍页面暂时无法打开</p>",
                baseURL: nil
            )
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onClose: () -> Void

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.request.url?.scheme == "timesleep" {
                decisionHandler(.cancel)
                onClose()
                return
            }

            decisionHandler(.allow)
        }
    }
}
