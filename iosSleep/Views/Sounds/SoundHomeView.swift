import SwiftUI

struct SoundHomeView: View {
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @State private var showFavoritesOnly = false

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    private var displayedScenes: [SoundScene] {
        showFavoritesOnly ? library.filteredScenes.filter { library.isFavorite($0) } : library.filteredScenes
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(displayedScenes) { scene in
                            SoundCardView(scene: scene)
                        }
                    }
                    .padding()
                    .padding(.bottom, player.currentScene == nil ? 0 : 88)
                }

                if let scene = player.currentScene {
                    MiniPlayerView(scene: scene)
                        .padding()
                }
            }
            .navigationTitle("声音")
            .searchable(text: $library.searchText, prompt: "搜索雨声、森林、海浪")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                    }
                }
            }
            .overlay {
                if library.scenes.isEmpty {
                    EmptyStateView(title: "暂无声音资源", systemImage: "waveform", message: "请确认 SoundResources 已导入。")
                } else if displayedScenes.isEmpty {
                    EmptyStateView(title: "没有匹配的声音", systemImage: "magnifyingglass", message: "换个关键词或查看全部声音。")
                }
            }
        }
    }
}

private struct MiniPlayerView: View {
    @EnvironmentObject private var player: AudioPlayerService
    let scene: SoundScene

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(scene: scene)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(scene.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(scene.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let timer = player.sleepTimerText {
                    Text(timer)
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
            }

            Spacer()

            Button {
                player.toggle(scene: scene)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent)

            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}
