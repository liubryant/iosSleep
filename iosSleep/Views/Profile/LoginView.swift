import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .padding(.top, 36)

            VStack(spacing: 8) {
                Text("登录 iosSleep")
                    .font(.title2.weight(.semibold))
                Text("同步你的睡眠报告、收藏声音和监测设置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("手机号", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                settings.login()
                dismiss()
            } label: {
                Text("本地模拟登录")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                settings.login()
                dismiss()
            } label: {
                Label("通过 Apple 登录", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("继续即表示你同意用户协议和隐私政策。第一版仅做本地登录状态模拟，不上传账号数据。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
    }
}
