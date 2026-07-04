import SwiftUI

struct StoryPlayerView: View {
    @EnvironmentObject private var player: StoryPlayerService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    let story: StoryItem

    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var storyText = ""

    private var isCurrent: Bool { player.currentStory?.id == story.id }
    private var isPlayingThis: Bool { isCurrent && player.isPlaying }
    private var shouldUseLocalAudio: Bool { player.isBundledOrCached(story) }
    private var shouldResetCover: Bool {
        isCurrent && !player.isPlaying && player.currentTime == 0
    }

    var body: some View {
        GeometryReader { proxy in
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
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, proxy.size.width < 350 ? 12 : 20)

                playerControls
                    .padding(.horizontal, proxy.size.width < 350 ? 16 : 24)
                    .padding(.bottom, proxy.size.height < 600 ? 4 : 12)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private var playerControls: some View {
        VStack(spacing: 14) {
            if let progress = player.downloadProgress[story.id] {
                ProgressView(value: progress)
                    .tint(.indigo)
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
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(timeText(isCurrent ? player.duration : 0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button {
                    if shouldUseLocalAudio {
                        player.toggle(story: story)
                    } else {
                        player.toggleText(story: story, text: storyText)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.indigo.opacity(0.16),
                                        Color.cyan.opacity(0.12),
                                        Color.purple.opacity(0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.indigo)
                            .offset(x: isPlayingThis ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)
            }

            if shouldUseLocalAudio, let error = player.downloadErrors[story.id] {
                Text(error + "，该故事尚未开放下载，请稍后再试")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !shouldUseLocalAudio {
                Text("正在使用系统语音朗读本地故事文本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        guard let url = story.bundledResourceURL(fileName: "story.txt"),
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
                            .foregroundStyle(.primary)
                            .padding(.horizontal, isHighlighted(index) ? 8 : 0)
                            .padding(.vertical, isHighlighted(index) ? 5 : 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(isHighlighted(index) ? Color.indigo.opacity(index == activeIndex ? 0.18 : 0.10) : Color.clear)
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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            ZStack {
                Circle()
                    .fill(.black.opacity(0.06))

                StoryCoverImage(story: story)
                    .padding(10)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 5).padding(10))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .overlay {
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                    }
                    .rotationEffect(.degrees(rotation(at: context.date)))
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
                    .fill(Color(.systemGray5))
                    .frame(height: 4)

                Capsule()
                    .fill(.indigo)
                    .frame(width: width * progress, height: 4)

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .overlay(Circle().stroke(.indigo, lineWidth: 2))
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
