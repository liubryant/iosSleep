import SwiftUI

enum WellnessDestination: Hashable {
    case hub
    case healthInsight
    case assessment(WellnessAssessmentKind)
    case breathing
    case devices
    case history
    case record(WellnessAssessmentRecord)
}

struct WellnessFeature: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let icon: String
    let colors: [WellnessColorToken]
    let destination: WellnessDestination

    static let all: [WellnessFeature] = [
        .init(id: "health", title: "睡眠洞察", subtitle: "读取 Apple 健康睡眠阶段", badge: "健康数据", icon: "heart.text.square.fill", colors: [.blue, .cyan], destination: .healthInsight),
        .init(id: "sleep", title: "睡眠状态", subtitle: "了解近期睡眠困扰", badge: "8 道题", icon: "moon.zzz.fill", colors: [.indigo, .blue], destination: .assessment(.sleepHealth)),
        .init(id: "mood", title: "情绪状态", subtitle: "PHQ-2 快速筛查", badge: "约 1 分钟", icon: "heart.fill", colors: [.pink, .orange], destination: .assessment(.mood)),
        .init(id: "anxiety", title: "焦虑状态", subtitle: "GAD-7 觉察近期担忧", badge: "7 道题", icon: "wind", colors: [.cyan, .blue], destination: .assessment(.anxiety)),
        .init(id: "mbti", title: "MBTI 人格", subtitle: "发现你的 16 型人格", badge: "36 道题", icon: "person.2.wave.2.fill", colors: [.purple, .pink], destination: .assessment(.mbti)),
        .init(id: "bigfive", title: "大五性格", subtitle: "探索五种人格倾向", badge: "20 道题", icon: "person.crop.circle.fill", colors: [.purple, .indigo], destination: .assessment(.bigFive)),
        .init(id: "stress", title: "压力自测", subtitle: "看看身心是否超负荷", badge: "8 道题", icon: "speedometer", colors: [.orange, .red], destination: .assessment(.stress)),
        .init(id: "chronotype", title: "作息类型", subtitle: "晨型、弹性型还是夜型", badge: "节律探索", icon: "sun.and.horizon.fill", colors: [.yellow, .orange], destination: .assessment(.chronotype)),
        .init(id: "breathing", title: "呼吸练习", subtitle: "用一分钟让身心慢下来", badge: "正念时长", icon: "lungs.fill", colors: [.mint, .teal], destination: .breathing),
        .init(id: "devices", title: "智能设备", subtitle: "手表与睡眠设备连接指南", badge: "多平台", icon: "applewatch", colors: [.indigo, .purple], destination: .devices)
    ]

    static let sleepHealth = features(withIDs: ["health", "sleep", "chronotype"])
    static let mindAndPersonality = features(withIDs: ["mbti", "mood", "anxiety", "stress", "bigfive"])
    static let relaxAndDevices = features(withIDs: ["breathing", "devices"])

    private static let coverDestinations = (mindAndPersonality + sleepHealth + relaxAndDevices).map(\.destination) + [.history]
    private static let coverIndices = Dictionary(uniqueKeysWithValues: zip(coverDestinations, MindfulnessCover.wellnessIndices))

    static func coverImage(for destination: WellnessDestination) -> UIImage? {
        coverIndices[destination].flatMap { MindfulnessCover.image(at: $0) }
    }

    static var hubCoverImage: UIImage? {
        MindfulnessCover.wellnessIndices.dropFirst(coverDestinations.count).first.flatMap { MindfulnessCover.image(at: $0) }
    }

    private static func features(withIDs ids: [String]) -> [WellnessFeature] {
        ids.compactMap { id in all.first(where: { $0.id == id }) }
    }
}

struct WellnessHomeSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            featureSection(
                title: "情绪与性格",
                subtitle: "温柔觉察情绪、压力与内在倾向",
                features: WellnessFeature.mindAndPersonality
            )
        }
    }

    private func featureSection(
        title: String,
        subtitle: String,
        features: [WellnessFeature]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: WellnessDestination.hub) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SoundHomeTextColor.title)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(SoundHomeTextColor.detail)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("全部")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(SoundHomeTextColor.detail)
                    .padding(.top, 5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(features) { feature in
                        NavigationLink(value: feature.destination) {
                            WellnessHomeCard(feature: feature)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(height: 140)
        }
    }
}

