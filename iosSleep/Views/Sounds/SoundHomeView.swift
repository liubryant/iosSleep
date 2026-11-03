import SwiftUI
import UIKit

struct SoundHomeView: View {
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var membership = SleepMembershipSession.shared
    @State private var selectedCategory: SoundCategory = .whiteNoise
    @State private var vipPromptTitle = ""
    @State private var vipPromptKind: SleepVIPContentKind = .mindfulness
    @State private var showVIPPrompt = false
    @State private var showMembershipAfterPrompt = false
    @State private var showMembership = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    private let mindfulnessItems: [SoundHomeMindfulnessItem] = [
        .init(title: "深度睡眠疗愈", subtitle: "卸下疲惫，沉入安稳梦境", imageName: "1", track: .deepSleep),
        .init(title: "日间提神", subtitle: "唤醒精神，找回清晰专注", imageName: "2", track: .daytimeEnergy),
        .init(title: "散步冥想", subtitle: "跟随脚步，感受此时此地", imageName: "3", track: .walking),
        .init(title: "睡前释放情绪", subtitle: "温柔放下今天的情绪", imageName: "4", track: .emotionalRelease),
        .init(title: "安定身心助眠", subtitle: "舒缓呼吸，让身体松下来", imageName: "5", track: .calmingSleep),
        .init(title: "缓解疲倦", subtitle: "短暂休息，恢复身心能量", imageName: "6", track: .fatigueRelief),
        .init(title: "快速入睡", subtitle: "平静思绪，更快进入睡眠", imageName: "7", track: .quickSleep),
        .init(title: "考前失眠解放", subtitle: "减少紧张，安心迎接明天", imageName: "8", track: .examSleep)
    ]

    private var displayedScenes: [SoundScene] {
        selectedCategory.scenes(from: library.filteredScenes, library: library)
    }

