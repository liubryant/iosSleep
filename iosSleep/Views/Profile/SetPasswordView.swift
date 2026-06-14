import SwiftUI

struct SetPasswordView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var password = ""
    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var countdown = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var isCodeValid: Bool {
        code.count == 6 && code.allSatisfy(\.isNumber)
    }

    private var isPasswordValid: Bool {
        password.count >= 6
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("修改登录密码")
                    .font(.title2.weight(.semibold))
                    .padding(.top, 36)
                Text("验证手机号 \(settings.phoneNumber) 后修改密码，之后可使用密码登录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                .disabled(isSendingCode || countdown > 0)
            }

            SecureField("请输入新密码（至少6位）", text: $password)
                .textContentType(.newPassword)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button {
                submit()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("确认设置")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isCodeValid || !isPasswordValid || isSubmitting)

            Spacer()
        }
        .padding()
        .navigationTitle("修改密码")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestCode() {
        errorMessage = nil
        successMessage = nil
        isSendingCode = true
        Task {
            do {
                try await AuthAPI.requestVerificationCode(phone: settings.phoneNumber)
                startCountdown()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "验证码发送失败，请稍后重试"
            }
            isSendingCode = false
        }
    }

    private func submit() {
        errorMessage = nil
        successMessage = nil
        isSubmitting = true
        Task {
            do {
                _ = try await AuthAPI.setPassword(phone: settings.phoneNumber, code: code, password: password)
                successMessage = "密码设置成功"
                code = ""
                password = ""
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "设置失败，请稍后重试"
            }
            isSubmitting = false
        }
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
