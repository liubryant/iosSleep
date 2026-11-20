import SwiftUI
import UIKit

enum SoundHomeTextColor {
    static let title = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .label
    })
    static let detail = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.65, alpha: 1) : .secondaryLabel
    })
}

struct SoundHomeView: View {
    @ScaledMetric(relativeTo: .title2) private var greetingFontSize = 25.0
    @ScaledMetric(relativeTo: .subheadline) private var membershipBannerFontSize = 13.0
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @EnvironmentObject private var mindfulnessPlayer: MindfulnessAudioPlayer
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var weather = HomeWeather()
    @ObservedObject private var membership = SleepMembershipSession.shared
    @State private var selectedCategory: SoundCategory = .whiteNoise
    @State private var vipPrompt: SleepVIPPromptContent?
    @State private var showMembershipAfterPrompt = false
    @State private var showMembership = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    private let searchResultsAnchor = "sound-search-results"

    private var isSearching: Bool {
        !library.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasMiniPlayer: Bool {
        player.currentScene != nil || storyPlayer.currentStory != nil || mindfulnessPlayer.currentTrack != nil
    }

    private let mindfulnessItems: [SoundHomeMindfulnessItem] = [
        .init(title: SleepL10n.text("深度睡眠疗愈"), subtitle: SleepL10n.text("卸下疲惫，沉入安稳梦境"), track: .deepSleep),
        .init(title: SleepL10n.text("日间提神"), subtitle: SleepL10n.text("唤醒精神，找回清晰专注"), track: .daytimeEnergy),
        .init(title: SleepL10n.text("散步冥想"), subtitle: SleepL10n.text("跟随脚步，感受此时此地"), track: .walking),
        .init(title: SleepL10n.text("睡前释放情绪"), subtitle: SleepL10n.text("温柔放下今天的情绪"), track: .emotionalRelease),
        .init(title: SleepL10n.text("安定身心助眠"), subtitle: SleepL10n.text("舒缓呼吸，让身体松下来"), track: .calmingSleep),
        .init(title: SleepL10n.text("缓解疲倦"), subtitle: SleepL10n.text("短暂休息，恢复身心能量"), track: .fatigueRelief),
        .init(title: SleepL10n.text("快速入睡"), subtitle: SleepL10n.text("平静思绪，更快进入睡眠"), track: .quickSleep),
        .init(title: SleepL10n.text("考前失眠解放"), subtitle: SleepL10n.text("减少紧张，安心迎接明天"), track: .examSleep)
    ]

    private var displayedScenes: [SoundScene] {
        if isSearching { return library.filteredScenes }
        let scenes = selectedCategory.scenes(from: library.scenes, library: library)
        guard selectedCategory == .whiteNoise, !library.favorites.isEmpty else { return scenes }
        return scenes.filter { library.isFavorite($0) } + scenes.filter { !library.isFavorite($0) }
    }

    private var sceneSections: [SoundHomeSection] {
        var sections: [SoundHomeSection] = []
        var sectionIndex = 0
        var startIndex = 0
        let scenes = displayedScenes

        while startIndex < scenes.count {
            let endIndex = min(startIndex + 6, scenes.count)
            let sectionScenes = Array(scenes[startIndex..<endIndex])
            sectionIndex += 1
            sections.append(SoundHomeSection(index: sectionIndex, scenes: sectionScenes, showsAdAfter: sectionScenes.count == 6))
            startIndex = endIndex
        }

        return sections
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    LazyVStack(spacing: 16) {
                        if !isSearching && selectedCategory == .whiteNoise {
                            DailyInspirationCard()
                            mindfulnessSection
                            if !membership.isVIPActive {
                                membershipBanner
                            }
                            WellnessHomeSection()
                                .padding(.top, 8)
                        }

                        if isSearching {
                            Text(SleepL10n.text("声音搜索结果"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SoundHomeTextColor.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(searchResultsAnchor)
                        } else {
                            soundSectionHeader
                        }

                        ForEach(sceneSections) { section in
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(section.scenes) { scene in
                                    soundCard(for: scene)
                                }
                            }

                            if section.showsAdAfter {
                                DrawFeedAdCardView()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.bottom, hasMiniPlayer ? miniPlayerOverlayInset : 0)
                }
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    soundTopBar
                    soundSearchBar
                        .frame(maxWidth: 1100)
                        .padding(.bottom, 12)
                        .onSubmit { scrollToSearchResults(using: scrollProxy) }
                }
                    .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
            }
            .task(id: library.searchText) {
                do {
                    try await Task.sleep(nanoseconds: 250_000_000)
                    scrollToSearchResults(using: scrollProxy)
                } catch is CancellationError {
                    // A newer query will position its own results.
                } catch {}
            }
            .task(id: scenePhase == .active && settings.agreementAccepted) {
                if scenePhase == .active && settings.agreementAccepted {
                    weather.refresh()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if library.scenes.isEmpty {
                    EmptyStateView(title: SleepL10n.text("暂无声音资源"), systemImage: "waveform", message: SleepL10n.text("请确认 SoundResources 已导入。"))
                } else if displayedScenes.isEmpty {
                    EmptyStateView(title: SleepL10n.text("没有匹配的声音"), systemImage: "magnifyingglass",
                                   message: isSearching ? SleepL10n.text("试试更短的关键词，比如「雨」或「海浪」。") : selectedCategory.emptyMessage)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: QuickActionService.didRequestNature)) { _ in
                selectedCategory = .nature
                library.searchText = ""
            }
            }
            .navigationDestination(for: WellnessDestination.self) { destination in
                WellnessDestinationView(destination: destination)
            }
        }
        .sheet(item: $vipPrompt, onDismiss: {
            guard showMembershipAfterPrompt else { return }
            showMembershipAfterPrompt = false
            showMembership = true
        }) { prompt in
            SleepVIPUpgradeSheet(
                contentTitle: prompt.title,
                contentKind: prompt.kind,
                onUpgrade: {
                    showMembershipAfterPrompt = true
                    vipPrompt = nil
                },
                onCancel: { vipPrompt = nil }
            )
        }
        .fullScreenCover(isPresented: $showMembership) {
            NavigationStack { SleepMembershipView() }
                .environmentObject(settings)
        }
    }