    private var sceneSections: [SoundHomeSection] {
        var sections: [SoundHomeSection] = []
        var sectionIndex = 0
        var startIndex = 0

        while startIndex < displayedScenes.count {
            let endIndex = min(startIndex + 6, displayedScenes.count)
            let scenes = Array(displayedScenes[startIndex..<endIndex])
            sectionIndex += 1
            sections.append(SoundHomeSection(index: sectionIndex, scenes: scenes, showsAdAfter: scenes.count == 6))
            startIndex = endIndex
        }

        return sections
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    soundSearchBar
                    soundFeatureCategories

                    LazyVStack(spacing: 16) {
                        if selectedCategory == .whiteNoise {
                            mindfulnessSection
                            WellnessHomeSection()
                                .padding(.top, 8)
                        }

                        soundSectionHeader

                        ForEach(sceneSections) { section in
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.scenes) { scene in
                                    soundCard(for: scene)
                                }
                            }

                            if section.showsAdAfter {
                                DrawFeedAdCardView()
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, player.currentScene == nil && storyPlayer.currentStory == nil ? 0 : 88)
                }
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                soundTopBar
                    .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if library.scenes.isEmpty {
                    EmptyStateView(title: "暂无声音资源", systemImage: "waveform", message: "请确认 SoundResources 已导入。")
                } else if displayedScenes.isEmpty {
                    EmptyStateView(title: "没有匹配的声音", systemImage: "magnifyingglass", message: selectedCategory.emptyMessage)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: QuickActionService.didRequestNature)) { _ in
                selectedCategory = .nature
                library.searchText = ""
            }
        }
        .sheet(isPresented: $showVIPPrompt, onDismiss: {
            guard showMembershipAfterPrompt else { return }
            showMembershipAfterPrompt = false
            showMembership = true
        }) {
            SleepVIPUpgradeSheet(
                contentTitle: vipPromptTitle,
                contentKind: vipPromptKind,
                onUpgrade: {
                    showMembershipAfterPrompt = true
                    showVIPPrompt = false
                },
                onCancel: { showVIPPrompt = false }
            )
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showMembership) {
            NavigationStack { SleepMembershipView() }
                .environmentObject(settings)
        }
    }

    private var mindfulnessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("正念冥想").font(.system(size: 15, weight: .medium))
                    Text("跟随声音，把注意力带回当下")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    MindfulnessHomeView()
                } label: {
                    HStack(spacing: 4) {
                        Text("更多")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: [GridItem(.fixed(235))],
                    spacing: 16
                ) {
                    ForEach(mindfulnessItems.prefix(6)) { item in
                        NavigationLink {
                            MindfulnessPlayerView(track: item.track)
                        } label: {
                            mindfulnessCard(item)
                        }
                        .buttonStyle(.plain)
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
                vipPromptTitle = scene.title
                vipPromptKind = .sound
                showVIPPrompt = true
            }
        } else {
            SoundCardView(scene: scene, isVIPContent: scene.requiresVIP)
        }
    }

    private var soundSectionHeader: some View {
        sectionHeader(title: "大自然入眠", subtitle: "枕着山海风雨，慢慢沉入梦乡")
            .padding(.top, selectedCategory == .whiteNoise ? 8 : 0)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 15, weight: .medium))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mindfulnessCard(_ item: SoundHomeMindfulnessItem) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                if let image = mindfulnessImage(named: item.imageName) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: 150, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
    }

    private func mindfulnessImage(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "SoundResources/Mindfulness/Covers"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
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
                    NavigationLink {
                        WellnessHubView()
                    } label: {
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
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(feature.color)
                    .frame(width: 48, height: 48)
                    .background(feature.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }

            Text(feature.title)
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
        HStack {
            soundHeader

            Spacer()

            filterMenu
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private var soundSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索雨声、森林、海浪", text: $library.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !library.searchText.isEmpty {
                Button {
                    library.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var soundCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SoundCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
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

    private var soundHeader: some View {
        HStack(spacing: 12) {
            Image("LauncherIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.title2.weight(.regular))
            }
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
            greeting = "早上好"
        case 8..<12:
            greeting = "上午好"
        case 12..<14:
            greeting = "中午好"
        case 14..<18:
            greeting = "下午好"
        case 18..<21:
            greeting = "傍晚好"
        case 21..<24:
            greeting = "晚上好"
        default:
            greeting = "夜深了"
        }
        return "\(greeting)，时光睡眠！"
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
        button.accessibilityLabel = "声音筛选与定时"
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
                UIAction(title: "全部") { [weak self] _ in self?.onShowAll() },
                UIAction(title: "收藏") { [weak self] _ in self?.onShowFavorites() }
            ])
            let timers = UIMenu(options: .displayInline, children: [
                UIAction(title: "15 分钟后停止") { [weak self] _ in self?.onSetTimer(15) },
                UIAction(title: "30 分钟后停止") { [weak self] _ in self?.onSetTimer(30) },
                UIAction(title: "60 分钟后停止") { [weak self] _ in self?.onSetTimer(60) },
                UIAction(title: "取消定时", attributes: .destructive) { [weak self] _ in self?.onCancelTimer() }
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
    let imageName: String
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
            return "收藏喜欢的声音后会显示在这里。"
        default:
            return "换个关键词或查看全部声音。"
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
            return limitedMatches(in: scenes, keywords: ["冥想", "声音浴", "钵", "寺", "钟", "光蕴", "七弦", "八音盒", "呼吸", "静"])
        case .sleep:
            return Array(scenes.filter { $0.category == "sleep" }.prefix(30))
        case .nature:
            return limitedMatches(in: scenes, keywords: ["雨", "风", "海", "山", "林", "森林", "竹林", "溪", "泉", "河", "湖", "岛", "星", "月", "雪", "虫", "鸟"])
        case .whisper:
            return limitedMatches(in: scenes, keywords: ["耳", "低语", "风铃", "键盘", "铅笔", "磨砚", "手谈", "切菜", "打字机", "心跳", "静电"])
        case .whiteNoise:
            return scenes
        case .dream:
            return limitedMatches(in: scenes, keywords: ["梦", "夜", "月", "星", "幻", "蓝色", "浮空", "云", "微光", "深睡", "睡吧"])
        case .mindfulness:
            return limitedMatches(in: scenes, keywords: ["正念", "冥想", "钵", "声音浴", "寺庙", "山泉", "竹林", "远山", "须臾", "柔软", "静"])
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
