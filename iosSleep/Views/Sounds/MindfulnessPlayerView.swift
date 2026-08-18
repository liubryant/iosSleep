import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

struct MindfulnessTrack: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let resourceName: String
    let resourceExtension: String
    let subdirectory: String
    let colors: [Color]
    let accent: Color
    let icon: String
    var fileURL: URL?

    static let deepSleep = MindfulnessTrack(
        id: "deep-sleep-healing", title: "深度睡眠疗愈", subtitle: "正念引导 · 安稳入眠",
        resourceName: "深度睡眠", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.17, green: 0.31, blue: 0.34), Color(red: 0.23, green: 0.39, blue: 0.40), Color(red: 0.12, green: 0.23, blue: 0.27)],
        accent: .mint, icon: "moon.stars.fill"
    )

    static let daytimeEnergy = MindfulnessTrack(
        id: "daytime-energy", title: "日间提神", subtitle: "正念引导 · 清醒专注",
        resourceName: "日间提神", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.50, green: 0.34, blue: 0.18), Color(red: 0.72, green: 0.52, blue: 0.27), Color(red: 0.34, green: 0.25, blue: 0.18)],
        accent: .orange, icon: "sun.max.fill"
    )

    static let walking = MindfulnessTrack(
        id: "walking-meditation", title: "散步冥想", subtitle: "正念引导 · 感受脚下",
        resourceName: "散步冥想", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.18, green: 0.38, blue: 0.27), Color(red: 0.34, green: 0.55, blue: 0.39), Color(red: 0.12, green: 0.27, blue: 0.22)],
        accent: .green, icon: "figure.walk"
    )

    static let emotionalRelease = MindfulnessTrack(
        id: "emotional-release", title: "睡前释放情绪", subtitle: "正念引导 · 温柔放下",
        resourceName: "睡前释放情绪", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.34, green: 0.24, blue: 0.43), Color(red: 0.51, green: 0.38, blue: 0.58), Color(red: 0.22, green: 0.17, blue: 0.34)],
        accent: .purple, icon: "cloud.moon.fill"
    )

    static let calmingSleep = MindfulnessTrack(
        id: "calming-sleep", title: "安定身心助眠", subtitle: "正念引导 · 舒缓身心",
        resourceName: "rachel安定身心助眠", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.15, green: 0.34, blue: 0.39), Color(red: 0.28, green: 0.52, blue: 0.55), Color(red: 0.11, green: 0.24, blue: 0.31)],
        accent: .cyan, icon: "heart.circle.fill"
    )

    static let fatigueRelief = MindfulnessTrack(
        id: "fatigue-relief", title: "缓解疲倦", subtitle: "正念引导 · 恢复能量",
        resourceName: "caroline缓解疲倦给身心一次温柔的休息", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.25, green: 0.38, blue: 0.26), Color(red: 0.45, green: 0.59, blue: 0.35), Color(red: 0.17, green: 0.29, blue: 0.22)],
        accent: .mint, icon: "leaf.fill"
    )

    static let quickSleep = MindfulnessTrack(
        id: "quick-sleep", title: "快速入睡", subtitle: "正念引导 · 沉入梦乡",
        resourceName: "suyue快速入睡｜让意识慢慢沉入夜晚", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.19, green: 0.24, blue: 0.47), Color(red: 0.32, green: 0.39, blue: 0.64), Color(red: 0.13, green: 0.17, blue: 0.34)],
        accent: .blue, icon: "zzz"
    )

    static let examSleep = MindfulnessTrack(
        id: "exam-sleep", title: "考前失眠解放", subtitle: "正念引导 · 缓解紧张",
        resourceName: "nan考前失眠解放｜放下焦虑，安心入眠", resourceExtension: "mp3", subdirectory: "SoundResources/Mindfulness",
        colors: [Color(red: 0.42, green: 0.24, blue: 0.36), Color(red: 0.62, green: 0.39, blue: 0.51), Color(red: 0.29, green: 0.17, blue: 0.31)],
        accent: .pink, icon: "book.closed.fill"
    )
}