    private var membershipBanner: some View {
        Button {
            showMembership = true
        } label: {
            HStack(spacing: 10) {
                SleepMembershipDiamond()
                    .frame(width: 20, height: 16)
                    .accessibilityHidden(true)

                Text(SleepL10n.text("解锁更多助眠声音与故事"))
                    .font(.system(size: membershipBannerFontSize))
                    .foregroundStyle(Color(white: 0.67))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Text(SleepL10n.text("开通会员"))
                        .font(.system(size: membershipBannerFontSize, weight: .medium))
                        .fixedSize()
                    Image(systemName: "chevron.right")
                    .flipsForRightToLeftLayoutDirection(true)
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color(red: 0.70, green: 0.64, blue: 0.53))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var mindfulnessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                MindfulnessHomeView()
            } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(SleepL10n.text("正念冥想"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SoundHomeTextColor.title)
                    Text(SleepL10n.text("跟随声音，把注意力带回当下"))
                        .font(.system(size: 11))
                        .foregroundStyle(SoundHomeTextColor.detail)
                }

                Spacer()

                    HStack(spacing: 4) {
                        Text(SleepL10n.text("更多"))
                        Image(systemName: "chevron.right")
                    .flipsForRightToLeftLayoutDirection(true)
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
                LazyHGrid(
                    rows: [GridItem(.fixed(235))],
                    spacing: 16
                ) {
                    ForEach(mindfulnessItems.prefix(6)) { item in
                        if item.track.requiresVIP && !membership.isVIPActive {
                            Button {
                                vipPrompt = SleepVIPPromptContent(title: item.title, kind: .mindfulness)
                            } label: {
                                mindfulnessCard(item)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                MindfulnessPlayerView(track: item.track)
                            } label: {
                                mindfulnessCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(height: 240)
        }
    }

    @ViewBuilder
    private func soundCard(for scene: SoundScene) -> some View {
        if scene.requiresVIP && !membership.isVIPActive {
            SoundCardView(scene: scene, isVIPContent: true) {
                vipPrompt = SleepVIPPromptContent(title: scene.title, kind: .sound)
            }
        } else {
            SoundCardView(scene: scene, isVIPContent: scene.requiresVIP)
        }
    }

    private var soundSectionHeader: some View {
        sectionHeader(title: SleepL10n.text("大自然入眠"), subtitle: SleepL10n.text("枕着山海风雨，慢慢沉入梦乡"))
            .padding(.top, selectedCategory == .whiteNoise ? 8 : 0)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: SleepL10n.text(title))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SoundHomeTextColor.title)
            Text(verbatim: SleepL10n.text(subtitle))
                .font(.system(size: 11))
                .foregroundStyle(SoundHomeTextColor.detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mindfulnessCard(_ item: SoundHomeMindfulnessItem) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                if let index = item.track.coverIndex, let image = MindfulnessCover.image(at: index) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: 150, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                if item.track.requiresVIP { MindfulnessVIPBadge().padding(9) }
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "play.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.30))
                    .clipShape(Circle())
                    .padding(9)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: SleepL10n.text(item.title))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(SoundHomeTextColor.title)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
    }


    private var soundFeatureCategories: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 0, alignment: .center),
                count: 4
            ),
            spacing: 10
        ) {
            ForEach(SoundFeature.allCases) { feature in
                if feature == .stories {
                    Button {
                        QuickActionService.shared.request(.stories)
                    } label: {
                        soundFeatureLabel(feature)
                    }
                    .buttonStyle(.plain)
                } else if feature == .relax || feature == .focus {
                    NavigationLink(value: WellnessDestination.hub) {
                        soundFeatureLabel(feature)
                    }
                    .buttonStyle(.plain)
                } else if feature == .mindfulness {
                    NavigationLink {
                        MindfulnessHomeView()
                    } label: {
                        soundFeatureLabel(feature)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        if let category = feature.category {
                            selectedCategory = category
                        }
                    } label: {
                        soundFeatureLabel(feature)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.leading, -8)
        .padding(.bottom, 8)
    }

    private func soundFeatureLabel(_ feature: SoundFeature) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        feature.category == selectedCategory
                            ? Color.blue.opacity(0.10)
                            : Color.clear
                    )
                    .frame(width: 56, height: 54)
                Image(systemName: feature.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(feature.color)
                    .frame(width: 48, height: 48)
                    .background(feature.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }

            Text(verbatim: SleepL10n.text(feature.title))
                .font(.caption)
                .fontWeight(feature.category == selectedCategory ? .semibold : .regular)
                .foregroundStyle(feature.category == selectedCategory ? Color.blue : Color.secondary)
                .lineLimit(1)
        }
        .frame(width: 64)
        .frame(height: 72)
        .contentShape(Rectangle())
    }

    private var soundTopBar: some View {
        HStack(spacing: 8) {
            if settings.agreementAccepted && weather.isAvailable {
                weatherBadge
                    .fixedSize()
            }

            Text(verbatim: SleepL10n.text(greetingText))
                .font(.system(size: greetingFontSize, weight: .bold))
                .foregroundStyle(SoundHomeTextColor.title)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            filterMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 3)
        .padding(.bottom, 13)
    }

    @ViewBuilder
    private var weatherBadge: some View {
        if weather.authorization == .notDetermined {
            Button(action: weather.requestAccess) { weatherBadgeLabel }
                .buttonStyle(.plain)
                .accessibilityLabel(SleepL10n.text("开启本地天气定位"))
        } else {
            Menu {
                if weather.authorization == .authorizedWhenInUse || weather.authorization == .authorizedAlways {
                    Button(SleepL10n.text("刷新天气"), systemImage: "arrow.clockwise", action: weather.refresh)
                } else {
                    Button(SleepL10n.text("在设置中开启定位"), systemImage: "location") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                Link(SleepL10n.text("天气数据来自 Open-Meteo"), destination: URL(string: "https://open-meteo.com/")!)
            } label: {
                weatherBadgeLabel
            }
            .accessibilityLabel(weather.current.map {
                SleepL10n.format("{0}，{1} 摄氏度", [String(describing: $0.appearance.description), String(describing: $0.temperatureText)])
            } ?? SleepL10n.text("本地天气暂不可用"))
        }
    }

    private var weatherBadgeLabel: some View {
        let conditions = weather.current
        return HStack(spacing: 4) {
            Image(systemName: conditions?.appearance.symbol ?? "cloud.sun.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(conditions?.appearance.tint ?? Color.orange)
                .accessibilityHidden(true)
            Text(SleepL10n.text(conditions.map { "\($0.temperatureText)°" } ?? "--°"))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(SoundHomeTextColor.title)
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var soundSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 24)
                .accessibilityHidden(true)

            TextField(SleepL10n.text("搜索雨声、森林、海浪"), text: $library.searchText)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !library.searchText.isEmpty {
                Button {
                    library.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SleepL10n.text("清除搜索"))
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    private func scrollToSearchResults(using proxy: ScrollViewProxy) {
        guard isSearching, !displayedScenes.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            proxy.scrollTo(searchResultsAnchor, anchor: .top)
        }
    }

    private var soundCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SoundCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(verbatim: SleepL10n.text(category.title))
                            .font(.subheadline.weight(selectedCategory == category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(selectedCategory == category ? Color.blue : Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var filterMenu: some View {
        SoundOptionsMenuButton(
            onShowAll: {
                selectedCategory = .all
                library.searchText = ""
            },
            onShowFavorites: { selectedCategory = .favorites },
            onSetTimer: { player.setSleepTimer(minutes: $0) },
            onCancelTimer: { player.cancelSleepTimer() }
        )
        .frame(width: 44, height: 44)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<8:
            greeting = SleepL10n.text("早上好")
        case 8..<12:
            greeting = SleepL10n.text("上午好")
        case 12..<14:
            greeting = SleepL10n.text("中午好")
        case 14..<18:
            greeting = SleepL10n.text("下午好")
        case 18..<21:
            greeting = SleepL10n.text("傍晚好")
        case 21..<24:
            greeting = SleepL10n.text("晚上好")
        default:
            greeting = SleepL10n.text("夜深了")
        }
        return SleepL10n.format("{0}，时光睡眠", [String(describing: greeting)])
    }
}

/// 保持菜单从右上角按钮锚点弹出，同时避开 SwiftUI `Menu` 关闭后偶发的
/// SF Symbol 裁切快照残留。UIKit 按钮的图标层不会随菜单预览一起重建。
private struct SoundOptionsMenuButton: UIViewRepresentable {
    let onShowAll: () -> Void
    let onShowFavorites: () -> Void
    let onSetTimer: (Int) -> Void
    let onCancelTimer: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onShowAll: onShowAll,
            onShowFavorites: onShowFavorites,
            onSetTimer: onSetTimer,
            onCancelTimer: onCancelTimer
        )
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        button.setImage(UIImage(systemName: "slider.horizontal.3", withConfiguration: symbolConfiguration), for: .normal)
        button.tintColor = .label
        button.adjustsImageWhenHighlighted = false
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = SleepL10n.text("声音筛选与定时")
        button.menu = context.coordinator.makeMenu()
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.update(
            onShowAll: onShowAll,
            onShowFavorites: onShowFavorites,
            onSetTimer: onSetTimer,
            onCancelTimer: onCancelTimer
        )
        button.menu = context.coordinator.makeMenu()
    }

    final class Coordinator {
        private var onShowAll: () -> Void
        private var onShowFavorites: () -> Void
        private var onSetTimer: (Int) -> Void
        private var onCancelTimer: () -> Void

        init(
            onShowAll: @escaping () -> Void,
            onShowFavorites: @escaping () -> Void,
            onSetTimer: @escaping (Int) -> Void,
            onCancelTimer: @escaping () -> Void
        ) {
            self.onShowAll = onShowAll
            self.onShowFavorites = onShowFavorites
            self.onSetTimer = onSetTimer
            self.onCancelTimer = onCancelTimer
        }

        func update(
            onShowAll: @escaping () -> Void,
            onShowFavorites: @escaping () -> Void,
            onSetTimer: @escaping (Int) -> Void,
            onCancelTimer: @escaping () -> Void
        ) {
            self.onShowAll = onShowAll
            self.onShowFavorites = onShowFavorites
            self.onSetTimer = onSetTimer
            self.onCancelTimer = onCancelTimer
        }

        func makeMenu() -> UIMenu {
            let filters = UIMenu(options: .displayInline, children: [
                UIAction(title: SleepL10n.text("全部")) { [weak self] _ in self?.onShowAll() },
                UIAction(title: SleepL10n.text("收藏")) { [weak self] _ in self?.onShowFavorites() }
            ])
            let timers = UIMenu(options: .displayInline, children: [
                UIAction(title: SleepL10n.text("15 分钟后停止")) { [weak self] _ in self?.onSetTimer(15) },
                UIAction(title: SleepL10n.text("30 分钟后停止")) { [weak self] _ in self?.onSetTimer(30) },
                UIAction(title: SleepL10n.text("60 分钟后停止")) { [weak self] _ in self?.onSetTimer(60) },
                UIAction(title: SleepL10n.text("取消定时"), attributes: .destructive) { [weak self] _ in self?.onCancelTimer() }
            ])
            return UIMenu(children: [filters, timers])
        }
    }
}

private struct SoundHomeSection: Identifiable {
    let index: Int
    let scenes: [SoundScene]
    let showsAdAfter: Bool

    var id: Int { index }
}

private struct SoundHomeMindfulnessItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let track: MindfulnessTrack
}

private enum SoundCategory: String, CaseIterable, Identifiable {
    case recommended
    case favorites
    case all
    case meditation
    case sleep
    case nature
    case whisper
    case whiteNoise
    case dream
    case mindfulness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return "推荐"
        case .favorites: return "收藏"
        case .all: return "全部"
        case .meditation: return "冥想"
        case .sleep: return "助眠"
        case .nature: return "自然"
        case .whisper: return "耳畔"
        case .whiteNoise: return "白噪音"
        case .dream: return "梦境"
        case .mindfulness: return "正念"
        }
    }

    var emptyMessage: String {
        switch self {
        case .favorites:
            return SleepL10n.text("收藏喜欢的声音后会显示在这里。")
        default:
            return SleepL10n.text("换个关键词或查看全部声音。")
        }
    }

    @MainActor
    func scenes(from scenes: [SoundScene], library: SoundLibrary) -> [SoundScene] {
        switch self {
        case .recommended:
            return scenes.filter { $0.index <= 20 }
        case .favorites:
            return scenes.filter { library.isFavorite($0) }
        case .all:
            return scenes
        case .meditation:
            return limitedMatches(in: scenes, keywords: [SleepL10n.text("冥想"), SleepL10n.text("声音浴"), SleepL10n.text("钵"), SleepL10n.text("寺"), SleepL10n.text("钟"), SleepL10n.text("光蕴"), SleepL10n.text("七弦"), SleepL10n.text("八音盒"), SleepL10n.text("呼吸"), SleepL10n.text("静")])
        case .sleep:
            return Array(scenes.filter { $0.category == "sleep" }.prefix(30))
        case .nature:
            return limitedMatches(in: scenes, keywords: [SleepL10n.text("雨"), SleepL10n.text("风"), SleepL10n.text("海"), SleepL10n.text("山"), SleepL10n.text("林"), SleepL10n.text("森林"), SleepL10n.text("竹林"), SleepL10n.text("溪"), SleepL10n.text("泉"), SleepL10n.text("河"), SleepL10n.text("湖"), SleepL10n.text("岛"), SleepL10n.text("星"), SleepL10n.text("月"), SleepL10n.text("雪"), SleepL10n.text("虫"), SleepL10n.text("鸟")])
        case .whisper:
            return limitedMatches(in: scenes, keywords: [SleepL10n.text("耳"), SleepL10n.text("低语"), SleepL10n.text("风铃"), SleepL10n.text("键盘"), SleepL10n.text("铅笔"), SleepL10n.text("磨砚"), SleepL10n.text("手谈"), SleepL10n.text("切菜"), SleepL10n.text("打字机"), SleepL10n.text("心跳"), SleepL10n.text("静电")])
        case .whiteNoise:
            return scenes.filter { SoundLibrary.isIncludedInNatureSleep($0) }
        case .dream:
            return limitedMatches(in: scenes, keywords: [SleepL10n.text("梦"), SleepL10n.text("夜"), SleepL10n.text("月"), SleepL10n.text("星"), SleepL10n.text("幻"), SleepL10n.text("蓝色"), SleepL10n.text("浮空"), SleepL10n.text("云"), SleepL10n.text("微光"), SleepL10n.text("深睡"), SleepL10n.text("睡吧")])
        case .mindfulness:
            return limitedMatches(in: scenes, keywords: [SleepL10n.text("正念"), SleepL10n.text("冥想"), SleepL10n.text("钵"), SleepL10n.text("声音浴"), SleepL10n.text("寺庙"), SleepL10n.text("山泉"), SleepL10n.text("竹林"), SleepL10n.text("远山"), SleepL10n.text("须臾"), SleepL10n.text("柔软"), SleepL10n.text("静")])
        }
    }

    private func limitedMatches(in scenes: [SoundScene], keywords: [String]) -> [SoundScene] {
        Array(scenes.filter { scene in
            let text = "\(scene.title) \(scene.subtitle) \(scene.category)"
            return keywords.contains { text.localizedCaseInsensitiveContains($0) }
        }.prefix(30))
    }
}

