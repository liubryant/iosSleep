import StoreKit
import SwiftUI

@MainActor
final class SleepMembershipViewModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var isProcessing = false
    @Published var statusMessage = "正在加载 App Store 会员套餐…"
    @Published private(set) var displayPrices: [String: String] = [:]
    @Published private(set) var availableProductIDs = Set<String>()

    func loadData() {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusMessage = "正在加载 App Store 会员套餐…"
        Task {
            async let productsRequest = SleepStoreKitService.shared.loadProducts()
            if SleepMembershipSession.shared.effectiveAccessToken != nil {
                try? await SleepMembershipSession.shared.refresh()
            }
            let products = await productsRequest
            displayPrices = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0.displayPrice) })
            availableProductIDs = Set(products.map(\.id))
            isRefreshing = false
            if products.isEmpty {
                statusMessage = "暂未获取到 App Store 商品，请稍后重试"
            } else if SleepMembershipSession.shared.isVIPActive {
                statusMessage = SleepMembershipSession.shared.expiresAt.map { "会员权益有效期至 \($0)" }
                    ?? "会员权益已生效"
            } else {
                statusMessage = "请选择套餐并通过 App Store 订阅"
            }
        }
    }

    func price(for plan: SleepMembershipPlan) -> String {
        displayPrices[plan.productID] ?? "获取中…"
    }

    func isAvailable(_ plan: SleepMembershipPlan) -> Bool {
        availableProductIDs.contains(plan.productID)
    }

    func isCurrent(_ plan: SleepMembershipPlan) -> Bool {
        SleepMembershipSession.shared.isVIPActive
            && SleepMembershipSession.shared.productID == plan.productID
    }

    func purchase(plan: SleepMembershipPlan, agreementsAccepted: Bool) {
        guard agreementsAccepted else {
            statusMessage = "请先阅读并同意会员、自动续费、隐私政策和使用条款"
            return
        }
        guard isAvailable(plan) else {
            statusMessage = "该 App Store 商品暂不可购买，请稍后重试"
            return
        }
        guard !isCurrent(plan), !isProcessing else { return }
        isProcessing = true
        statusMessage = "正在打开 App Store 支付…"
        Task {
            do {
                let signed = try await SleepStoreKitService.shared.purchase(productID: plan.productID)
                statusMessage = "支付结果确认中…"
                let session = SleepMembershipSession.shared
                let verified = try await SleepMembershipService.shared.verifyApplePurchase(
                    token: session.userAccessToken,
                    appleProductID: signed.productID,
                    transactionID: signed.transactionID,
                    jws: signed.jws
                )
                session.apply(verified)
                await SleepStoreKitService.shared.finish(transactionID: signed.transactionID)
                isProcessing = false
                if verified.transactionAlreadyProcessed {
                    statusMessage = "当前订阅已生效，本次未生成新的续订周期"
                } else if verified.active {
                    statusMessage = verified.expiresAt.map { "支付成功，订阅有效期至 \($0)" }
                        ?? "支付成功，会员已开通"
                } else {
                    statusMessage = "支付已完成，会员状态同步中…"
                    try? await session.refresh()
                }
            } catch is CancellationError {
                isProcessing = false
                statusMessage = "已取消支付"
            } catch {
                isProcessing = false
                statusMessage = error.localizedDescription
            }
        }
    }

    func restorePurchases() {
        guard !isProcessing else { return }
        isProcessing = true
        statusMessage = "正在从 App Store 恢复购买…"
        Task {
            do {
                let transactions = try await SleepStoreKitService.shared.restore()
                var restoredCount = 0
                var lastError: Error?
                for signed in transactions {
                    do {
                        let session = SleepMembershipSession.shared
                        let verified = try await SleepMembershipService.shared.verifyApplePurchase(
                            token: session.userAccessToken,
                            appleProductID: signed.productID,
                            transactionID: signed.transactionID,
                            jws: signed.jws
                        )
                        session.apply(verified)
                        await SleepStoreKitService.shared.finish(transactionID: signed.transactionID)
                        restoredCount += 1
                    } catch {
                        lastError = error
                    }
                }
                isProcessing = false
                if restoredCount > 0 {
                    statusMessage = SleepMembershipSession.shared.expiresAt.map { "会员权益已恢复，有效期至 \($0)" }
                        ?? "会员权益已恢复"
                } else if let lastError {
                    statusMessage = lastError.localizedDescription
                } else {
                    statusMessage = "当前 Apple 账户没有可恢复的有效订阅"
                }
            } catch {
                isProcessing = false
                statusMessage = error.localizedDescription
            }
        }
    }
}

