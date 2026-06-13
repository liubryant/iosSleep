import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var cacheSize = CacheService.formattedSize(CacheService.cacheSize())
    @State private var showingClearAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: settings.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.isLoggedIn ? "已登录用户" : "未登录")
                                .font(.headline)
                            Text(settings.isLoggedIn ? "睡眠目标：每天 8 小时" : "登录后同步睡眠记录和设置")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if settings.isLoggedIn {
                        Button("退出登录", role: .destructive) {
                            settings.logout()
                        }
                    } else {
                        NavigationLink("登录 / 注册") {
                            LoginView()
                        }
                    }
                }

                Section("权限") {
                    HStack {
                        Label("麦克风", systemImage: "mic.fill")
                        Spacer()
                        Text("使用时申请")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("HealthKit", systemImage: "heart.fill")
                        Spacer()
                        Text(healthKit.statusText)
                            .foregroundStyle(healthKit.isAuthorized ? .green : .secondary)
                    }
                    Button("授权 HealthKit") {
                        Task { await healthKit.requestAuthorization() }
                    }
                }

                Section("睡眠监测") {
                    Toggle("保存识别片段", isOn: $settings.saveAudioClips)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("识别灵敏度")
                            Spacer()
                            Text("\(Int(settings.sensitivity * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.sensitivity, in: 0.3...0.95)
                    }
                }

                Section("数据") {
                    HStack {
                        Label("缓存大小", systemImage: "internaldrive")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Label("清除缓存", systemImage: "trash")
                    }
                }

                Section("关于") {
                    NavigationLink("用户协议") {
                        LegalTextView(title: "用户协议", text: LegalText.userAgreement)
                    }
                    NavigationLink("隐私政策") {
                        LegalTextView(title: "隐私政策", text: LegalText.privacyPolicy)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .onAppear {
                cacheSize = CacheService.formattedSize(CacheService.cacheSize())
            }
            .alert("清除缓存？", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    CacheService.clearCache()
                    cacheSize = CacheService.formattedSize(CacheService.cacheSize())
                }
            } message: {
                Text("只会清理临时文件和缓存目录，不会删除内置声音资源。")
            }
        }
    }
}
