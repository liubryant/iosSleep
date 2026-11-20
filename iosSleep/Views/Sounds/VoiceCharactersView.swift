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

    private static let pageStrings: [String] = [
    "专注练习",
    "专注自身",
    "了解每一种声音的陪伴方式",
    "云舟",
    "云舟的动漫人物肖像",
    "亲切 · 包容 · 有陪伴感",
    "人物分类",
    "他的声音从夜色深处缓缓靠近，低沉却不压迫。悠长的节奏会将思绪带离喧闹，进入更安静的层次。",
    "他的声音像穿过山林的深缓河流，稳定而有力量。跟随低沉的节奏，你可以逐渐松开身体里积存的压力。",
    "全部",
    "压力释放",
    "向下滑动，遇见声音背后的他们",
    "呼吸觉察",
    "声音人物",
    "夜间冥想",
    "夜间陪伴",
    "她像一朵正在安静舒展的花，话语里有柔软的微笑。无论你今天是否完美，都能在她的声音里被温柔接住。",
    "她像一盏始终为你亮着的暖灯，不评判此刻的疲惫，也不要求你马上振作，只温柔地陪你找回稳定。",
    "她像清晨穿过林间的溪流，清亮而柔软。每一次停顿都留有空气，让情绪在自然的节奏里重新舒展。",
    "她带着清晨阳光般的明亮，却没有刺眼的急促。适度的活力会帮你理清思绪，把注意力带回正在做的事。",
    "她的声音像一叶停在静水上的小舟，柔和而平稳。你可以把纷乱暂时放下，让注意力跟着她缓缓靠岸。",
    "她的声音像月光落在枕边，不催促，也不打扰，只在夜色渐深时陪你慢慢卸下一天的重量。",
    "她的声音利落、清晰，带着恰到好处的朝气。适合想要摆脱倦意、重新关注自己和当下行动的时刻。",
    "妮",
    "妮的动漫人物肖像",
    "安心 · 柔美 · 呼吸感强",
    "安心声线",
    "安禾",
    "安禾的动漫人物肖像",
    "工作卸压",
    "建立安全感",
    "快速入睡",
    "情绪疗愈",
    "想象冥想",
    "愿每个夜晚，都有合适的声音陪你",
    "慢下来的声音",
    "找到陪你",
    "接纳不完美",
    "日间专注",
    "日间提神",
    "时光睡眠 · 声音人物图鉴",
    "时光睡眠 · 正念冥想声音人物图鉴",
    "明亮 · 柔和 · 有活力",
    "星遥",
    "星遥的动漫人物肖像",
    "林溪",
    "林溪的动漫人物肖像",
    "柔润治愈",
    "正念冥想",
    "每一道声音都有自己的温度与节奏。认识他们，也找到此刻最适合你的陪伴。",
    "沉稳 · 低缓 · 有安全感",
    "沉稳声线",
    "沐川",
    "沐川的动漫人物肖像",
    "深夜声线",
    "深度冥想",
    "深度睡眠",
    "深邃 · 磁性 · 节奏缓慢",
    "清澈 · 自然 · 呼吸感强",
    "清醒能量",
    "温暖陪伴",
    "温柔 · 轻缓 · 贴近耳边",
    "焦虑缓解",
    "疗愈放松",
    "睡前放松",
    "睡眠陪伴",
    "知夏",
    "知夏的动漫人物肖像",
    "空灵 · 宁静 · 中性柔声",
    "空灵声线",
    "细腻 · 柔润 · 带温暖微笑感",
    "自我关怀",
    "自然冥想",
    "自然声线",
    "舸",
    "舸的动漫人物肖像",
    "花蕊",
    "花蕊的动漫人物肖像",
    "观月",
    "观月的动漫人物肖像",
    "认识声音的气质，选择更适合此刻的陪伴",
    "身体扫描",
    "轻快 · 响亮 · 有活力",
    "轻快声线",
    "返回",
    "返回顶部",
    "这道声音像遥远星光落入意识的边缘，轻盈、中性而开阔。它为想象留出空间，也让呼吸变得清晰可见。"
]

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let translations = Dictionary(uniqueKeysWithValues: Self.pageStrings.map { ($0, SleepL10n.text($0)) })
        if let data = try? JSONSerialization.data(withJSONObject: translations),
           let dictionary = String(data: data, encoding: .utf8) {
            let language = Locale.preferredLanguages.first ?? "zh-Hans"
            let direction = Locale.characterDirection(forLanguage: language) == .rightToLeft ? "rtl" : "ltr"
            let script = """
            const translations = \(dictionary);
            document.documentElement.dir = '\(direction)';
            const applyTranslations = () => {
                const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                while (walker.nextNode()) {
                    const node = walker.currentNode;
                    if (['SCRIPT', 'STYLE'].includes(node.parentElement.tagName)) continue;
                    const value = node.nodeValue.trim();
                    if (translations[value] && translations[value] !== value) node.nodeValue = translations[value];
                }
            };
            applyTranslations();
            new MutationObserver(applyTranslations).observe(document.body, {childList: true, subtree: true});
            """
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }

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
                SleepL10n.text("<meta name='viewport' content='width=device-width'><p style='padding:40px;font:16px -apple-system;color:#555'>人物介绍页面暂时无法打开</p>"),
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
