import AVFoundation
import Foundation

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentScene: SoundScene?
    @Published private(set) var isPlaying = false
    @Published private(set) var sleepTimerText: String?
    @Published var volume: Double = 0.8 {
        didSet {
            player?.volume = Float(volume)
        }
    }

    private var player: AVAudioPlayer?
    private var sleepTimerTask: Task<Void, Never>?

    func toggle(scene: SoundScene) {
        if currentScene?.id == scene.id, isPlaying {
            pause()
        } else {
            play(scene: scene)
        }
    }

    func play(scene: SoundScene) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let audioName = (scene.audioFile as NSString).deletingPathExtension
            let audioExtension = (scene.audioFile as NSString).pathExtension
            guard let url = Bundle.main.url(forResource: audioName, withExtension: audioExtension, subdirectory: scene.audioSubdirectory) else {
                print("Missing sound resource for \(scene.title)")
                return
            }

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
}