private struct WellnessHomeCard: View {
    let feature: WellnessFeature

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = WellnessFeature.coverImage(for: feature.destination) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 132)
                    .clipped()
                    .accessibilityHidden(true)
            } else {
                LinearGradient(colors: feature.colors.map(\.color),
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            LinearGradient(colors: [.black.opacity(0.40), .black.opacity(0.72)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(feature.badge)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 23)
                        .background(.black.opacity(0.32))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: feature.icon)
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Text(feature.title)
                    .font(.system(size: 17, weight: .semibold))
                Text(feature.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .foregroundStyle(.white)
            .padding(15)
        }
        .frame(width: 220, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: feature.colors.first?.color.opacity(0.08) ?? .clear, radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct WellnessDestinationView: View {
    let destination: WellnessDestination

    @ViewBuilder
    var body: some View {
        switch destination {
        case .hub:
            WellnessHubView()
        case .healthInsight:
            HealthSleepInsightView()
        case .assessment(let kind):
            WellnessAssessmentView(definition: .definition(for: kind))
        case .breathing:
            BreathingExerciseView()
        case .devices:
            ConnectedHealthDevicesView()
        case .history:
            WellnessHistoryView()
        case .record(let record):
            WellnessRecordDetailView(record: record)
        }
    }
}

struct WellnessHubView: View {
    @ObservedObject private var history = WellnessHistoryStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    hubFeatureSection(
                        title: "睡眠健康",
                        subtitle: "睡眠数据、状态评估与日常记录",
                        features: WellnessFeature.sleepHealth
                    )

                    hubFeatureSection(
                        title: "情绪与性格",
                        subtitle: "了解近期感受与稳定人格倾向",
                        features: WellnessFeature.mindAndPersonality
                    )

                    hubFeatureSection(
                        title: "放松与设备",
                        subtitle: "主动恢复并汇总更多健康数据",
                        features: WellnessFeature.relaxAndDevices
                    )

                    NavigationLink(value: WellnessDestination.history) {
                        historyCard
                    }
                    .buttonStyle(.plain)

                    privacyNotice
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WellnessTopBar(title: "身心探索")
        }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("给自己一点了解的时间")
                .font(.system(size: 20, weight: .semibold))
            Text("从睡眠、情绪到性格节律，所有记录默认仅保存在 App 本地。")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.82))
                .lineSpacing(3)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background { WellnessCoverBackground(image: WellnessFeature.hubCoverImage) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func hubCard(_ feature: WellnessFeature) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: feature.icon)
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityHidden(true)
            }
            Text(feature.title)
                .font(.system(size: 15, weight: .semibold))
            Text(feature.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        .background { WellnessCoverBackground(image: WellnessFeature.coverImage(for: feature.destination)) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func hubFeatureSection(
        title: String,
        subtitle: String,
        features: [WellnessFeature]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(features) { feature in
                    NavigationLink(value: feature.destination) {
                        hubCard(feature)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.30))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text("测评记录")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(history.records.isEmpty ? "完成测评后，可在这里查看变化" : "已保存 \(history.records.count) 次测评结果")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .background { WellnessCoverBackground(image: WellnessFeature.coverImage(for: .history)) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
    }

    private var privacyNotice: some View {
        Label {
            Text("测评结果默认仅保存在当前设备，不会用于广告推荐，仅用于自我觉察，不代替专业诊断。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 4)
    }
}

private struct WellnessCoverBackground: View {
    let image: UIImage?
    var fallback: Color = Color(white: 0.12)

    var body: some View {
        cover.allowsHitTesting(false)
    }

    @ViewBuilder
    private var cover: some View {
        if let image {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.46), .black.opacity(0.77)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
            }
            .accessibilityHidden(true)
        } else {
            fallback
        }
    }
}

struct WellnessAssessmentView: View {
    let definition: WellnessAssessmentDefinition

    private var coverImage: UIImage? {
        WellnessFeature.coverImage(for: .assessment(definition.kind))
    }

    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var history = WellnessHistoryStore.shared
    @ObservedObject private var membership = SleepMembershipSession.shared
    @State private var currentIndex = 0
    @State private var answers: [String: Int] = [:]
    @State private var result: WellnessAssessmentRecord?
    @State private var pendingMBTIResult: WellnessAssessmentRecord?
    @State private var showMBTIUnlockPrompt = false
    @State private var showMembershipAfterPrompt = false
    @State private var showMembership = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if let result {
                resultContent(result)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
            } else {
                questionContent
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WellnessTopBar(title: definition.title)
        }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            restoreCachedMBTIResultIfNeeded()
        }
        .sheet(isPresented: $showMBTIUnlockPrompt, onDismiss: {
            guard showMembershipAfterPrompt else { return }
            showMembershipAfterPrompt = false
            showMembership = true
        }) {
            SleepVIPUpgradeSheet(
                contentTitle: definition.title,
                contentKind: .mbti,
                onUpgrade: {
                    showMembershipAfterPrompt = true
                    showMBTIUnlockPrompt = false
                },
                onCancel: {
                    showMBTIUnlockPrompt = false
                }
            )
        }
        .fullScreenCover(isPresented: $showMembership, onDismiss: {
            revealPendingMBTIResultIfEntitled()
        }) {
            NavigationStack { SleepMembershipView() }
                .environmentObject(settings)
        }
    }

    private var questionContent: some View {
        let question = definition.questions[currentIndex]
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                assessmentHeader

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("第 \(currentIndex + 1) 题")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(definition.colors.first?.color ?? .blue)
                        Spacer()
                        Text("\(currentIndex + 1) / \(definition.questions.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: Double(currentIndex + 1), total: Double(definition.questions.count))
                        .tint(definition.colors.first?.color ?? .blue)

                    Text(question.text)
                        .font(.system(size: 21, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }

                VStack(spacing: 10) {
                    ForEach(question.choices) { choice in
                        choiceButton(choice, question: question)
                    }
                }

                HStack(spacing: 12) {
                    Button("上一题") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                        saveMBTIDraftIfNeeded()
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentIndex == 0)

                    Button(currentIndex == definition.questions.count - 1 ? "查看结果" : "下一题") {
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(definition.colors.first?.color ?? .blue)
                    .frame(maxWidth: .infinity)
                    .disabled(answers[question.id] == nil)
                }
                .controlSize(.large)

                Text("本测评用于自我觉察，不构成医疗诊断或治疗建议。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .padding(.bottom, 28)
        }
    }

    private var assessmentHeader: some View {
        let image = coverImage
        return HStack(spacing: 14) {
            Image(systemName: definition.icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(colors: definition.colors.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(definition.introduction)
                    .font(.system(size: 13))
                    .foregroundStyle(image == nil ? Color.primary : .white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(definition.periodText)
                    .font(.system(size: 11))
                    .foregroundStyle(image == nil ? Color.secondary : .white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: image == nil ? nil : 136, alignment: .leading)
        .background { WellnessCoverBackground(image: image, fallback: Color(.secondarySystemGroupedBackground)) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func choiceButton(_ choice: WellnessChoice, question: WellnessQuestion) -> some View {
        let isSelected = answers[question.id] == choice.score
        let color = definition.colors.first?.color ?? .blue
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                answers[question.id] = choice.score
            }
            saveMBTIDraftIfNeeded()
        } label: {
            HStack {
                Text(choice.text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? color : Color.secondary.opacity(0.45))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isSelected ? color.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.48) : Color.clear, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        guard answers[definition.questions[currentIndex].id] != nil else { return }
        if currentIndex < definition.questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex += 1
            }
            saveMBTIDraftIfNeeded()
        } else {
            let newResult = definition.makeResult(answers: answers)
            if definition.kind == .mbti && !membership.isVIPActive {
                pendingMBTIResult = newResult
                saveMBTIDraftIfNeeded()
                showMBTIUnlockPrompt = true
            } else {
                showResult(newResult)
            }
        }
    }

    private func revealPendingMBTIResultIfEntitled() {
        guard membership.isVIPActive, let pendingMBTIResult else { return }
        self.pendingMBTIResult = nil
        showResult(pendingMBTIResult)
    }

    private func showResult(_ newResult: WellnessAssessmentRecord) {
        if definition.kind == .mbti {
            MBTIAssessmentDraftStore.clear()
        }
        history.add(newResult)
        withAnimation(.easeInOut(duration: 0.25)) {
            result = newResult
        }
    }

    private func resultContent(_ result: WellnessAssessmentRecord) -> some View {
        let image = coverImage
        return ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.14), lineWidth: 11)
                        Circle()
                            .trim(from: 0, to: min(1, Double(result.score) / Double(max(result.maximumScore, 1))))
                            .stroke(
                                LinearGradient(colors: definition.colors.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 11, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(definition.kind == .mbti ? mbtiCode(result.level) : "\(result.score)")
                                .font(.system(size: definition.kind == .mbti ? 27 : 32, weight: .bold, design: .rounded))
                            Text(definition.kind == .mbti ? "人格类型" : (result.metrics.isEmpty ? "/ \(result.maximumScore)" : "综合画像"))
                                .font(.caption)
                                .foregroundStyle(image == nil ? Color.secondary : .white.opacity(0.8))
                        }
                    }
                    .frame(width: 138, height: 138)

                    Text(definition.kind == .mbti ? mbtiNickname(result.level) : result.level)
                        .font(.title2.weight(.semibold))
                    Text(result.summary)
                        .font(.system(size: 14))
                        .foregroundStyle(image == nil ? Color.secondary : .white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .foregroundStyle(image == nil ? Color.primary : .white)
                .background { WellnessCoverBackground(image: image, fallback: Color(.secondarySystemGroupedBackground)) }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if !result.metrics.isEmpty {
                    metricSection(result.metrics)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label(definition.kind == .mbti ? "人格解读" : "给你的建议", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    ForEach(Array(result.suggestions.enumerated()), id: \.offset) { index, suggestion in
                        HStack(alignment: .top, spacing: 11) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(definition.colors.first?.color ?? .blue)
                                .clipShape(Circle())
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button("重新测评") {
                    if definition.kind == .mbti {
                        history.removeRecords(for: WellnessAssessmentKind.mbti.rawValue)
                        MBTIAssessmentDraftStore.clear()
                        pendingMBTIResult = nil
                    }
                    answers = [:]
                    currentIndex = 0
                    withAnimation { self.result = nil }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text(definition.kind == .mbti ? "MBTI 结果反映当前作答呈现的人格偏好，不是能力判断或固定标签，也不是官方认证测评。" : "结果仅供自我观察，不用于疾病诊断。感受持续或明显影响生活时，请联系有资质的专业人员。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .padding(.bottom, 28)
        }
    }

    private func metricSection(_ metrics: [WellnessMetricResult]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(definition.kind == .mbti ? "四维偏好强度" : "五维画像")
                .font(.headline)
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(metric.title).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(metric.value)%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.12))
                            Capsule()
                                .fill(LinearGradient(colors: definition.colors.map(\.color), startPoint: .leading, endPoint: .trailing))
                                .frame(width: geometry.size.width * CGFloat(metric.value) / 100)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func mbtiCode(_ level: String) -> String {
        level.components(separatedBy: " · ").first ?? level
    }

    private func mbtiNickname(_ level: String) -> String {
        let parts = level.components(separatedBy: " · ")
        return parts.count > 1 ? parts[1] : level
    }

    private func restoreCachedMBTIResultIfNeeded() {
        guard definition.kind == .mbti,
              result == nil,
              answers.isEmpty,
              pendingMBTIResult == nil else { return }

        if let cachedResult = history.latestRecord(for: WellnessAssessmentKind.mbti.rawValue) {
            result = cachedResult
            return
        }

        guard let draft = MBTIAssessmentDraftStore.load(), !draft.answers.isEmpty else { return }
        answers = draft.answers
        currentIndex = min(max(0, draft.currentIndex), definition.questions.count - 1)
    }

    private func saveMBTIDraftIfNeeded(currentIndex index: Int? = nil) {
        guard definition.kind == .mbti else { return }
        MBTIAssessmentDraftStore.save(
            answers: answers,
            currentIndex: index ?? currentIndex
        )
    }
}

struct WellnessHistoryView: View {
    @ObservedObject private var history = WellnessHistoryStore.shared

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if history.records.isEmpty {
                EmptyStateView(title: "暂无测评记录", systemImage: "clock.arrow.circlepath", message: "完成任意身心测评后，结果会保存在这里。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(history.records) { record in
                            NavigationLink(value: WellnessDestination.record(record)) {
                                historyRow(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { WellnessTopBar(title: "测评记录") }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func historyRow(_ record: WellnessAssessmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title).font(.headline)
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(record.assessmentID == WellnessAssessmentKind.mbti.rawValue ? mbtiCode(record.level) : (record.metrics.isEmpty ? "\(record.score) 分" : "画像"))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.blue)
                    Text(record.assessmentID == WellnessAssessmentKind.mbti.rawValue ? mbtiNickname(record.level) : record.level)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(record.summary)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .contentShape(Rectangle())
    }

    private func mbtiCode(_ level: String) -> String {
        level.components(separatedBy: " · ").first ?? level
    }

    private func mbtiNickname(_ level: String) -> String {
        let parts = level.components(separatedBy: " · ")
        return parts.count > 1 ? parts[1] : level
    }
}

struct WellnessRecordDetailView: View {
    let record: WellnessAssessmentRecord

    private var accentColor: Color {
        guard let kind = WellnessAssessmentKind(rawValue: record.assessmentID) else { return .blue }
        return WellnessAssessmentDefinition.definition(for: kind).colors.first?.color ?? .blue
    }

    private var isMBTI: Bool {
        record.assessmentID == WellnessAssessmentKind.mbti.rawValue
    }

    private var mbtiCode: String {
        record.level.components(separatedBy: " · ").first ?? record.level
    }

    private var mbtiNickname: String {
        let parts = record.level.components(separatedBy: " · ")
        return parts.count > 1 ? parts[1] : record.level
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 11) {
                        Text(isMBTI ? mbtiCode : (record.metrics.isEmpty ? "\(record.score)" : "\(record.score)%"))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        Text(isMBTI ? mbtiNickname : record.level).font(.title3.weight(.semibold))
                        Text(record.date.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(record.summary)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if !record.metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text(isMBTI ? "四维偏好强度" : "五维画像").font(.headline)
                            ForEach(record.metrics) { metric in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(metric.title).font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text("\(metric.value)%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    }
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(accentColor.opacity(0.12))
                                            Capsule().fill(accentColor).frame(width: geometry.size.width * CGFloat(metric.value) / 100)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Label(isMBTI ? "人格解读" : "建议", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        ForEach(Array(record.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(accentColor)
                                    .clipShape(Circle())
                                Text(suggestion).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text(isMBTI ? "人格类型是理解自己的参考，不代表能力高低，也不会限制你的成长。" : "历史结果仅用于自我观察，不构成医疗诊断。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { WellnessTopBar(title: record.title) }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct HealthSleepInsightView: View {
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var selectedDays = 7

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    healthHero

                    Picker("统计周期", selection: $selectedDays) {
                        Text("近 7 天").tag(7)
                        Text("近 30 天").tag(30)
                    }
                    .pickerStyle(.segmented)

                    if healthKit.isLoadingInsight || healthKit.isRequestingAuthorization {
                        VStack(spacing: 14) {
                            ProgressView()
                                .controlSize(.large)
                            Text(healthKit.isRequestingAuthorization ? "等待 Apple 健康授权…" : "正在读取睡眠数据…")
                                .font(.system(size: 14, weight: .medium))
                            if healthKit.isRequestingAuthorization {
                                Text("请在弹出的系统授权页面选择允许；如果以前已经选择过，将直接开始读取。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else if let insight = healthKit.recentInsight {
                        insightContent(insight)
                    } else {
                        emptyHealthContent
                    }

                    Label("数据仅在本机读取和分析，不会发送给广告或统计服务。不同设备可提供的数据类型可能不同。", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { WellnessTopBar(title: "睡眠洞察") }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: selectedDays) { days in
            guard healthKit.isAuthorized else { return }
            Task { await healthKit.loadRecentInsight(days: days) }
        }
    }

    private var healthHero: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 76))
                .foregroundStyle(.white.opacity(0.17))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 24)
            VStack(alignment: .leading, spacing: 7) {
                Text("来自 Apple 健康")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                Text("看见睡眠中的恢复")
                    .font(.system(size: 21, weight: .semibold))
                Text("整合睡眠阶段与睡眠期间的身体指标")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background { WellnessCoverBackground(image: WellnessFeature.coverImage(for: .healthInsight)) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyHealthContent: some View {
        VStack(spacing: 15) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.blue)
            Text(healthKit.insightMessage ?? "授权后读取睡眠阶段、睡眠心率、HRV、呼吸频率和血氧等数据。")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await healthKit.requestAndLoadRecentInsight(days: selectedDays) }
            } label: {
                Label("授权并开始分析", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(healthKit.isLoadingInsight || healthKit.isRequestingAuthorization)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func insightContent(_ insight: HealthSleepInsight) -> some View {
        HStack(spacing: 12) {
            insightMetric(title: "平均睡眠", value: durationText(insight.averageSleep), icon: "bed.double.fill", color: .indigo)
            insightMetric(title: "记录夜数", value: "\(insight.nights) 晚", icon: "calendar", color: .blue)
        }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("睡眠阶段").font(.headline)
                Spacer()
                Text("近 \(selectedDays) 天").font(.caption).foregroundStyle(.secondary)
            }
            stageRow("深度睡眠", duration: insight.deepSleep, percentage: insight.deepPercentage, color: .indigo)
            stageRow("核心睡眠", duration: insight.coreSleep, percentage: insight.corePercentage, color: .blue)
            stageRow("快速眼动", duration: insight.remSleep, percentage: insight.remPercentage, color: .cyan)
            if insight.awakeTime > 0 {
                stageRow("睡中清醒", duration: insight.awakeTime, percentage: min(100, insight.awakeTime / max(insight.totalSleep + insight.awakeTime, 1) * 100), color: .orange)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        let bodyMetrics = healthBodyMetrics(insight)
        if !bodyMetrics.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("睡眠期间身体指标").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(bodyMetrics) { metric in
                        VStack(alignment: .leading, spacing: 7) {
                            Image(systemName: metric.icon).foregroundStyle(metric.color)
                            Text(metric.value).font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text(metric.title).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        Button {
            Task { await healthKit.loadRecentInsight(days: selectedDays) }
        } label: {
            Label("刷新健康数据", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func insightMetric(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func stageRow(_ title: String, duration: TimeInterval, percentage: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(durationText(duration)) · \(Int(percentage.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12))
                    Capsule().fill(color).frame(width: geometry.size.width * CGFloat(min(100, percentage)) / 100)
                }
            }
            .frame(height: 8)
        }
    }

    private func healthBodyMetrics(_ insight: HealthSleepInsight) -> [HealthBodyMetric] {
        var metrics: [HealthBodyMetric] = []
        if let value = insight.averageHeartRate {
            metrics.append(.init(title: "平均心率", value: "\(Int(value.rounded())) 次/分", icon: "heart.fill", color: .pink))
        }
        if let value = insight.averageHRV {
            metrics.append(.init(title: "心率变异性", value: String(format: "%.0f 毫秒", value), icon: "waveform.path.ecg", color: .red))
        }
        if let value = insight.averageRespiratoryRate {
            metrics.append(.init(title: "呼吸频率", value: String(format: "%.1f 次/分", value), icon: "lungs.fill", color: .teal))
        }
        if let value = insight.averageOxygenSaturation {
            metrics.append(.init(title: "血氧饱和度", value: String(format: "%.1f%%", value), icon: "drop.fill", color: .blue))
        }
        if let value = insight.averageWristTemperature {
            metrics.append(.init(title: "睡眠腕温", value: String(format: "%.1f℃", value), icon: "thermometer.medium", color: .orange))
        }
        return metrics
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        return "\(minutes / 60)小时\(minutes % 60)分"
    }
}

private struct HealthBodyMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}

struct BreathingExerciseView: View {
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDuration = 60
    @State private var remaining = 60
    @State private var isRunning = false
    @State private var phaseStep = 0
    @State private var completionMessage: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isDark: Bool { colorScheme == .dark }

    private var backgroundColors: [Color] {
        isDark
            ? [Color(red: 0.045, green: 0.105, blue: 0.11), Color(red: 0.045, green: 0.065, blue: 0.10)]
            : [Color(red: 0.91, green: 0.98, blue: 0.96), Color(red: 0.90, green: 0.95, blue: 0.99)]
    }

    private var circleColors: [Color] {
        isDark
            ? [Color(red: 0.13, green: 0.29, blue: 0.29), Color(red: 0.08, green: 0.17, blue: 0.21)]
            : [Color.white, Color(red: 0.74, green: 0.89, blue: 0.88)]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Picker("练习时长", selection: $selectedDuration) {
                    Text("1 分钟").tag(60)
                    Text("3 分钟").tag(180)
                    Text("5 分钟").tag(300)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 22)

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: circleColors, center: .center, startRadius: 12, endRadius: 118)
                        )
                        .overlay {
                            Circle().strokeBorder(Color.teal.opacity(isDark ? 0.42 : 0.24), lineWidth: 1)
                        }
                        .frame(width: 220, height: 220)
                        .scaleEffect(circleScale)
                        .shadow(color: .teal.opacity(0.16), radius: 28)
                        .animation(.easeInOut(duration: phaseAnimationDuration), value: phaseStep)

                    VStack(spacing: 8) {
                        Text(phaseText)
                            .font(.system(size: 25, weight: .semibold))
                        Text(timeText)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.82))
                            .monospacedDigit()
                    }
                }

                Text(phaseHint)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 46, height: 46)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)

                    Button {
                        toggleRunning()
                    } label: {
                        Label(isRunning ? "暂停" : (remaining == selectedDuration ? "开始练习" : "继续"), systemImage: isRunning ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.08, green: 0.42, blue: 0.43))
                    .foregroundStyle(.white)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)

                Text("完成后可在获得授权的情况下写入 Apple 健康正念时长")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
            .padding(.top, 22)
        }
        .safeAreaInset(edge: .top, spacing: 0) { WellnessTopBar(title: "呼吸练习") }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: selectedDuration) { value in
            isRunning = false
            remaining = value
            phaseStep = 0
        }
        .onReceive(timer) { _ in tick() }
        .alert("练习完成", isPresented: Binding(
            get: { completionMessage != nil },
            set: { if !$0 { completionMessage = nil } }
        )) {
            Button("完成", role: .cancel) { completionMessage = nil }
        } message: {
            Text(completionMessage ?? "")
        }
    }

    private var cyclePosition: Int { phaseStep % 10 }
    private var phaseText: String {
        switch cyclePosition {
        case 0...3: return "慢慢吸气"
        case 4...5: return "轻轻停留"
        default: return "缓缓呼气"
        }
    }
    private var phaseHint: String {
        switch cyclePosition {
        case 0...3: return "让空气自然进入身体，不需要刻意用力"
        case 4...5: return "放松肩膀，感受这一刻的安静"
        default: return "比吸气更慢一点，把紧绷轻轻放下"
        }
    }
    private var circleScale: CGFloat {
        switch cyclePosition {
        case 0...3: return 1.12
        case 4...5: return 1.12
        default: return 0.82
        }
    }
    private var phaseAnimationDuration: Double { cyclePosition == 0 || cyclePosition == 6 ? 3.8 : 0.35 }
    private var timeText: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }

    private func toggleRunning() {
        if remaining <= 0 { reset() }
        isRunning.toggle()
        if isRunning && remaining == selectedDuration {
            Task { _ = await healthKit.requestMindfulnessAuthorization() }
        }
    }

    private func reset() {
        isRunning = false
        remaining = selectedDuration
        phaseStep = 0
    }

    private func tick() {
        guard isRunning else { return }
        if remaining > 0 {
            remaining -= 1
            phaseStep = (phaseStep + 1) % 10
        }
        guard remaining == 0 else { return }
        isRunning = false
        let end = Date()
        let start = end.addingTimeInterval(-Double(selectedDuration))
        Task {
            let saved = await healthKit.saveMindfulSession(start: start, end: end)
            completionMessage = saved ? "本次练习已写入 Apple 健康正念时长。" : "本次练习已完成。你可以在系统设置中允许时光睡眠写入正念时长。"
        }
    }
}

struct ConnectedHealthDevicesView: View {
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var selectedProvider: HealthDeviceProvider?

    private let providers: [HealthDeviceProvider] = [
        .init(name: "Oura", detail: "睡眠阶段、恢复、心率与血氧", icon: "circle.hexagongrid.fill", color: .purple, website: URL(string: "https://support.ouraring.com/")!),
        .init(name: "Fitbit", detail: "睡眠记录、活动与身体指标", icon: "diamond.fill", color: .teal, website: URL(string: "https://support.google.com/fitbit/")!),
        .init(name: "Withings", detail: "睡眠、心率、体重与健康设备", icon: "bed.double.fill", color: .blue, website: URL(string: "https://support.withings.com/")!),
        .init(name: "Garmin", detail: "睡眠、压力、血氧与身体电量", icon: "triangle.fill", color: .blue, website: URL(string: "https://support.garmin.com/")!),
        .init(name: "WHOOP", detail: "睡眠表现、恢复与心率变异性", icon: "waveform.path.ecg", color: .red, website: URL(string: "https://support.whoop.com/")!)
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    appleHealthCard

                    VStack(alignment: .leading, spacing: 5) {
                        Text("更多健康设备").font(.headline)
                        Text("优先通过厂商 App 与 Apple 健康同步，无需把账号密码交给时光睡眠。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(providers) { provider in
                        Button {
                            selectedProvider = provider
                        } label: {
                            providerRow(provider)
                        }
                        .buttonStyle(.plain)
                    }

                    Label("部分厂商或设备不会向 Apple 健康写入完整睡眠阶段。直接云端连接需要厂商审核、OAuth 凭据和服务端支持，未完成前不会显示虚假的“已连接”。", systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { WellnessTopBar(title: "智能设备") }
        .appEdgeSwipeBack()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedProvider) { provider in
            providerGuide(provider)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var appleHealthCard: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "heart.fill")
                .font(.system(size: 82))
                .foregroundStyle(.white.opacity(0.15))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 22)
            VStack(alignment: .leading, spacing: 8) {
                Text("Apple 健康")
                    .font(.system(size: 20, weight: .semibold))
                Text("汇总 Apple Watch 与其他健康设备的数据")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.82))
                Button {
                    Task { await healthKit.requestAndLoadRecentInsight() }
                } label: {
                    Text(healthKit.isAuthorized ? "刷新同步" : "立即授权")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background { WellnessCoverBackground(image: WellnessFeature.coverImage(for: .devices)) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func providerRow(_ provider: HealthDeviceProvider) -> some View {
        HStack(spacing: 14) {
            Image(systemName: provider.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(provider.color)
                .frame(width: 48, height: 48)
                .background(provider.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(provider.name).font(.headline).foregroundStyle(.primary)
                Text(provider.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("连接指南")
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
        }
        .padding(15)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func providerGuide(_ provider: HealthDeviceProvider) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: provider.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(provider.color)
                        .frame(width: 58, height: 58)
                        .background(provider.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.name).font(.title3.weight(.semibold))
                        Text(provider.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    guideStep(1, "打开 \(provider.name) 官方 App，并确认设备已经完成同步。")
                    guideStep(2, "在厂商 App 的健康共享设置中查看是否可以连接 Apple 健康。")
                    guideStep(3, "允许写入睡眠和相关身体指标后，回到时光睡眠的“睡眠洞察”授权读取。")
                }

                Link(destination: provider.website) {
                    Label("查看官方帮助", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(provider.color)

                Spacer()
            }
            .padding(20)
            .navigationTitle("\(provider.name) 连接指南")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func guideStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 23, height: 23)
                .background(.blue)
                .clipShape(Circle())
            Text(text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HealthDeviceProvider: Identifiable {
    let name: String
    let detail: String
    let icon: String
    let color: Color
    let website: URL

    var id: String { name }
}

struct WellnessTopBar: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Spacer()
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private extension WellnessColorToken {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .cyan: return .cyan
        case .teal: return .teal
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        case .indigo: return .indigo
        case .mint: return .mint
        }
    }
}
