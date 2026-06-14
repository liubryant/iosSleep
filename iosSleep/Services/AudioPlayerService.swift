import AVFoundation
import Foundation

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

    func toggle(scene: SoundScene) {
        if currentScene?.id == scene.id, isPlaying {
            pause()
        } else {
            playTask?.cancel()
            playTask = Task { [weak self] in
                await self?.play(scene: scene)
            }
        }
    }

    func play(scene: SoundScene) async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
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
        } catch {
            print("Failed to play \(scene.title): \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        player?.stop()
        player = nil
        currentScene = nil
        isPlaying = false
        cancelSleepTimer()
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
        }
    }

    func isDownloading(_ scene: SoundScene) -> Bool {
        downloadProgress[scene.id] != nil
    }

    func cachedAudioExists(for scene: SoundScene) -> Bool {
        FileManager.default.fileExists(atPath: cachedAudioURL(for: scene).path)
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
