import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var sleepMonitor: SleepMonitorService
    @State private var cacheSize = CacheService.formattedSize(CacheService.cacheSize())
    @State private var showingClearAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileHeader
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
                        Label("数据大小", systemImage: "internaldrive")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Label("清除数据", systemImage: "trash")
                    }
                }

                Section("关于") {
                    NavigationLink("用户协议") {
                        LegalTextView(title: "用户协议", url: LegalLinks.userAgreementURL)
                    }
                    NavigationLink("隐私政策") {
                        LegalTextView(title: "隐私政策", url: LegalLinks.privacyPolicyURL)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cacheSize = CacheService.formattedSize(CacheService.cacheSize())
            }
            .alert("清除数据？", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    CacheService.clearCache()
                    sleepMonitor.clearAllData()
                    cacheSize = CacheService.formattedSize(CacheService.cacheSize())
                }
            } message: {
                Text("将删除所有睡眠监测保存的录音声音数据，以及临时缓存文件，不会删除内置声音资源。此操作不可恢复。")
            }
        }
    }

    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            TropicalRainforestCover()
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    Text("我的")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                Spacer()
            }
            .padding(22)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: settings.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(settings.isLoggedIn ? "已登录用户" : "未登录")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(settings.isLoggedIn ? "睡眠目标：每天 8 小时" : "登录后同步睡眠记录和设置")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.86))
                    }

                    Spacer()
                }

                if settings.isLoggedIn {
                    Button(role: .destructive) {
                        settings.logout()
                    } label: {
                        Text("退出登录")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("登录 / 注册")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
}

private struct TropicalRainforestCover: View {
    var body: some View {
        if let url = Bundle.main.url(
            forResource: "cover",
            withExtension: "jpg",
            subdirectory: "SoundResources/010_热带雨林"
        ),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [.green.opacity(0.75), .cyan.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