struct SleepMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var session = SleepMembershipSession.shared
    @StateObject private var viewModel = SleepMembershipViewModel()
    @State private var selectedPlan = 1
    @State private var hasAcceptedAgreements = false
    @State private var showLogin = false
    @State private var legalDocument: SleepMembershipLegalDocument?

    private let plans = SleepMembershipPlan.all
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.027, blue: 0.012).ignoresSafeArea()
            decoration
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        accountHeader
                        benefitsCard
                        planSection
                        statusArea
                        payMethodDivider
                        payChannelArea
                        tipsCard
                    }
                    .padding(.bottom, 18)
                }
                bottomArea
            }
        }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showLogin, onDismiss: { viewModel.loadData() }) {
            NavigationStack { LoginView() }
                .environmentObject(settings)
        }
        .sheet(item: $legalDocument) { document in
            NavigationStack {
                LegalTextView(title: document.title, url: document.url)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { legalDocument = nil }
                        }
                    }
            }
        }
        .onAppear { viewModel.loadData() }
    }

    private var decoration: some View {
        VStack {
            HStack {
                Spacer()
                Circle()
                    .fill(Color(red: 0.79, green: 0.45, blue: 0.17).opacity(0.18))
                    .frame(width: 250, height: 250)
                    .blur(radius: 28)
                    .offset(x: 80, y: -80)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.sleepMembershipLightGold)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text("VIP 会员")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.sleepMembershipLightGold)
            Spacer()
            Button(action: { viewModel.loadData() }) {
                if viewModel.isRefreshing {
                    ProgressView().tint(.sleepMembershipLightGold)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.sleepMembershipLightGold)
                }
            }
            .frame(width: 44, height: 44)
            .disabled(viewModel.isRefreshing || viewModel.isProcessing)
        }
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.24))
    }

    private var accountHeader: some View {
        HStack(spacing: 13) {
            ZStack {
                LinearGradient(
                    colors: [.sleepMembershipLightGold, Color(red: 0.51, green: 0.28, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Circle())
                Image(systemName: session.isVIPActive ? "crown.fill" : "person.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.31, green: 0.16, blue: 0.07))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text(hasSyncedLogin ? maskedPhone : "Apple 账户可直接订阅")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(membershipSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(session.isVIPActive ? .sleepMembershipLightGold : .sleepMembershipMutedGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            if !hasSyncedLogin {
                Button("登录同步") { showLogin = true }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.46, green: 0.25, blue: 0.10))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color.sleepMembershipLightGold)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var maskedPhone: String {
        let phone = settings.phoneNumber
        guard phone.count >= 7 else { return phone }
        return String(phone.prefix(3)) + " **** " + String(phone.suffix(4))
    }

    private var hasSyncedLogin: Bool {
        settings.isLoggedIn && session.userAccessToken != nil
    }

    private var membershipSubtitle: String {
        if session.isVIPActive {
            return session.expiresAt.map { "有效期至 \($0)" } ?? "会员权益已生效"
        }
        return "登录后会员同步到手机号账号"
    }

    private var benefitsCard: some View {
        VStack(spacing: 17) {
            HStack {
                Text("会员权益")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.sleepMembershipLightGold)
                Spacer()
            }
            HStack(spacing: 0) {
                benefit(icon: "figure.mind.and.body", title: "全部正念冥想", subtitle: "VIP 内容畅听")
                benefit(icon: "waveform", title: "全部助眠声音", subtitle: "会员全部解锁")
                benefit(icon: "sparkles", title: "内容持续更新", subtitle: "更多会员音频")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.055, blue: 0.03), Color(red: 0.24, green: 0.14, blue: 0.075)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.sleepMembershipGold.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private func benefit(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .medium))
                .foregroundColor(.sleepMembershipLightGold)
                .frame(height: 30)
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            Text(subtitle).font(.system(size: 10)).foregroundColor(.sleepMembershipMutedGold)
        }
        .frame(maxWidth: .infinity)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择会员套餐")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.sleepMembershipLightGold)
                .padding(.horizontal, 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(plans.indices, id: \.self) { index in
                        planCard(plans[index], index: index)
                    }
                }
                .padding(.horizontal, isPad ? 22 : 12)
            }
            .frame(height: isPad ? 190 : 164)
        }
        .padding(.top, isPad ? 28 : 24)
    }

    private func planCard(_ plan: SleepMembershipPlan, index: Int) -> some View {
        let selected = selectedPlan == index
        let badge = badgeStyle(for: index)
        let priceAndPeriod = displayPriceAndPeriod(for: plan)
        return Button(action: { selectedPlan = index }) {
            ZStack(alignment: .top) {
                VStack(spacing: 6) {
                    Spacer().frame(height: 14)
                    if priceAndPeriod == "获取中…" {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 0.227, green: 0.180, blue: 0.133))
                            .frame(width: isPad ? 68 : 58, height: isPad ? 26 : 22)
                            .padding(.vertical, 3)
                    } else {
                        Text(priceAndPeriod)
                            .font(.system(size: isPad ? 24 : 20, weight: .bold))
                            .foregroundColor(selected ? .sleepMembershipSelectedPrice : .sleepMembershipUnselectedPrice)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Text(plan.name)
                        .font(.system(size: isPad ? 14 : 12, weight: .semibold))
                        .foregroundColor(selected ? .sleepMembershipSelectedTitle : .sleepMembershipUnselectedTitle)
                    Text(plan.detail)
                        .font(.system(size: isPad ? 12 : 10))
                        .foregroundColor(selected ? .sleepMembershipSelectedDetail : .sleepMembershipUnselectedDetail)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                    Spacer()
                }
                .frame(width: isPad ? 158 : 138, height: isPad ? 172 : 148)
                .background(
                    LinearGradient(
                        colors: selected
                            ? [Color(red: 0.286, green: 0.208, blue: 0.133), Color(red: 0.169, green: 0.129, blue: 0.094)]
                            : [Color(red: 0.102, green: 0.082, blue: 0.071)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? Color.sleepMembershipUnselectedPrice : Color(red: 0.318, green: 0.267, blue: 0.216),
                                lineWidth: selected ? 2 : 1)
                )
                .padding(.top, 16)

                Text(badge.text)
                    .font(.system(size: isPad ? 11 : 9.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(LinearGradient(colors: [badge.start, badge.end], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .offset(y: 4)
            }
            .frame(height: isPad ? 190 : 164)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badgeStyle(for index: Int) -> (text: String, start: Color, end: Color) {
        switch index {
        case 0: return ("限时特惠", Color(red: 0.612, green: 0.153, blue: 0.690), Color(red: 0.416, green: 0.106, blue: 0.604))
        case 1: return ("超值特惠", Color(red: 1.0, green: 0.702, blue: 0.0), Color(red: 0.961, green: 0.486, blue: 0.0))
        default: return ("80%用户选择", Color(red: 1.0, green: 0.420, blue: 0.208), Color(red: 0.898, green: 0.224, blue: 0.208))
        }
    }

    private func displayPriceAndPeriod(for plan: SleepMembershipPlan) -> String {
        let price = viewModel.price(for: plan).replacingOccurrences(of: "¥", with: "￥")
        guard price != "获取中…" else { return price }
        return "\(price)/\(plan.periodUnit)"
    }

    private var statusArea: some View {
        HStack(spacing: 8) {
            if viewModel.isProcessing { ProgressView().tint(.sleepMembershipGold) }
            Text(viewModel.statusMessage)
                .font(.system(size: 12))
                .foregroundColor(.sleepMembershipReadableMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var payMethodDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color(red: 0.32, green: 0.28, blue: 0.24)).frame(width: 20, height: 1)
            Text("支付方式").font(.system(size: 12)).foregroundColor(.sleepMembershipReadableMuted)
            Rectangle().fill(Color(red: 0.32, green: 0.28, blue: 0.24)).frame(width: 20, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var payChannelArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "applelogo").font(.system(size: 20, weight: .medium))
                Text("通过 App Store 支付").font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(.sleepMembershipGold)
            }
            .foregroundColor(Color(red: 0.525, green: 0.31, blue: 0.176))
            .padding(.horizontal, 16)
            .frame(height: isPad ? 64 : 56)
            .background(Color(red: 0.996, green: 0.922, blue: 0.725))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sleepMembershipGold, lineWidth: 1))

            Button(action: { viewModel.restorePurchases() }) {
                Text("恢复购买")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sleepMembershipMutedGold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("温馨提示", systemImage: "info.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.78, green: 0.61, blue: 0.36))
            Text(warmTipsContent)
                .font(.system(size: 11.5))
                .foregroundColor(.sleepMembershipTipsText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var warmTipsContent: String {
        """
        1. 本会员为虚拟数字服务，通过苹果 App Store 内购（IAP）完成支付，费用将从您的 Apple ID 账户扣除。
        2. 会员权益在支付成功、服务端确认订单后立即生效，具体到期时间以页面顶部显示为准。
        3. 本套餐为自动续订订阅；除非在当前订阅期结束至少 24 小时前取消，否则将自动续订。您可在 iOS“设置—Apple 账户—订阅”中管理或取消。
        4. 普通用户可免费使用前 4 个正念冥想内容及前 30 个助眠声音，VIP 会员可解锁后续全部正念冥想与助眠声音。
        5. 若支付后权益未及时到账，可稍后重新进入本页面，或点击“恢复购买”同步订单状态。
        6. 无需注册或登录即可购买、恢复订阅；登录仅用于在支持的设备间同步账号内容与会员权益。
        7. 开通即代表您已阅读并同意《会员服务协议》《自动续费服务协议》《隐私政策》和《使用条款（EULA）》。
        """
    }

    private var bottomArea: some View {
        let plan = plans[selectedPlan]
        let isCurrent = viewModel.isCurrent(plan)
        let isPayEnabled = !viewModel.isProcessing && !isCurrent && viewModel.isAvailable(plan)
        return VStack(spacing: 5) {
            Button(action: { viewModel.purchase(plan: plan, agreementsAccepted: hasAcceptedAgreements) }) {
                Group {
                    if viewModel.isProcessing {
                        HStack(spacing: 10) {
                            ProgressView().tint(Color(red: 0.46, green: 0.25, blue: 0.10))
                            Text(processingPaymentText).font(.system(size: isPad ? 14 : 13, weight: .bold))
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(displayPriceAndPeriod(for: plan)).font(.system(size: isPad ? 21 : 19, weight: .bold))
                            Text(isCurrent ? "当前套餐" : (session.isVIPActive ? "更换套餐" : "立即开通"))
                                .font(.system(size: isPad ? 13 : 12, weight: .bold))
                        }
                    }
                }
                .foregroundColor(isPayEnabled || viewModel.isProcessing
                    ? Color(red: 0.46, green: 0.25, blue: 0.10)
                    : Color(red: 0.76, green: 0.70, blue: 0.64))
                .frame(maxWidth: .infinity, minHeight: isPad ? 56 : 48)
                .background(
                    LinearGradient(
                        colors: isPayEnabled || viewModel.isProcessing
                            ? [Color(red: 0.996, green: 0.922, blue: 0.725), Color(red: 1.0, green: 0.847, blue: 0.537)]
                            : [Color(red: 0.294, green: 0.255, blue: 0.216), Color(red: 0.22, green: 0.192, blue: 0.169)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
            }
            .disabled(!isPayEnabled)
            .padding(.horizontal, 28)
            .padding(.top, 7)

            HStack(spacing: 3) {
                Button(action: { hasAcceptedAgreements.toggle() }) {
                    Image(systemName: hasAcceptedAgreements ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(hasAcceptedAgreements ? .sleepMembershipGold : .sleepMembershipReadableMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                Text("请阅读并同意").font(.system(size: 12)).foregroundColor(.sleepMembershipReadableMuted)
                Button("《会员服务协议》") { legalDocument = .vipAgreement }
                Button("《自动续费协议》") { legalDocument = .autoRenewAgreement }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.sleepMembershipGold)

            HStack(spacing: 10) {
                Button("《隐私政策》") { legalDocument = .privacyPolicy }
                Button("《使用条款（EULA）》") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        openURL(url)
                    }
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.sleepMembershipGold)
        }
        .padding(.bottom, 8)
        .background(Color(red: 0.055, green: 0.027, blue: 0.012))
    }

    private var processingPaymentText: String {
        if viewModel.statusMessage.contains("确认") { return "支付结果确认中…" }
        if viewModel.statusMessage.contains("恢复") { return "正在恢复购买…" }
        return "正在打开 App Store 支付…"
    }
}

struct SleepMembershipDiamond: View {
    var body: some View {
        Canvas { context, size in
            func facet(_ points: [CGPoint], color: Color) {
                var path = Path()
                path.addLines(points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }

            let left = CGPoint(x: 0, y: 0.32)
            let topLeft = CGPoint(x: 0.19, y: 0)
            let topRight = CGPoint(x: 0.81, y: 0)
            let right = CGPoint(x: 1, y: 0.32)
            let bottom = CGPoint(x: 0.5, y: 1)
            let innerLeft = CGPoint(x: 0.28, y: 0.24)
            let innerRight = CGPoint(x: 0.72, y: 0.24)
            let innerBottom = CGPoint(x: 0.5, y: 0.61)

            facet([left, topLeft, topRight, right, bottom], color: Color(red: 0.88, green: 0.65, blue: 0.28))
            facet([left, topLeft, topRight, innerRight, innerLeft], color: Color(red: 1, green: 0.88, blue: 0.58))
            facet([left, innerLeft, innerBottom, bottom], color: Color(red: 0.96, green: 0.77, blue: 0.41))
            facet([topRight, right, bottom, innerBottom, innerRight], color: Color(red: 0.73, green: 0.49, blue: 0.20))
            facet([innerLeft, innerRight, innerBottom], color: Color(red: 0.22, green: 0.15, blue: 0.08))
        }
    }
}

enum SleepVIPContentKind {
    case mindfulness
    case sound
    case mbti

    var title: String {
        switch self {
        case .mindfulness: return "VIP 专享正念"
        case .sound: return "VIP 专享声音"
        case .mbti: return "解锁完整 MBTI 分析"
        }
    }

    var benefitIcon: String {
        switch self {
        case .mindfulness: return "wind"
        case .sound: return "waveform"
        case .mbti: return "chart.bar.xaxis"
        }
    }

    var benefitTitle: String {
        switch self {
        case .mindfulness: return "正念冥想内容"
        case .sound: return "全部助眠声音"
        case .mbti: return "完整人格报告"
        }
    }

    var benefitDetail: String {
        switch self {
        case .mindfulness: return "畅听会员专享的引导练习与冥想课程"
        case .sound: return "畅听会员专享的助眠声音"
        case .mbti: return "人格类型、四维偏好强度、完整人格解读"
        }
    }

    func prompt(for contentTitle: String) -> String {
        if self == .mbti { return "你的 MBTI 测评已完成，开通会员即可查看结果。" }
        let title = contentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "开通会员即可播放" : "开通会员即可播放「\(title)」"
    }
}

struct SleepVIPPromptContent: Identifiable {
    let id = UUID()
    let title: String
    let kind: SleepVIPContentKind
}

struct SleepVIPUpgradeSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let contentTitle: String
    var contentKind: SleepVIPContentKind = .mindfulness
    let onUpgrade: () -> Void
    let onCancel: () -> Void

    private let gold = Color(red: 0.97, green: 0.80, blue: 0.47)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                benefit
                actions
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .background(sheetBackground.ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(320), .large])
        .presentationDragIndicator(.visible)
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.16, green: 0.12, blue: 0.09), Color(white: 0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            SleepMembershipDiamond()
                .frame(width: 24, height: 19)
                .frame(width: 38, height: 38)
                .background(gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("时光睡眠会员")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(gold)
                Text(contentKind.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(contentKind.prompt(for: contentTitle))
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var benefit: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: contentKind.benefitIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(gold)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(contentKind.benefitTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(contentKind.benefitDetail)
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.72))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actions: some View {
        VStack(spacing: 2) {
            Button(action: onUpgrade) {
                Text("立即开通会员")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.20, green: 0.12, blue: 0.06))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(gold, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("稍后再说")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.72))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

struct SleepMembershipPlan {
    let name: String
    let detail: String
    let period: String
    let productID: String
    let appleNumericID: String

    var periodUnit: String { period.hasPrefix("每") ? String(period.dropFirst()) : period }

    static let all = [
        SleepMembershipPlan(name: "周会员", detail: "短期体验 · 灵活续费", period: "每周", productID: "cn.sleep.vip.week", appleNumericID: "6806154887"),
        SleepMembershipPlan(name: "月会员", detail: "热门之选 · 畅享全月", period: "每月", productID: "cn.sleep.vip.month", appleNumericID: "6805426537"),
        SleepMembershipPlan(name: "年会员", detail: "超值长期 · 尊享一年", period: "每年", productID: "cn.sleep.vip.year", appleNumericID: "6805424822")
    ]
}

private struct SleepMembershipLegalDocument: Identifiable {
    let id: String
    let title: String
    let url: URL

    static let vipAgreement = SleepMembershipLegalDocument(
        id: "sleep_vip_agreement",
        title: "会员服务协议",
        url: URL(string: "https://www.cjym123.cn/im/bot/sleep/vip/agreement/member")!
    )
    static let autoRenewAgreement = SleepMembershipLegalDocument(
        id: "sleep_auto_renew_agreement",
        title: "自动续费服务协议",
        url: URL(string: "https://www.cjym123.cn/im/bot/sleep/vip/agreement/auto-renew")!
    )
    static let privacyPolicy = SleepMembershipLegalDocument(
        id: "sleep_privacy_policy",
        title: "隐私政策",
        url: LegalLinks.privacyPolicyURL
    )
}

private extension Color {
    static let sleepMembershipLightGold = Color(red: 1.0, green: 0.91, blue: 0.68)
    static let sleepMembershipGold = Color(red: 0.79, green: 0.48, blue: 0.20)
    static let sleepMembershipMutedGold = Color(red: 0.72, green: 0.61, blue: 0.43)
    static let sleepMembershipReadableMuted = Color(red: 0.69, green: 0.65, blue: 0.61)
    static let sleepMembershipTipsText = Color(red: 0.74, green: 0.70, blue: 0.66)
    static let sleepMembershipSelectedPrice = Color(red: 1.0, green: 0.88, blue: 0.63)
    static let sleepMembershipUnselectedPrice = Color(red: 0.92, green: 0.78, blue: 0.51)
    static let sleepMembershipSelectedTitle = Color(red: 1.0, green: 0.96, blue: 0.87)
    static let sleepMembershipUnselectedTitle = Color(red: 0.82, green: 0.75, blue: 0.65)
    static let sleepMembershipSelectedDetail = Color(red: 0.86, green: 0.75, blue: 0.59)
    static let sleepMembershipUnselectedDetail = Color(red: 0.62, green: 0.55, blue: 0.46)
}
