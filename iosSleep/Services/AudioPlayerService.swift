import AVFoundation
import Foundation
import MediaPlayer
import StoreKit
import UIKit

@MainActor
enum AppReviewPrompt {
    private static var isRequestScheduled = false

    static func recordPlayback(id: String) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let playedIDsKey = "review.playedAudioIDs.\(version)"
        var ids = Set(UserDefaults.standard.stringArray(forKey: playedIDsKey) ?? [])
        if ids.insert(id).inserted {
            UserDefaults.standard.set(Array(ids), forKey: playedIDsKey)
        }
        guard ids.count >= 3 else { return }

        let attemptCountKey = "review.attemptCount.\(version)"
        let lastRequestDateKey = "review.lastRequestDate.\(version)"
        let attemptCount = UserDefaults.standard.integer(forKey: attemptCountKey)
        guard attemptCount < 3, !isRequestScheduled else { return }
        let lastRequestTime = UserDefaults.standard.double(forKey: lastRequestDateKey)
        if lastRequestTime > 0 {
            guard Date().timeIntervalSince1970 - lastRequestTime >= 24 * 60 * 60 else { return }
        }
        isRequestScheduled = true

        // 稍微延后，避免评分卡片与刚进入的播放反馈抢占同一帧。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRequestScheduled = false
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            UserDefaults.standard.set(attemptCount + 1, forKey: attemptCountKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastRequestDateKey)
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
}

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentScene: SoundScene?
    @Published private(set) var isPlaying = false
    @Published private(set) var sleepTimerText: String?
    @Published private(set) var downloadProgress: [String: Double] = [:]
    @Published private(set) var downloadErrors: [String: String] = [:]
    @Published var volume: Double = 0.8 {
        didSet {
            player?.volume = Float(volume)
        }
    }

    private var player: AVAudioPlayer?
    private var sleepTimerTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?
    private var cachedArtworkSceneID: String?
    private var cachedArtwork: MPMediaItemArtwork?

    override init() {
        super.init()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        configureRemoteCommandCenter()
    }

    func toggle(scene: SoundScene) {
        if currentScene?.id == scene.id, isPlaying {
            pause()
        } else {
            guard !scene.requiresVIP || SleepMembershipSession.shared.isVIPActive else { return }
            playTask?.cancel()
            playTask = Task { [weak self] in
                await self?.play(scene: scene)
            }
        }
    }

    func play(scene: SoundScene) async {
        guard !scene.requiresVIP || SleepMembershipSession.shared.isVIPActive else { return }
        do {
            // 锁屏媒体卡片需要应用接管当前音频会话；混音模式下系统可能不会
            // 将该声音识别为 Now Playing 内容。
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            let url = try await playableURL(for: scene)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.numberOfLoops = -1
            player?.volume = Float(volume)
            player?.prepareToPlay()
            player?.play()
            currentScene = scene
            isPlaying = true
            updateNowPlayingInfo()
            AppReviewPrompt.recordPlayback(id: "sound:\(scene.id)")
        } catch {
            print("Failed to play \(scene.title): \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        player?.stop()
        player = nil
        currentScene = nil
        isPlaying = false
        cancelSleepTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func setSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        sleepTimerText = "\(minutes) 分钟后停止"
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.player?.stop()
                self?.player = nil
                self?.currentScene = nil
                self?.isPlaying = false
                self?.sleepTimerText = nil
                self?.sleepTimerTask = nil
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerText = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            updateNowPlayingInfo()
        }
    }

    /// 配置锁屏与控制中心的远程播放控制，使播放助眠声音时可在锁屏页/后台显示并控制播放状态。
    private func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .commandFailed }
            player.play()
            self.isPlaying = true
            self.updateNowPlayingInfo()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let scene = self.currentScene else { return .commandFailed }
            self.toggle(scene: scene)
            return .success
        }

        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
    }

    /// 更新锁屏与控制中心展示的当前播放信息（标题、专辑、播放状态与封面）。
    private func updateNowPlayingInfo() {
        guard let scene = currentScene else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: scene.title,
            MPMediaItemPropertyArtist: AppConstants.appName,
            MPMediaItemPropertyAlbumTitle: scene.subtitle,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0
        ]

        if let duration = player?.duration, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if cachedArtworkSceneID != scene.id {
            cachedArtworkSceneID = scene.id
            cachedArtwork = coverImage(for: scene).map { image in
                MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
        if let cachedArtwork {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func coverImage(for scene: SoundScene) -> UIImage? {
        let coverName = (scene.coverFile as NSString).deletingPathExtension
        let coverExtension = (scene.coverFile as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: coverName, withExtension: coverExtension, subdirectory: scene.coverSubdirectory),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func isDownloading(_ scene: SoundScene) -> Bool {
        downloadProgress[scene.id] != nil
    }

    func cachedAudioExists(for scene: SoundScene) -> Bool {
        FileManager.default.fileExists(atPath: cachedAudioURL(for: scene).path)
    }

    func isBundledOrCached(_ scene: SoundScene) -> Bool {
        bundledAudioURL(for: scene) != nil || cachedAudioExists(for: scene)
    }

    /// 返回已经可离线播放的本地文件，供声音详情页复用，避免重复下载。
    func localAudioURL(for scene: SoundScene) -> URL? {
        if let bundledURL = bundledAudioURL(for: scene) { return bundledURL }
        let cachedURL = cachedAudioURL(for: scene)
        return FileManager.default.fileExists(atPath: cachedURL.path) ? cachedURL : nil
    }

    private func playableURL(for scene: SoundScene) async throws -> URL {
        if let bundleURL = bundledAudioURL(for: scene) {
            return bundleURL
        }

        let cachedURL = cachedAudioURL(for: scene)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        return try await download(scene: scene, to: cachedURL)
    }

    private func bundledAudioURL(for scene: SoundScene) -> URL? {
        let audioName = (scene.audioFile as NSString).deletingPathExtension
        let audioExtension = (scene.audioFile as NSString).pathExtension
        return Bundle.main.url(forResource: audioName, withExtension: audioExtension, subdirectory: scene.audioSubdirectory)
    }

    private func cachedAudioURL(for scene: SoundScene) -> URL {
        let extensionName = (scene.audioFile as NSString).pathExtension
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent("\(scene.id).\(extensionName)")
    }

    private func download(scene: SoundScene, to destinationURL: URL) async throws -> URL {
        let directoryURL = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let downloadURL = AppConstants.soundServerBaseURL
            .appendingPathComponent(scene.id)
            .appendingPathComponent("download")

        downloadErrors[scene.id] = nil
        downloadProgress[scene.id] = 0
        defer {
            downloadProgress[scene.id] = nil
        }

        let (bytes, response) = try await URLSession.shared.bytes(from: downloadURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let expectedLength = max(response.expectedContentLength, 0)
        let temporaryURL = destinationURL.appendingPathExtension("download")
        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)

        var receivedLength: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(32 * 1024)

        do {
            let fileHandle = try FileHandle(forWritingTo: temporaryURL)
            defer {
                try? fileHandle.close()
            }

            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= 32 * 1024 {
                    fileHandle.write(buffer)
                    receivedLength += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    updateProgress(sceneID: scene.id, receivedLength: receivedLength, expectedLength: expectedLength)
                }
            }

            if !buffer.isEmpty {
                fileHandle.write(buffer)
                receivedLength += Int64(buffer.count)
                updateProgress(sceneID: scene.id, receivedLength: receivedLength, expectedLength: expectedLength)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            downloadErrors[scene.id] = "下载失败"
            throw error
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func updateProgress(sceneID: String, receivedLength: Int64, expectedLength: Int64) {
        guard expectedLength > 0 else {
            downloadProgress[sceneID] = 0.1
            return
        }
        downloadProgress[sceneID] = min(Double(receivedLength) / Double(expectedLength), 1)
    }
}
