import SwiftUI

struct StoryPlayerView: View {
    @EnvironmentObject private var player: StoryPlayerService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var storyLibrary: StoryLibrary
    let story: StoryItem
    let onPlayStory: (StoryItem) -> Void

    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var storyText = ""
    @State private var sleepTimerTask: Task<Void, Never>?
    @State private var sleepTimerMinutes: Int?
    @AppStorage("storyPlaybackOrder") private var playbackOrder = StoryPlaybackOrder.sequential.rawValue

    private var isCurrent: Bool { player.currentStory?.id == story.id }
    private var isPlayingThis: Bool { isCurrent && player.isPlaying }
    private var shouldUseLocalAudio: Bool { player.isBundledOrCached(story) }
    private var shouldResetCover: Bool {
        isCurrent && !player.isPlaying && player.currentTime == 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                StoryCoverImage(story: story)
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(1.12)
                    .blur(radius: 28)
                    .opacity(0.9)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.07, blue: 0.15).opacity(0.42),
                        Color(red: 0.08, green: 0.09, blue: 0.19).opacity(0.66),
                        Color(red: 0.04, green: 0.06, blue: 0.13).opacity(0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                let coverSize = responsiveCoverSize(for: proxy.size)

                VStack(spacing: proxy.size.height < 600 ? 8 : 14) {
                    RotatingStoryCover(
                        story: story,
                        isPlaying: isPlayingThis,
                        shouldReset: shouldResetCover
                    )
                    .frame(width: coverSize, height: coverSize)
                    .frame(maxWidth: .infinity)
                    .padding(.top, proxy.size.height < 600 ? 2 : 8)

                    StoryPlaybackTextView(
                        text: storyText.isEmpty ? "暂无故事正文" : storyText,
                        currentTime: isCurrent ? player.currentTime : 0,
                        duration: isCurrent ? player.duration : 0
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                    .background(Color.black.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
                    .padding(.horizontal, proxy.size.width < 350 ? 12 : 20)
                    .frame(maxWidth: 820)

                    playerControls
                        .padding(.horizontal, proxy.size.width < 350 ? 16 : 24)
                        .frame(maxWidth: 760)
                        .padding(.bottom, proxy.size.height < 600 ? 4 : 12)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .appEdgeSwipeBack()
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sleepTimerMenu
            }
        }
        .preference(key: StoryDetailVisibilityPreferenceKey.self, value: true)
        .task(id: story.id) {
            loadStoryText()
            if audioPlayer.currentScene != nil {
                audioPlayer.stop()
            }
            if player.currentStory?.id == story.id {
                if !player.isPlaying {
                    player.resume()
                }
            } else if shouldUseLocalAudio {
                await player.play(story: story)
            } else {
                player.playText(story: story, text: storyText)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: StoryPlayerService.didFinishStory)) { notification in
            guard notification.object as? String == story.id else { return }
            playNextStory()
        }
    }

    private var sleepTimerMenu: some View {
        Menu {
            ForEach([15, 30, 60], id: \.self) { minutes in
                Button("\(minutes) 分钟") {
                    startSleepTimer(minutes: minutes)
                }
            }
            if sleepTimerMinutes != nil {
                Divider()
                Button("关闭定时", role: .destructive) {
                    cancelSleepTimer()
                }
            }
        } label: {
            Image(systemName: sleepTimerMinutes == nil ? "timer" : "timer.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 42, height: 36)
                .background(.white.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    private var playerControls: some View {
        VStack(spacing: 14) {
            if let progress = player.downloadProgress[story.id] {
                ProgressView(value: progress)
                    .tint(.blue)
                Text("正在下载… \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                StorySeekBar(
                    value: isSeeking ? seekValue : (isCurrent ? player.currentTime : 0),
                    duration: isCurrent ? player.duration : 0,
                    onSeeking: { value in
                        isSeeking = true
                        seekValue = value
                    },
                    onSeek: { value in
                        seekValue = value
                        player.seek(to: value)
                        isSeeking = false
                    }
                )

                HStack {
                    Text(timeText(isCurrent ? (isSeeking ? seekValue : player.currentTime) : 0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    Text(timeText(isCurrent ? player.duration : 0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack {
                    Button {
                        player.seek(to: max(player.currentTime - 15, 0))
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 25, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        if shouldUseLocalAudio {
                            player.toggle(story: story)
                        } else {
                            player.toggleText(story: story, text: storyText)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)

                            Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                .font(.system(size: 27, weight: .bold))
                                .foregroundStyle(.black.opacity(0.88))
                                .offset(x: isPlayingThis ? 0 : 2)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        player.seek(to: min(player.currentTime + 15, player.duration))
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 25, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white)
            }

            if shouldUseLocalAudio, let error = player.downloadErrors[story.id] {
                Text(error + "，该故事尚未开放下载，请稍后再试")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !shouldUseLocalAudio {
                Text("正在使用系统语音朗读本地故事文本")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            playbackOrderControls
        }
        .padding(18)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var playbackOrderControls: some View {
        HStack(spacing: 10) {
            playbackOrderButton(title: "顺序播放", systemImage: "repeat", order: .sequential)
            playbackOrderButton(title: "随机播放", systemImage: "shuffle", order: .random)
        }
    }

    private func playbackOrderButton(
        title: String,
        systemImage: String,
        order: StoryPlaybackOrder
    ) -> some View {
        let selected = playbackOrder == order.rawValue
        return Button {
            playbackOrder = order.rawValue
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(selected ? Color.black.opacity(0.86) : Color.white.opacity(0.82))
                .background(selected ? Color.white : Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func playNextStory() {
        let stories = storyLibrary.stories
        guard stories.count > 1 else { return }

        let nextStory: StoryItem?
        if playbackOrder == StoryPlaybackOrder.random.rawValue {
            nextStory = stories.filter { $0.id != story.id }.randomElement()
        } else {
            let orderedStories = stories.sorted { $0.index < $1.index }
            guard let currentIndex = orderedStories.firstIndex(where: { $0.id == story.id }) else { return }
            nextStory = orderedStories[(currentIndex + 1) % orderedStories.count]
        }

        if let nextStory {
            onPlayStory(nextStory)
        }
    }

    private func startSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        sleepTimerMinutes = minutes
        sleepTimerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                player.stop()
                sleepTimerMinutes = nil
                sleepTimerTask = nil
            }
        }
    }

    private func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerMinutes = nil
    }

    private func timeText(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "00:00" }
        let total = Int(time)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func responsiveCoverSize(for size: CGSize) -> CGFloat {
        let widthLimit = size.width * 0.52
        let heightLimit = size.height * 0.25
        return min(190, max(108, min(widthLimit, heightLimit)))
    }

    private func loadStoryText() {
        guard let url = story.bundledResourceURL(fileName: story.storyTextFile),
              let rawText = try? String(contentsOf: url, encoding: .utf8) else {
            storyText = ""
            return
        }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(story.title) {
            storyText = String(trimmed.dropFirst(story.title.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            storyText = trimmed
        }
    }
}

private enum StoryPlaybackOrder: String {
    case sequential
    case random
}

private struct StoryPlaybackTextView: View {
    let text: String
    let currentTime: TimeInterval
    let duration: TimeInterval

    private var chunks: [String] {
        splitStoryText(text)
    }

    private var activeIndex: Int {
        guard duration > 0, chunks.isEmpty == false else { return 0 }
        let progress = min(max(currentTime / duration, 0), 0.999)
        return min(Int(progress * Double(chunks.count)), chunks.count - 1)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(chunks.indices, id: \.self) { index in
                        Text(chunks[index])
                            .font(.body)
                            .lineSpacing(7)
                            .foregroundStyle(.white.opacity(0.94))
                            .padding(.horizontal, 8)
                            .padding(.vertical, isHighlighted(index) ? 5 : 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(
                                        isHighlighted(index)
                                            ? Color(red: 0.68, green: 0.80, blue: 1.0)
                                                .opacity(index == activeIndex ? 0.22 : 0.10)
                                            : Color.clear
                                    )
                            )
                            .id(index)
                    }
                }
                .padding(16)
            }
            .onChange(of: activeIndex) { index in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func isHighlighted(_ index: Int) -> Bool {
        index == activeIndex || index == activeIndex + 1
    }

    private func splitStoryText(_ source: String) -> [String] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return ["暂无故事正文"] }

        let separators = Set("，,。！？!?；;\n")
        var result: [String] = []
        var current = ""

        for character in normalized {
            current.append(character)
            if separators.contains(character) {
                appendChunk(current, to: &result)
                current = ""
            }
        }
        appendChunk(current, to: &result)
        return result.isEmpty ? [normalized] : result
    }

    private func appendChunk(_ chunk: String, to result: inout [String]) {
        let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        result.append(trimmed)
    }
}

private struct RotatingStoryCover: View {
    let story: StoryItem
    let isPlaying: Bool
    let shouldReset: Bool

    /// 封面独立匀速旋转，不绑定音频时间，跳播时不会突转或反转。
    private let secondsPerRotation: TimeInterval = 30
    @State private var accumulatedDegrees: Double = 0
    @State private var rotationStartedAt: Date?

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(min(proxy.size.width, proxy.size.height) - 20, 1)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.06))
                        .frame(width: diameter, height: diameter)

                    StoryCoverImage(story: story)
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(rotation(at: context.date)))

                    Circle()
                        .stroke(.white, lineWidth: 5)
                        .frame(width: diameter, height: diameter)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if isPlaying {
                rotationStartedAt = Date()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                rotationStartedAt = Date()
            } else {
                commitRotation(at: Date())
                if shouldReset {
                    accumulatedDegrees = 0
                }
            }
        }
        .onChange(of: shouldReset) { reset in
            guard reset else { return }
            accumulatedDegrees = 0
            rotationStartedAt = nil
        }
    }

    private func rotation(at date: Date) -> Double {
        guard isPlaying, let rotationStartedAt else { return accumulatedDegrees }
        let elapsed = max(date.timeIntervalSince(rotationStartedAt), 0)
        return accumulatedDegrees + elapsed / secondsPerRotation * 360
    }

    private func commitRotation(at date: Date) {
        guard let rotationStartedAt else { return }
        let elapsed = max(date.timeIntervalSince(rotationStartedAt), 0)
        accumulatedDegrees = (accumulatedDegrees + elapsed / secondsPerRotation * 360)
            .truncatingRemainder(dividingBy: 360)
        self.rotationStartedAt = nil
    }
}

private struct StorySeekBar: View {
    let value: TimeInterval
    let duration: TimeInterval
    let onSeeking: (TimeInterval) -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progress = duration > 0 ? min(max(value / duration, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(height: 4)

                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: width * progress, height: 4)

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .offset(x: min(max(width * progress - 11, 0), width - 22))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onSeeking(time(at: gesture.location.x, width: width))
                    }
                    .onEnded { gesture in
                        onSeek(time(at: gesture.location.x, width: width))
                    }
            )
        }
        .frame(height: 30)
        .accessibilityLabel("播放进度")
        .accessibilityValue("\(Int(value))秒")
    }

    private func time(at x: CGFloat, width: CGFloat) -> TimeInterval {
        guard duration > 0 else { return 0 }
        return min(max(Double(x / width), 0), 1) * duration
    }
}
