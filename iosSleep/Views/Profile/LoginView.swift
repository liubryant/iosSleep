import SwiftUI

private enum LoginMode {
    case code
    case password
}

struct LoginView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var mode: LoginMode = .code
    @State private var phone = ""
    @State private var code = ""
    @State private var password = ""
    @State private var isSendingCode = false
    @State private var isLoggingIn = false
    @State private var countdown = 0
    @State private var errorMessage: String?
    @State private var legalDocument: SleepLoginLegalDocument?
    @State private var countdownTask: Task<Void, Never>?

    private let loginPurple = Color(red: 0.40, green: 0.31, blue: 0.96)

    private var loginAccent: Color {
        colorScheme == .dark ? Color(red: 0.76, green: 0.70, blue: 1.0) : loginPurple
    }

    private var isPhoneValid: Bool {
        let pattern = "^1[3-9]\\d{9}$"
        return phone.range(of: pattern, options: .regularExpression) != nil
    }

    private var isCodeValid: Bool {
        code.count == 6 && code.allSatisfy(\.isNumber)
    }

    private var isPasswordValid: Bool {
        password.count >= 6
    }

    private var canSendCode: Bool {
        isPhoneValid && countdown == 0 && !isSendingCode && !isLoggingIn
    }

    private var canLogin: Bool {
        guard isPhoneValid, !isLoggingIn else { return false }
        return mode == .code ? isCodeValid : isPasswordValid
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                loginContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .appEdgeSwipeBack()
        .sheet(item: $legalDocument) { document in
            NavigationStack {
                LegalTextView(title: document.title, url: document.url)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { legalDocument = nil }
                        }
                    }
            }
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("登录账号")
                .font(.system(size: 17, weight: .bold))

            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .foregroundStyle(.primary)
        .background(Color(.systemBackground))
    }

    private var loginContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image("LauncherIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    Text(mode == .code ? "手机验证码快速登录" : "手机号密码登录")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    Text("登录为可选操作，不登录也可以正常使用声音播放与睡眠功能")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 26)

                VStack(spacing: 16) {
                    labeledField(title: "手机号") {
                        HStack(spacing: 10) {
                            Text("+86")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(loginAccent)
                            Divider().frame(height: 20)
                            TextField("请输入手机号", text: Binding(
                                get: { phone },
                                set: { phone = normalizedPhoneNumber($0) }
                            ), prompt: Text("请输入手机号").foregroundColor(.secondary))
                            .keyboardType(.numberPad)
                            .textContentType(mode == .password ? .username : .telephoneNumber)
                        }
                    }

                    if mode == .code {
                        labeledField(title: "验证码") {
                            HStack {
                                TextField("请输入6位验证码", text: Binding(
                                    get: { code },
                                    set: { code = String($0.filter(\.isNumber).prefix(6)) }
                                ), prompt: Text("请输入6位验证码").foregroundColor(.secondary))
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)

                                Divider().frame(height: 20)

                                Button { requestCode() } label: {
                                    Group {
                                        if isSendingCode {
                                            ProgressView()
                                                .tint(loginAccent)
                                        } else {
                                            Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                                        }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(canSendCode ? loginAccent : Color.secondary)
                                    .frame(width: 78)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canSendCode)
                            }
                        }
                    } else {
                        labeledField(title: "密码") {
                            SecureField("请输入密码（至少6位）", text: $password,
                                        prompt: Text("请输入密码（至少6位）").foregroundColor(.secondary))
                                .textContentType(.password)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button { login() } label: {
                        Group {
                            if isLoggingIn {
                                ProgressView().tint(.white)
                            } else {
                                Text("登录")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(canLogin || isLoggingIn ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            LinearGradient(
                                colors: canLogin || isLoggingIn
                                    ? [loginPurple, Color(red: 0.49, green: 0.34, blue: 0.91)]
                                    : [Color(.secondarySystemBackground), Color(.secondarySystemBackground)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canLogin)

                    Button { switchMode() } label: {
                        Text(mode == .code ? "使用密码登录" : "使用验证码登录")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(loginAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                legalLinks
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }

    private func labeledField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            content()
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .tint(loginAccent)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            Text("登录即代表您已阅读并同意")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Button("《用户协议》") {
                    legalDocument = .userAgreement
                }
                Button("《隐私政策》") {
                    legalDocument = .privacyPolicy
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(loginAccent)
            .buttonStyle(.plain)
        }
    }

    private func normalizedPhoneNumber(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        // Password AutoFill can return a saved username with the +86 country code.
        if digits.count == 13, digits.hasPrefix("86") {
            return String(digits.dropFirst(2))
        }
        if digits.count == 15, digits.hasPrefix("0086") {
            return String(digits.dropFirst(4))
        }
        return String(digits.prefix(11))
    }

    private func requestCode() {
        guard canSendCode else { return }
        errorMessage = nil
        isSendingCode = true
        Task {
            do {
                try await AuthAPI.requestVerificationCode(phone: phone)
                startCountdown()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "验证码发送失败，请稍后重试"
            }
            isSendingCode = false
        }
    }

    private func login() {
        guard canLogin else { return }
        errorMessage = nil
        isLoggingIn = true
        Task {
            do {
                let result: AppUserLoginResult
                switch mode {
                case .code:
                    result = try await AuthAPI.login(phone: phone, code: code)
                case .password:
                    result = try await AuthAPI.login(phone: phone, password: password)
                }
                guard let accessToken = result.resolvedAccessToken else {
                    throw AuthError.server("登录成功但未取得账号凭证，请稍后重试")
                }
                settings.login(phone: result.phone, accessToken: accessToken)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "登录失败，请稍后重试"
            }
            isLoggingIn = false
        }
    }

    private func switchMode() {
        errorMessage = nil
        mode = mode == .code ? .password : .code
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = 60
        countdownTask = Task { @MainActor in
            while countdown > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                countdown -= 1
            }
        }
    }
}

private enum SleepLoginLegalDocument: String, Identifiable {
    case userAgreement
    case privacyPolicy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userAgreement: return "用户协议"
        case .privacyPolicy: return "隐私政策"
        }
    }

    var url: URL {
        switch self {
        case .userAgreement: return LegalLinks.userAgreementURL
        case .privacyPolicy: return LegalLinks.privacyPolicyURL
        }
    }
}
