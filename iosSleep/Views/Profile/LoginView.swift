import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var phone = ""
    @State private var code = ""
    @State private var isSendingCode = false
    @State private var isLoggingIn = false
    @State private var countdown = 0
    @State private var errorMessage: String?

    private var isPhoneValid: Bool {
        phone.count == 11 && phone.allSatisfy(\.isNumber)
    }

    private var isCodeValid: Bool {
        code.count >= 4 && code.allSatisfy(\.isNumber)
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
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
            .disabled(!isPhoneValid || !isCodeValid || isLoggingIn)

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
                let result = try await AuthAPI.login(phone: phone, code: code)
                settings.login(phone: phone, token: result.token)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "登录失败，请稍后重试"
            }
            isLoggingIn = false
        }
    }

    private func startCountdown() {
        countdown = 60
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }
}
