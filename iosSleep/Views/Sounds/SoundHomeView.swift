import SwiftUI

struct SoundHomeView: View {
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @State private var showFavoritesOnly = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var displayedScenes: [SoundScene] {
        showFavoritesOnly ? library.filteredScenes.filter { library.isFavorite($0) } : library.filteredScenes
    }

    private var sceneSections: [SoundHomeSection] {
        var sections: [SoundHomeSection] = []
        var sectionIndex = 0
        var startIndex = 0

        while startIndex < displayedScenes.count {
            let endIndex = min(startIndex + 4, displayedScenes.count)
            let scenes = Array(displayedScenes[startIndex..<endIndex])
            sectionIndex += 1
            sections.append(SoundHomeSection(index: sectionIndex, scenes: scenes, showsAdAfter: scenes.count == 4))
            startIndex = endIndex
        }

        return sections
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                soundTopBar
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
                    .padding(.bottom, player.currentScene == nil ? 0 : 88)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if library.scenes.isEmpty {
                    EmptyStateView(title: "暂无声音资源", systemImage: "waveform", message: "请确认 SoundResources 已导入。")
                } else if displayedScenes.isEmpty {
                    EmptyStateView(title: "没有匹配的声音", systemImage: "magnifyingglass", message: "换个关键词或查看全部声音。")
                }
            }
        }
    }

    private var soundTopBar: some View {
        HStack {
            soundHeader

            Spacer()

            filterMenu
        }
        .padding(.horizontal)
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
        .padding(.bottom, 4)
    }

    private var soundHeader: some View {
        HStack(spacing: 12) {
            Image("LauncherIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.title3.weight(.semibold))
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("全部") {
                showFavoritesOnly = false
                library.searchText = ""
            }
            Button("收藏") {
                showFavoritesOnly = true
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
