import SwiftUI

struct AccountDeletionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sleepMonitor: SleepMonitorService
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isSendingCode = false
    @State private var isDeleting = false
    @State private var countdown = 0
    @State private var errorMessage: String?
    @State private var showingConfirm = false
    @State private var didSucceed = false

    private var isCodeValid: Bool {
        code.count == 6 && code.allSatisfy(\.isNumber)
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .padding(.top, 36)

            VStack(spacing: 8) {
                Text("注销账号")
                    .font(.title2.weight(.semibold))
                Text("验证手机号 \(settings.phoneNumber) 后将永久注销账号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("注销账号前请确认：")
                    .font(.subheadline.weight(.semibold))
                Text("• 账号信息、睡眠记录及设置将被永久删除，无法恢复")
                Text("• 本机保存的监测数据也会一并清除")
                Text("• 注销后该手机号可重新注册新账号")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

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

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button(role: .destructive) {
                showingConfirm = true
            } label: {
                Group {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("注销账号")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(!isCodeValid || isDeleting)
        }
        .padding()
        .navigationTitle("账号与安全")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认注销账号？", isPresented: $showingConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("注销后账号及数据将被永久删除，且无法恢复。")
        }
        .alert("删除成功", isPresented: $didSucceed) {
            Button("好") { dismiss() }
        } message: {
            Text("账号已注销")
        }
    }

    private func requestCode() {
        errorMessage = nil
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

    private func deleteAccount() {
        errorMessage = nil
        isDeleting = true
        Task {
            do {
                try await AuthAPI.deleteAccount(phone: settings.phoneNumber, code: code)
                sleepMonitor.clearAllData()
                CacheService.clearCache()
                settings.clearAccountData()
                didSucceed = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "注销失败，请稍后重试"
            }
            isDeleting = false
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
