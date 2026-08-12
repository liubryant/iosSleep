import SwiftUI

struct SoundHomeView: View {
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @State private var selectedCategory: SoundCategory = .all

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
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
            VStack(spacing: 0) {
                soundTopBar
                soundFeatureCategories
                soundSearchBar

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(sceneSections) { section in
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.scenes) { scene in
                                    SoundCardView(scene: scene)
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
        .padding(.horizontal, 0)
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
        .padding(.top, 14)
        .padding(.bottom, 4)
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
                    .font(.title3.weight(.semibold))
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("全部") {
                selectedCategory = .all
                library.searchText = ""
            }
            Button("收藏") {
                selectedCategory = .favorites
            }
            Divider()
            Button("15 分钟后停止") { player.setSleepTimer(minutes: 15) }
            Button("30 分钟后停止") { player.setSleepTimer(minutes: 30) }
            Button("60 分钟后停止") { player.setSleepTimer(minutes: 60) }
            Button("取消定时") { player.cancelSleepTimer() }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.title3)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
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

private struct SoundHomeSection: Identifiable {
    let index: Int
    let scenes: [SoundScene]
    let showsAdAfter: Bool

    var id: Int { index }
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
        case .relax: return "舒眠放松"
        case .favorites: return "我的收藏"
        case .stories: return "睡前故事"
        case .nature: return "自然之声"
        case .focus: return "沉浸学习"
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
        case .relax: return .sleep
        case .favorites: return .favorites
        case .stories: return nil
        case .nature: return .nature
        case .focus: return .whisper
        case .mindfulness: return .mindfulness
        case .meditation: return .meditation
        }
    }
}