private enum SoundFeature: String, CaseIterable, Identifiable {
    case whiteNoise, relax, favorites, stories, nature, focus, mindfulness, meditation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whiteNoise: return "白噪音"
        case .relax: return "身心探索"
        case .favorites: return "我的收藏"
        case .stories: return "睡前故事"
        case .nature: return "自然之声"
        case .focus: return "情绪性格"
        case .mindfulness: return "自在正念"
        case .meditation: return "冥想专题"
        }
    }

    var icon: String {
        switch self {
        case .whiteNoise: return "waveform"
        case .relax: return "bed.double.fill"
        case .favorites: return "heart.fill"
        case .stories: return "book.closed.fill"
        case .nature: return "leaf.fill"
        case .focus: return "headphones"
        case .mindfulness: return "figure.mind.and.body"
        case .meditation: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .whiteNoise: return .blue
        case .relax: return .blue
        case .favorites: return .pink
        case .stories: return .orange
        case .nature: return .green
        case .focus: return .cyan
        case .mindfulness: return .teal
        case .meditation: return .blue
        }
    }

    var category: SoundCategory? {
        switch self {
        case .whiteNoise: return .whiteNoise
        case .relax: return nil
        case .favorites: return .favorites
        case .stories: return nil
        case .nature: return .nature
        case .focus: return nil
        case .mindfulness: return .mindfulness
        case .meditation: return .meditation
        }
    }
}
