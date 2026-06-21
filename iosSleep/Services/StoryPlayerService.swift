import AVFoundation
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class StoryPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentStory: StoryItem?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var downloadProgress: [String: Double] = [:]
    @Published private(set) var downloadErrors: [String: String] = [:]

    private var player: AVAudioPlayer?
    private var playTask: Task<Void, Never>?
    private var progressTimer: Timer?

    override init() {
        super.init()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        configureRemoteCommandCenter()
    }

    func isBundledOrCached(_ story: StoryItem) -> Bool {
        story.isBundled || cachedAudioExists(for: story)
    }

    func cachedAudioExists(for story: StoryItem) -> Bool {
        FileManager.default.fileExists(atPath: cachedAudioURL(for: story).path)
    }

    func isDownloading(_ story: StoryItem) -> Bool {
        downloadProgress[story.id] != nil
    }

    func toggle(story: StoryItem) {
        if currentStory?.id == story.id, isPlaying {
            pause()
        } else if currentStory?.id == story.id, player != nil {
            resume()
        } else {
            playTask?.cancel()
            playTask = Task { [weak self] in
                await self?.play(story: story)
            }
        }
    }

    func play(story: StoryItem) async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            let url = try await playableURL(for: story)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.numberOfLoops = 0
            player?.prepareToPlay()
            player?.play()
            currentStory = story
            isPlaying = true
            duration = player?.duration ?? 0
            currentTime = 0
            startProgressTimer()
            updateNowPlayingInfo()
        } catch {
            print("Failed to play \(story.title): \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    func resume() {
        guard player != nil else { return }
        player?.play()
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = max(0, min(time, duration))
        currentTime = player?.currentTime ?? 0
        updateNowPlayingInfo()
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        stopProgressTimer()
        player?.stop()
        player = nil
        currentStory = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            player.currentTime = 0
            isPlaying = false
            currentTime = 0
            stopProgressTimer()
            updateNowPlayingInfo()
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// 配置锁屏与控制中心的远程播放控制。
    private func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let story = self.currentStory else { return .commandFailed }
            self.toggle(story: story)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let story = currentStory else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: story.title,
            MPMediaItemPropertyArtist: AppConstants.appName,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let image = coverImage(for: story) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func coverImage(for story: StoryItem) -> UIImage? {
        guard let url = story.bundledResourceURL(fileName: story.coverFile),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func playableURL(for story: StoryItem) async throws -> URL {
        if let bundleURL = bundledAudioURL(for: story) {
            return bundleURL
        }

        let cachedURL = cachedAudioURL(for: story)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        return try await download(story: story, to: cachedURL)
    }

    private func bundledAudioURL(for story: StoryItem) -> URL? {
        guard story.isBundled else { return nil }
        return story.bundledResourceURL(fileName: story.audioFile)
    }

    private func cachedAudioURL(for story: StoryItem) -> URL {
        let extensionName = (story.audioFile as NSString).pathExtension
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("Stories", isDirectory: true)
            .appendingPathComponent("\(story.id).\(extensionName)")
    }

    /// 预留的服务器下载接口：指向 AppConstants.storyServerBaseURL/{index}/download。
    /// 后端尚未上线对应接口前，调用会失败并落到 downloadErrors，不影响已捆绑的故事正常播放。
    private func download(story: StoryItem, to destinationURL: URL) async throws -> URL {
        let directoryURL = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let downloadURL = AppConstants.storyServerBaseURL
            .appendingPathComponent("\(story.index)")
            .appendingPathComponent("download")

        downloadErrors[story.id] = nil
        downloadProgress[story.id] = 0
        defer {
            downloadProgress[story.id] = nil
        }

        let (bytes, response) = try await URLSession.shared.bytes(from: downloadURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            downloadErrors[story.id] = "下载失败"
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
                    updateProgress(storyID: story.id, receivedLength: receivedLength, expectedLength: expectedLength)
                }
            }

            if !buffer.isEmpty {
                fileHandle.write(buffer)
                receivedLength += Int64(buffer.count)
                updateProgress(storyID: story.id, receivedLength: receivedLength, expectedLength: expectedLength)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            downloadErrors[story.id] = "下载失败"
            throw error
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func updateProgress(storyID: String, receivedLength: Int64, expectedLength: Int64) {
        guard expectedLength > 0 else {
            downloadProgress[storyID] = 0.1
            return
        }
        downloadProgress[storyID] = min(Double(receivedLength) / Double(expectedLength), 1)
    }
}
