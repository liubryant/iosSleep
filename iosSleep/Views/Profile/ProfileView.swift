import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var sleepMonitor: SleepMonitorService
    @EnvironmentObject private var storyLibrary: StoryLibrary
    @ObservedObject private var membership = SleepMembershipSession.shared
    @State private var cacheSize = CacheService.formattedSize(CacheService.cacheSize())
    @State private var showingClearAlert = false
    @State private var showingMembership = false
    @State private var showingAccountManagement = false
    @State private var showingLogin = false

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private func cardFontSize(_ size: CGFloat) -> CGFloat { isPad ? ceil(size * 1.16) : size }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        loginCard
                        vipCard
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
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
                    Button("继续") {
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

                Section("提醒") {
                    Toggle(isOn: Binding(
                        get: { settings.storyReminderEnabled },
                        set: { enabled in
                            Task {
                                if enabled {
                                    settings.storyReminderAsked = true
                                    settings.storyReminderEnabled = await StoryNotificationService.shared.enable(
                                        stories: storyLibrary.stories
                                    )
                                } else {
                                    StoryNotificationService.shared.disable()
                                    settings.storyReminderEnabled = false
                                }
                            }
                        }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("故事提醒")
                                Text("每天 \(StoryNotificationService.reminderScheduleText) 精选故事")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note")
                        }
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
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .compactProfileSectionSpacing()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingMembership) {
                SleepMembershipView()
            }
            .navigationDestination(isPresented: $showingLogin) {
                LoginView()
            }
            .onAppear {
                cacheSize = CacheService.formattedSize(CacheService.cacheSize())
                membership.refreshSilently()
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
            .fullScreenCover(isPresented: $showingAccountManagement) {
                SleepAccountManagementDialog()
                    .environmentObject(settings)
                    .environmentObject(sleepMonitor)
                    .clearPresentationBackground()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "--"
    }

    private var maskedPhone: String {
        let phone = settings.phoneNumber
        guard phone.count >= 7 else { return phone }
        return String(phone.prefix(3)) + "****" + String(phone.suffix(4))
    }

    private func openAccount() {
        if settings.isLoggedIn {
            showingAccountManagement = true
        } else {
            showingLogin = true
        }
    }

    // 与 iosagentclaw ProfileView 登录卡片保持相同结构和尺寸。
    private var loginCard: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [Color(profileHex: "#7657F5"), Color(profileHex: "#C65FD0")],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                Image(systemName: "person.fill")
                    .font(.system(size: cardFontSize(26)))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(settings.isLoggedIn ? maskedPhone : "登录时光睡眠")
                    .font(.system(size: cardFontSize(19), weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(settings.isLoggedIn ? "账号已登录" : "登录后同步睡眠数据与会员权益")
                    .font(.system(size: cardFontSize(12)))
                    .foregroundStyle(Color(profileHex: "#E3CBB2"))
            }

            Spacer()

            if settings.isLoggedIn {
                Text("账号")
                    .font(.system(size: cardFontSize(13), weight: .medium))
                    .foregroundStyle(Color(profileHex: "#F4D8AE"))
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text("登录")
                    .font(.system(size: cardFontSize(13), weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minWidth: 72)
                    .frame(height: 38)
                    .background {
                        LinearGradient(
                            colors: [Color(profileHex: "#7658F7"), Color(profileHex: "#A64EE4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 18)
        .frame(height: isPad ? 136 : 116)
        .background(accountCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { openAccount() }
    }

    // 与 iosagentclaw ProfileView VIP 卡片保持相同结构和尺寸。
    private var vipCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(
                        colors: [Color(profileHex: "#FFE3A7"), Color(profileHex: "#C9944F")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                    Text("✦")
                        .font(.system(size: cardFontSize(21)))
                        .foregroundStyle(Color(profileHex: "#4B2A12"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("时光睡眠会员")
                        .font(.system(size: cardFontSize(17), weight: .bold))
                        .foregroundStyle(Color(profileHex: "#FFF2D2"))

                    Group {
                        if membership.isVIPActive, let expiresAt = membership.expiresAt {
                            Text("有效期至 \(expiresAt)")
                        } else {
                            Text(settings.isLoggedIn ? "开通会员，解锁全部正念内容" : "登录后会员同步到手机号账号")
                        }
                    }
                    .font(.system(size: cardFontSize(11)))
                    .foregroundStyle(Color(profileHex: "#C8A97E"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

                Spacer()

                Text("查看权益")
                    .font(.system(size: cardFontSize(12), weight: .semibold))
                    .foregroundStyle(Color(profileHex: "#4F2D16"))
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .background {
                        LinearGradient(
                            colors: [Color(profileHex: "#FFE9BD"), Color(profileHex: "#DAB06F")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Spacer()

            Rectangle()
                .fill(.white.opacity(0.133))
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)

            HStack(spacing: 0) {
                vipBenefit("✦ 全部正念冥想")
                vipBenefitDivider
                vipBenefit("✦ 自然声音畅听")
                vipBenefitDivider
                vipBenefit("✦ 专享内容更新")
            }
            .padding(.bottom, 14)
        }
        .frame(height: isPad ? 158 : 134)
        .background(accountCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { showingMembership = true }
    }

    private var accountCardBackground: LinearGradient {
        LinearGradient(
            colors: [Color(profileHex: "#241B18"), Color(profileHex: "#3B2920"), Color(profileHex: "#5A402B")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func vipBenefit(_ title: String) -> some View {
        Text(title)
            .font(.system(size: cardFontSize(11)))
            .foregroundStyle(Color(profileHex: "#EECC9A"))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
    }

    private var vipBenefitDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 12)
    }
}

private extension View {
    @ViewBuilder
    func compactProfileSectionSpacing() -> some View {
        if #available(iOS 17.0, *) {
            listSectionSpacing(.custom(12))
        } else {
            environment(\.defaultMinListHeaderHeight, 12)
        }
    }

    @ViewBuilder
    func clearPresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground(.clear)
        } else {
            self
        }
    }
}

private enum SleepAccountAction: String, Identifiable {
    case setPassword
    case deleteAccount

    var id: String { rawValue }
}

private struct SleepAccountManagementDialog: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sleepMonitor: SleepMonitorService
    @Environment(\.dismiss) private var dismiss
    @State private var accountAction: SleepAccountAction?

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 560
            let dialogHeight = isCompact
                ? min(max(proxy.size.height * 0.62, 440), proxy.size.height - 20)
                : min(max(proxy.size.height * 0.62, 420), 500)

            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("账号管理")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(red: 0.067, green: 0.094, blue: 0.153))
                            Text("管理当前登录账号")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                        }

                        Spacer()

                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.black)
                                .frame(width: 34, height: 34)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 14) {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.40, green: 0.31, blue: 0.96),
                                    Color(red: 0.57, green: 0.47, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())

                            Image(systemName: "person.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("已登录")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 0.086, green: 0.63, blue: 0.42))
                            Text(maskedPhone)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 0.067, green: 0.094, blue: 0.153))
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(red: 0.086, green: 0.63, blue: 0.42))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 82)
                    .background(Color(red: 0.969, green: 0.961, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.91, green: 0.89, blue: 1.0), lineWidth: 1)
                    }
                    .padding(.top, 26)

                    Spacer(minLength: 28)

                    Button { accountAction = .deleteAccount } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("注销账号")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color(red: 0.76, green: 0.25, blue: 0.047))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(red: 1.0, green: 0.97, blue: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.76, green: 0.25, blue: 0.047).opacity(0.45), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button { accountAction = .setPassword } label: {
                        Text("设置或修改密码")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.09, green: 0.10, blue: 0.14),
                                        Color(red: 0.21, green: 0.25, blue: 0.35)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)

                    Button {
                        settings.logout()
                        dismiss()
                    } label: {
                        Text("退出登录")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(red: 0.76, green: 0.25, blue: 0.047))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color(red: 0.94, green: 0.92, blue: 0.89))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.76, green: 0.25, blue: 0.047), lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .frame(maxWidth: isCompact ? proxy.size.width - 20 : min(proxy.size.width - 48, 520))
                .frame(height: dialogHeight)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                .padding(isCompact ? 8 : 24)
                .onTapGesture { }
            }
        }
        .sheet(item: $accountAction) { action in
            NavigationStack {
                switch action {
                case .setPassword:
                    SetPasswordView()
                case .deleteAccount:
                    AccountDeletionView()
                }
            }
            .environmentObject(settings)
            .environmentObject(sleepMonitor)
        }
        .onChange(of: settings.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                dismiss()
            }
        }
    }

    private var maskedPhone: String {
        let phone = settings.phoneNumber
        guard phone.count >= 7 else { return phone }
        return String(phone.prefix(3)) + " **** " + String(phone.suffix(4))
    }
}

private extension Color {
    init(profileHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        let red = Double((number >> 16) & 0xFF) / 255
        let green = Double((number >> 8) & 0xFF) / 255
        let blue = Double(number & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