struct MindfulnessPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ambientPlayer: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @EnvironmentObject private var player: MindfulnessAudioPlayer
    @State private var isFavorite: Bool
    @State private var isSeeking = false
    @State private var seekValue = 0.0
    @State private var breathingExpanded = false
    let track: MindfulnessTrack

    init(track: MindfulnessTrack = .deepSleep) {
        self.track = track
        _isFavorite = State(initialValue: UserDefaults.standard.bool(forKey: "mindfulness.favorite.\(track.id)"))
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 20)
                breathingArtwork
                Spacer(minLength: 26)
                playerPanel
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            ambientPlayer.stop()
            storyPlayer.stop()
            player.prepareAndPlay(track: track)
        }
        .preference(key: MindfulnessDetailVisibilityPreferenceKey.self, value: true)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    track.colors[0], track.colors[1], track.colors[2]
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(track.accent.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: 140, y: -270)
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 330, height: 330)
                .blur(radius: 90)
                .offset(x: -170, y: 320)
            Rectangle().fill(.ultraThinMaterial.opacity(0.22))
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.13))
                    .clipShape(Circle())
            }
            Spacer()
            Text(track.title).font(.headline.weight(.semibold))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    private var breathingArtwork: some View {
        ZStack {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 250, height: 250)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 210, height: 210)
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.24), track.accent.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: .black.opacity(0.14), radius: 30, y: 18)
            }
            .scaleEffect(breathingExpanded ? 1.10 : 0.90)

            VStack(spacing: 12) {
                Image(systemName: track.icon)
                    .font(.system(size: 54, weight: .light))
                VStack(spacing: 5) {
                    Text(player.isPlaying ? "跟随声音" : "片刻暂停")
                    Text(player.isPlaying ? "回到当下" : "保持觉察")
                }
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.74))
            }
            .foregroundStyle(.white)
        }
        .onAppear { updateBreathingAnimation(isPlaying: player.isPlaying) }
        .onChange(of: player.isPlaying) { isPlaying in
            updateBreathingAnimation(isPlaying: isPlaying)
        }
        .accessibilityHidden(true)
    }

    private func updateBreathingAnimation(isPlaying: Bool) {
        if isPlaying {
            breathingExpanded = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                    breathingExpanded = true
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { breathingExpanded = false }
        }
    }

    private var playerPanel: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(track.title).font(.title3.weight(.semibold))
                    Text(player.duration > 0 ? "\(track.subtitle) · \(timeText(player.duration))" : track.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(Color(red: 0.13, green: 0.28, blue: 0.30))
                        .frame(width: 58, height: 58)
                        .background(.white.opacity(0.94))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            }

            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { isSeeking ? seekValue : player.currentTime },
                        set: { value in isSeeking = true; seekValue = value }
                    ),
                    in: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            player.seek(to: seekValue)
                            isSeeking = false
                        }
                    }
                )
                .tint(.white)
                HStack {
                    Text(timeText(isSeeking ? seekValue : player.currentTime))
                    Spacer()
                    Text("-" + timeText(max(player.duration - (isSeeking ? seekValue : player.currentTime), 0)))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                actionButton(
                    title: isFavorite ? "已收藏" : "收藏",
                    icon: isFavorite ? "heart.fill" : "heart",
                    isActive: isFavorite
                ) {
                    isFavorite.toggle()
                    UserDefaults.standard.set(isFavorite, forKey: "mindfulness.favorite.\(track.id)")
                }
                Menu {
                    ForEach([5, 10, 15, 30], id: \.self) { minutes in
                        Button("\(minutes) 分钟后停止") { player.setSleepTimer(minutes: minutes) }
                    }
                    if player.sleepTimerText != nil {
                        Divider()
                        Button("取消定时", role: .destructive) { player.cancelSleepTimer() }
                    }
                } label: {
                    actionLabel(
                        title: player.sleepTimerText ?? "定时",
                        icon: player.sleepTimerText == nil ? "timer" : "timer.circle.fill",
                        isActive: player.sleepTimerText != nil
                    )
                }
                actionButton(title: "后退15秒", icon: "gobackward.15") { player.skip(seconds: -15) }
                actionButton(title: "前进15秒", icon: "goforward.15") { player.skip(seconds: 15) }
            }

            if let error = player.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(.ultraThinMaterial.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 28, y: 18)
    }

    private func actionButton(
        title: String,
        icon: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { actionLabel(title: title, icon: icon, isActive: isActive) }
            .buttonStyle(.plain)
    }

    private func actionLabel(title: String, icon: String, isActive: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isActive ? Color(red: 0.74, green: 1, blue: 0.91) : .white.opacity(0.84))
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(.white.opacity(isActive ? 0.14 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

@MainActor
final class MindfulnessAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentTrack: MindfulnessTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var sleepTimerText: String?
    @Published private(set) var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var sleepDeadline: Date?
    private var track: MindfulnessTrack?

    override init() {
        super.init()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        configureRemoteCommandCenter()
    }

    func prepareAndPlay(track: MindfulnessTrack) {
        if currentTrack?.id == track.id, audioPlayer != nil { play(); return }
        stop()
        self.track = track
        currentTrack = track
        guard let url = track.fileURL ?? Bundle.main.url(
            forResource: track.resourceName, withExtension: track.resourceExtension,
            subdirectory: track.subdirectory
        ) else {
            errorMessage = "未找到\(track.title)音频资源"
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.numberOfLoops = -1
            newPlayer.prepareToPlay()
            audioPlayer = newPlayer
            duration = newPlayer.duration
            startProgressTimer()
            play()
            AppReviewPrompt.recordPlayback(id: "mindfulness:\(track.id)")
        } catch {
            errorMessage = "音频加载失败，请重新进入页面"
        }
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard let audioPlayer else {
            if let track { prepareAndPlay(track: track) }
            return
        }
        if audioPlayer.currentTime >= audioPlayer.duration - 0.1 { audioPlayer.currentTime = 0 }
        audioPlayer.play()
        isPlaying = true
        errorMessage = nil
        updateNowPlayingInfo()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func stop() {
        let stoppedTrackID = currentTrack?.id
        audioPlayer?.stop()
        audioPlayer = nil
        currentTrack = nil
        track = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        progressTimer?.invalidate()
        progressTimer = nil
        cancelSleepTimer()
        clearNowPlayingInfoIfOwned(trackID: stoppedTrackID)
    }

    func seek(to value: TimeInterval) {
        guard let audioPlayer else { return }
        audioPlayer.currentTime = min(max(value, 0), audioPlayer.duration)
        currentTime = audioPlayer.currentTime
        updateNowPlayingInfo()
    }

    func skip(seconds: TimeInterval) { seek(to: currentTime + seconds) }

    func setSleepTimer(minutes: Int) {
        sleepDeadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
        updateSleepTimerText()
    }

    func cancelSleepTimer() { sleepDeadline = nil; sleepTimerText = nil }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = self.audioPlayer?.currentTime ?? 0
                self.duration = self.audioPlayer?.duration ?? 0
                self.updateSleepTimerText()
            }
        }
    }

    private func updateSleepTimerText() {
        guard let sleepDeadline else { return }
        let remaining = sleepDeadline.timeIntervalSinceNow
        if remaining <= 0 {
            pause()
            cancelSleepTimer()
            return
        }
        let seconds = Int(remaining.rounded(.up))
        sleepTimerText = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = duration
            updateNowPlayingInfo()
        }
    }

    private func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, self.currentTrack != nil else { return .commandFailed }
            self.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.currentTrack != nil else { return .commandFailed }
            self.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.currentTrack != nil else { return .commandFailed }
            self.toggle()
            return .success
        }
        commandCenter.stopCommand.addTarget { [weak self] _ in
            guard let self, self.currentTrack != nil else { return .commandFailed }
            self.stop()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  self.currentTrack != nil,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: AppConstants.appName,
            MPMediaItemPropertyAlbumTitle: track.subtitle,
            MPNowPlayingInfoPropertyExternalContentIdentifier: "mindfulness:\(track.id)",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer?.currentTime ?? currentTime
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let image = nowPlayingArtwork(for: track) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func nowPlayingArtwork(for track: MindfulnessTrack) -> UIImage? {
        let coverName: String?
        switch track.id {
        case MindfulnessTrack.deepSleep.id: coverName = "1"
        case MindfulnessTrack.daytimeEnergy.id: coverName = "2"
        case MindfulnessTrack.walking.id: coverName = "3"
        case MindfulnessTrack.emotionalRelease.id: coverName = "4"
        case MindfulnessTrack.calmingSleep.id: coverName = "5"
        case MindfulnessTrack.fatigueRelief.id: coverName = "6"
        case MindfulnessTrack.quickSleep.id: coverName = "7"
        case MindfulnessTrack.examSleep.id: coverName = "8"
        default: coverName = nil
        }
        if let coverName,
           let url = Bundle.main.url(
               forResource: coverName,
               withExtension: "png",
               subdirectory: "SoundResources/Mindfulness/Covers"
           ),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: "LauncherIcon")
    }

    private func clearNowPlayingInfoIfOwned(trackID: String?) {
        guard let trackID,
              let identifier = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyExternalContentIdentifier] as? String,
              identifier == "mindfulness:\(trackID)" else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    deinit { progressTimer?.invalidate() }
}

struct MindfulnessDetailVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
