import SwiftUI

private enum LoginMode {
    case code
    case password
}

struct LoginView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var mode: LoginMode = .code
    @State private var phone = ""
    @State private var code = ""
    @State private var password = ""
    @State private var isSendingCode = false
    @State private var isLoggingIn = false
    @State private var countdown = 0
    @State private var errorMessage: String?

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

    var body: some View {
        VStack(spacing: 22) {
            Image("LauncherIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 36)

            VStack(spacing: 8) {
                Text("登录时光睡眠")
                    .font(.title2.weight(.semibold))
                Text("同步你的睡眠报告、收藏声音和监测设置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("请输入手机号", text: $phone)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: phone) { newValue in
                    let digits = newValue.filter(\.isNumber)
                    phone = String(digits.prefix(11))
                }

            if mode == .code {
                HStack(spacing: 12) {
                    TextField("请输入验证码", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: code) { newValue in
                            let digits = newValue.filter(\.isNumber)
                            code = String(digits.prefix(6))
                        }

                    Button {
                        requestCode()
                    } label: {
                        Group {
                            if isSendingCode {
                                ProgressView()
                            } else if countdown > 0 {
                                Text("\(countdown)s")
                            } else {
                                Text("获取验证码")
                            }
                        }
                        .frame(width: 92)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isPhoneValid || isSendingCode || countdown > 0)
                }
            } else {
                SecureField("请输入密码", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                login()
            } label: {
                Group {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Text("登录")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPhoneValid || (mode == .code ? !isCodeValid : !isPasswordValid) || isLoggingIn)

            Button {
                switchMode()
            } label: {
                Text(mode == .code ? "使用密码登录" : "使用验证码登录")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.indigo)

            Text("继续即表示你同意用户协议和隐私政策。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestCode() {
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
                settings.login(phone: result.phone)
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
        countdown = 120
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }
}
