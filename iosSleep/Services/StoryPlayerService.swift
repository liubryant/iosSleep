import AVFoundation
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class StoryPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    @Published private(set) var currentStory: StoryItem?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var downloadProgress: [String: Double] = [:]
    @Published private(set) var downloadErrors: [String: String] = [:]

    private var player: AVAudioPlayer?
    private var playTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isSpeechMode = false
    private var speechText = ""
    private var speechStartCharacter = 0
    private var speechCurrentCharacter = 0

    private var speechCharacterCount: Int {
        speechText.count
    }

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        UIApplication.shared.beginReceivingRemoteControlEvents()
        configureRemoteCommandCenter()
    }

    func isBundledOrCached(_ story: StoryItem) -> Bool {
        story.isBundled || cachedAudioExists(for: story)
    }

    func cachedAudioExists(for story: StoryItem) -> Bool {
        guard !story.audioFile.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: cachedAudioURL(for: story).path)
    }

    func isDownloading(_ story: StoryItem) -> Bool {
        downloadProgress[story.id] != nil
    }

    func toggle(story: StoryItem) {
        if currentStory?.id == story.id, isPlaying {
            pause()
        } else if currentStory?.id == story.id, isSpeechMode {
            resume()
        } else if currentStory?.id == story.id, player != nil {
            resume()
        } else {
            playTask?.cancel()
            playTask = Task { [weak self] in
                await self?.play(story: story)
            }
        }
    }

    func toggleText(story: StoryItem, text: String) {
        if currentStory?.id == story.id, isPlaying {
            pause()
        } else if currentStory?.id == story.id, isSpeechMode {
            resume()
        } else {
            playText(story: story, text: text)
        }
    }

    func playText(story: StoryItem, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure speech session: \(error)")
        }

        playTask?.cancel()
        playTask = nil
        player?.stop()
        player = nil
        stopProgressTimer()
        speechSynthesizer.stopSpeaking(at: .immediate)

        currentStory = story
        isSpeechMode = true
        speechText = trimmedText
        speechStartCharacter = 0
        speechCurrentCharacter = 0
        duration = estimatedSpeechDuration(for: trimmedText)
        currentTime = 0
        speakText(fromCharacter: 0)
    }

    func play(story: StoryItem) async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            let url = try await playableURL(for: story)

            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeechMode = false
            speechText = ""
            speechStartCharacter = 0
            speechCurrentCharacter = 0

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
        if isSpeechMode {
            speechSynthesizer.pauseSpeaking(at: .word)
        } else {
            player?.pause()
        }
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    func resume() {
        if isSpeechMode {
            if speechSynthesizer.isPaused {
                speechSynthesizer.continueSpeaking()
            } else {
                speakText(fromCharacter: speechCurrentCharacter)
            }
        } else {
            guard player != nil else { return }
            player?.play()
        }
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        let boundedTime = max(0, min(time, duration))
        if isSpeechMode {
            currentTime = boundedTime
            let character = characterOffset(for: boundedTime)
            speechCurrentCharacter = character
            speakText(fromCharacter: character)
        } else {
            player?.currentTime = boundedTime
            currentTime = player?.currentTime ?? 0
        }
        updateNowPlayingInfo()
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        stopProgressTimer()
        speechSynthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        currentStory = nil
        isPlaying = false
        isSpeechMode = false
        speechText = ""
        speechStartCharacter = 0
        speechCurrentCharacter = 0
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
                guard let self else { return }
                if self.isSpeechMode {
                    self.currentTime = self.time(forCharacter: self.speechCurrentCharacter)
                } else if let player = self.player {
                    self.currentTime = player.currentTime
                }
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
            guard let self, self.player != nil || self.isSpeechMode else { return .commandFailed }
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil || self.isSpeechMode else { return .commandFailed }
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
        guard !story.coverFile.isEmpty else { return nil }
        guard let url = story.bundledResourceURL(fileName: story.coverFile),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func speakText(fromCharacter character: Int) {
        let startCharacter = min(max(character, 0), speechCharacterCount)
        guard startCharacter < speechCharacterCount else {
            isPlaying = false
            currentTime = duration
            stopProgressTimer()
            updateNowPlayingInfo()
            return
        }

        speechSynthesizer.stopSpeaking(at: .immediate)
        speechStartCharacter = startCharacter
        speechCurrentCharacter = startCharacter

        let startIndex = speechText.index(speechText.startIndex, offsetBy: startCharacter)
        let utterance = AVSpeechUtterance(string: String(speechText[startIndex...]))
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 0.98
        utterance.volume = 1

        speechSynthesizer.speak(utterance)
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
    }

    private func estimatedSpeechDuration(for text: String) -> TimeInterval {
        max(TimeInterval(text.count) / 4.2, 1)
    }

    private func characterOffset(for time: TimeInterval) -> Int {
        guard duration > 0, speechCharacterCount > 0 else { return 0 }
        let progress = min(max(time / duration, 0), 1)
        return min(Int(Double(speechCharacterCount) * progress), speechCharacterCount)
    }

    private func time(forCharacter character: Int) -> TimeInterval {
        guard speechCharacterCount > 0 else { return 0 }
        let progress = min(max(Double(character) / Double(speechCharacterCount), 0), 1)
        return duration * progress
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speechCurrentCharacter = min(speechStartCharacter + characterRange.location, speechCharacterCount)
            currentTime = time(forCharacter: speechCurrentCharacter)
            updateNowPlayingInfo()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speechCurrentCharacter = speechCharacterCount
            currentTime = duration
            isPlaying = false
            stopProgressTimer()
            updateNowPlayingInfo()
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if isSpeechMode && !isPlaying {
                stopProgressTimer()
                updateNowPlayingInfo()
            }
        }
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
        guard story.isBundled, !story.audioFile.isEmpty else { return nil }
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
