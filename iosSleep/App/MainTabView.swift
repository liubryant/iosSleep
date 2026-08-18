import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var soundLibrary: SoundLibrary
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @EnvironmentObject private var mindfulnessPlayer: MindfulnessAudioPlayer
    @EnvironmentObject private var storyLibrary: StoryLibrary
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var storyNotificationService = StoryNotificationService.shared
    @State private var selectedTab = 0
    @State private var isStoryDetailVisible = false
    @State private var isMindfulnessDetailVisible = false
    @State private var isMindfulnessFlowVisible = false
    @State private var requestedStoryID: String?
    @State private var quickMindfulnessTrack: MindfulnessTrack?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SoundHomeView()
                    .tag(0)
                    .tabItem {
                        Label("声音", systemImage: "waveform")
                    }

                SleepHomeView()
                    .tag(1)
                    .tabItem {
                        Label("睡眠", systemImage: "moon.zzz.fill")
                    }

                StoryHomeView(requestedStoryID: $requestedStoryID)
                    .tag(2)
                    .tabItem {
                        Label("故事", image: "StoryTabIcon")
                    }

                ProfileView()
                    .tag(3)
                    .tabItem {
                        Label("我的", systemImage: "person.crop.circle")
                    }
            }
            .tint(.blue)

            if let story = storyPlayer.currentStory, !isStoryDetailVisible {
                GlobalStoryMiniPlayerView(story: story)
                    .padding(.horizontal)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            } else if let track = mindfulnessPlayer.currentTrack,
                      selectedTab == 0,
                      !isMindfulnessFlowVisible,
                      !isMindfulnessDetailVisible {
                GlobalMindfulnessMiniPlayerView(track: track)
                    .padding(.horizontal)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            } else if let scene = player.currentScene {
                GlobalMiniPlayerView(scene: scene)
                    .padding(.horizontal)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: player.currentScene?.id)
        .animation(.easeInOut(duration: 0.2), value: storyPlayer.currentStory?.id)
        .animation(.easeInOut(duration: 0.2), value: mindfulnessPlayer.currentTrack?.id)
        .onChange(of: player.currentScene?.id) { id in
            guard id != nil else { return }
            if storyPlayer.currentStory != nil { storyPlayer.stop() }
            if mindfulnessPlayer.currentTrack != nil { mindfulnessPlayer.stop() }
        }
        .onChange(of: storyPlayer.currentStory?.id) { id in
            guard id != nil else { return }
            if player.currentScene != nil { player.stop() }
            if mindfulnessPlayer.currentTrack != nil { mindfulnessPlayer.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: StoryNotificationService.didOpenStory)) { notification in
            if let storyID = notification.object as? String {
                requestedStoryID = storyID
            }
            selectedTab = 2
        }
        .onChange(of: storyNotificationService.pendingStoryID) { storyID in
            if let storyID {
                requestedStoryID = storyID
                selectedTab = 2
            }
        }
        .onPreferenceChange(StoryDetailVisibilityPreferenceKey.self) { visible in
            isStoryDetailVisible = visible
        }
        .onPreferenceChange(MindfulnessDetailVisibilityPreferenceKey.self) { visible in
            isMindfulnessDetailVisible = visible
        }
        .onPreferenceChange(MindfulnessFlowVisibilityPreferenceKey.self) { visible in
            isMindfulnessFlowVisible = visible
        }
        .fullScreenCover(item: $quickMindfulnessTrack) { track in
            NavigationStack {
                MindfulnessPlayerView(track: track)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: QuickActionService.didRequestAction)) { notification in
            guard let action = notification.object as? AppQuickAction else { return }
            _ = QuickActionService.shared.consumePendingAction()
            openQuickAction(action)
        }
        .onAppear {
            if storyNotificationService.pendingStoryID != nil {
                requestedStoryID = storyNotificationService.pendingStoryID
                selectedTab = 2
            }
            if let action = QuickActionService.shared.consumePendingAction() {
                openQuickAction(action)
            }
        }
        .task {
            _ = StoryNotificationService.shared
            if storyLibrary.stories.isEmpty {
                await storyLibrary.load()
            }
            await StoryNotificationService.shared.requestAuthorizationIfNeeded()
            if settings.storyReminderEnabled {
                settings.storyReminderEnabled = await StoryNotificationService.shared.enable(
                    stories: storyLibrary.stories
                )
            }
        }
    }

    private func openQuickAction(_ action: AppQuickAction) {
        switch action {
        case .mindfulness:
            selectedTab = 0
            quickMindfulnessTrack = [
                MindfulnessTrack.deepSleep, .daytimeEnergy, .walking, .emotionalRelease,
                .calmingSleep, .fatigueRelief, .quickSleep, .examSleep
            ].randomElement()
        case .nature:
            selectedTab = 0
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: QuickActionService.didRequestNature, object: nil)
            }
            playRandomDownloadedNatureSound()
        case .stories:
            openRandomStory()
        }
    }

    private func playRandomDownloadedNatureSound() {
        Task { @MainActor in
            if soundLibrary.scenes.isEmpty {
                await soundLibrary.load()
            }

            let natureKeywords = ["雨", "风", "海", "山", "林", "森林", "竹林", "溪", "泉", "河", "湖", "岛", "星", "月", "雪", "虫", "鸟"]
            let natureScenes = soundLibrary.scenes.filter { scene in
                let searchableText = "\(scene.title) \(scene.subtitle) \(scene.category)"
                return natureKeywords.contains {
                    searchableText.localizedCaseInsensitiveContains($0)
                }
            }
            let localNatureScenes = natureScenes.filter { player.isBundledOrCached($0) }
            let localScenes = soundLibrary.scenes.filter { player.isBundledOrCached($0) }
            let candidates: [SoundScene]
            if !localNatureScenes.isEmpty {
                candidates = localNatureScenes
            } else if !natureScenes.isEmpty {
                candidates = natureScenes
            } else if !localScenes.isEmpty {
                candidates = localScenes
            } else {
                candidates = soundLibrary.scenes
            }

            guard let scene = randomItem(excluding: player.currentScene?.id, from: candidates) else { return }
            await player.play(scene: scene)
        }
    }

    private func openRandomStory() {
        Task { @MainActor in
            if storyLibrary.stories.isEmpty {
                await storyLibrary.load()
            }
            // 远程散文开关开启时，StoryLibrary 已把默认故事与散文合并。
            // 快捷菜单直接从完整列表随机，不能优先限制为有本地音频的默认故事，
            // 否则 553 篇散文永远没有机会被选中。
            guard let story = randomItem(
                excluding: storyPlayer.currentStory?.id,
                from: storyLibrary.stories
            ) else { return }
            // 与通知点击共用同一条持久路由：先保存明确的故事 ID，
            // StoryHomeView 加载完成后再消费，不依赖瞬时事件的到达时机。
            StoryNotificationService.shared.requestOpenStory(story.id)
            selectedTab = 2
            // TabView 切换完成后再下发详情目标，确保 StoryHomeView 已挂载并能接收导航。
            await Task.yield()
            requestedStoryID = story.id
        }
    }

    private func randomItem<T: Identifiable>(excluding currentID: T.ID?, from items: [T]) -> T? where T.ID: Equatable {
        let alternatives = items.filter { $0.id != currentID }
        return (alternatives.isEmpty ? items : alternatives).randomElement()
    }
}

private struct GlobalMindfulnessMiniPlayerView: View {
    @EnvironmentObject private var player: MindfulnessAudioPlayer
    let track: MindfulnessTrack

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: track.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                Text(track.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let timer = player.sleepTimerText {
                    Text(timer).font(.caption2).foregroundStyle(.blue)
                }
            }
            Spacer()
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent)
            Button { player.stop() } label: {
                Image(systemName: "xmark").frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

/// 由当前 SwiftUI 视图层级直接上报故事详情页是否可见，避免页面重建时
/// onAppear/onDisappear 通知乱序导致全局迷你播放器覆盖在详情页上。
struct StoryDetailVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct GlobalMiniPlayerView: View {
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
                        .foregroundStyle(.blue)
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

private struct GlobalStoryMiniPlayerView: View {
    @EnvironmentObject private var player: StoryPlayerService
    let story: StoryItem

    var body: some View {
        HStack(spacing: 12) {
            StoryCoverImage(story: story)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("睡前故事")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.resume()
                }
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
