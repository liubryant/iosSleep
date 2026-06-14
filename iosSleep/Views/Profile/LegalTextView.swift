import SwiftUI
import WebKit

struct LegalTextView: View {
    let title: String
    let url: URL

    var body: some View {
        WebPageView(url: url)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebPageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

struct PrivacyAgreementView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var isChecked = false
    @State private var showMustCheckAlert = false
    @State private var showDisagreeAlert = false
    @State private var presentedLegal: LegalDestination?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("个人信息保护")
                    .font(.title3.weight(.semibold))

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("欢迎使用时光睡眠。我们非常重视您的个人信息与隐私保护。请您在使用前仔细阅读以下协议，了解我们如何为您提供睡眠监测、声音播放、HealthKit 数据同步等服务。")
                            .padding(.top, 8)
                        HStack(spacing: 0) {
                            Button("《用户协议》") {
                                presentedLegal = .agreement
                            }
                            .foregroundStyle(.blue)

                            Text(" 和 ")
                                .foregroundStyle(.primary)

                            Button("《隐私政策》") {
                                presentedLegal = .privacy
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        Text("在您点击“同意并继续”前，我们不会主动请求麦克风、HealthKit 等敏感权限，也不会开始睡眠声音监测。")
                        Text("您可以点击上方蓝色协议名称查看完整内容。若您不同意相关条款，将无法继续使用本应用。")
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 220, maxHeight: 320)

                Toggle(isOn: $isChecked) {
                    Text("我已阅读并同意《用户协议》和《隐私政策》")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkboxLike)

                Button {
                    guard isChecked else {
                        showMustCheckAlert = true
                        return
                    }
                    settings.acceptAgreement()
                } label: {
                    Text("同意并继续")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("不同意") {
                    showDisagreeAlert = true
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(24)
        }
        .sheet(item: $presentedLegal) { item in
            NavigationStack {
                LegalTextView(title: item.title, url: item.url)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") {
                                presentedLegal = nil
                            }
                        }
                    }
            }
        }
        .alert("提示", isPresented: $showMustCheckAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请先阅读并勾选同意《用户协议》和《隐私政策》。")
        }
        .alert("提示", isPresented: $showDisagreeAlert) {
            Button("查看协议", role: .cancel) {
                presentedLegal = .agreement
            }
            Button("退出App", role: .destructive) {
                exit(0)
            }
        } message: {
            Text("您需要同意《用户协议》和《隐私政策》后才能使用时光睡眠。")
        }
    }

}

private enum LegalDestination: Identifiable {
    case agreement
    case privacy

    var id: String {
        switch self {
        case .agreement: return "agreement"
        case .privacy: return "privacy"
        }
    }

    var title: String {
        switch self {
        case .agreement: return "用户协议"
        case .privacy: return "隐私政策"
        }
    }

    var url: URL {
        switch self {
        case .agreement: return LegalLinks.userAgreementURL
        case .privacy: return LegalLinks.privacyPolicyURL
        }
    }
}

enum LegalLinks {
    static let privacyPolicyURL = URL(string: "https://www.cjym123.cn/privacy_sleep.html")!
    static let userAgreementURL = URL(string: "https://www.cjym123.cn/agreement_sleep.html")!
}

private struct CheckboxLikeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? .indigo : .secondary)
                configuration.label
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private extension ToggleStyle where Self == CheckboxLikeToggleStyle {
    static var checkboxLike: CheckboxLikeToggleStyle {
        CheckboxLikeToggleStyle()
    }
}
