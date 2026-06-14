import AVFoundation
import Foundation

@MainActor
final class SleepMonitorService: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published private(set) var currentSession: SleepSession?
    @Published private(set) var latestSession: SleepSession?
    @Published private(set) var sessions: [SleepSession] = []
    @Published private(set) var currentDecibel: Double = 0
    @Published private(set) var permissionDenied = false

    private let engine = AVAudioEngine()
    private let classifier: SoundClassifying = HybridSleepSoundClassifier()
    private var lastEventTimeByType: [SleepEventType: Date] = [:]
    private var lastPersistTime = Date.distantPast
    private var recorder: AVAudioRecorder?

    init() {
        sessions = SleepSessionStore.loadSessions()
        latestSession = sessions.first
    }

    func start() async {
        let granted = await requestMicrophoneAccess()
        guard granted else {
            permissionDenied = true
            return
        }

        do {
            try configureAudioSession()
            var session = SleepSession()
            let recordingURL = try SleepSessionStore.makeRecordingURL(sessionID: session.id)
            session.audioFileName = recordingURL.lastPathComponent
            currentSession = session
            latestSession = session
            sessions = SleepSessionStore.upsert(session, into: sessions)
            persistSessions(force: true)
            lastEventTimeByType = [:]
            try startRecorder(url: recordingURL)
            installTap()
            engine.prepare()
            try engine.start()
            isMonitoring = true
        } catch {
            print("Failed to start sleep monitor: \(error)")
            stop()
        }
    }

    func stop() {
        guard isMonitoring || currentSession != nil else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        recorder?.stop()
        recorder = nil

        currentSession?.endTime = Date()
        latestSession = currentSession
        if let latestSession {
            sessions = SleepSessionStore.upsert(latestSession, into: sessions)
            persistSessions(force: true)
        }
        currentSession = nil
        isMonitoring = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func select(session: SleepSession) {
        guard !isMonitoring else { return }
        latestSession = session
    }

    func dismissPermissionAlert() {
        permissionDenied = false
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
        try session.setPreferredSampleRate(16_000)
        try session.setPreferredIOBufferDuration(0.96)
        try session.setActive(true)
    }

    private func installTap() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.process(buffer: buffer)
            }
        }
    }

    private func startRecorder(url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard var session = currentSession, let features = AudioFeatureExtractor.features(from: buffer) else { return }
        currentDecibel = features.estimatedDecibel

        let now = Date()
        session.noiseSamples.append(NoiseSample(time: now, decibel: features.estimatedDecibel))
        if session.noiseSamples.count > 720 {
            session.noiseSamples.removeFirst(session.noiseSamples.count - 720)
        }

        if let result = classifier.classify(buffer: buffer, features: features), canAppendEvent(type: result.type, at: now) {
            let event = SleepEvent(
                type: result.type,
                startTime: now.addingTimeInterval(-2),
                endTime: now,
                confidence: result.confidence,
                peakDecibel: features.estimatedDecibel
            )
            session.events.append(event)
            lastEventTimeByType[result.type] = now
        }

        currentSession = session
        latestSession = session
        sessions = SleepSessionStore.upsert(session, into: sessions)
        persistSessions(force: false)
    }

    private func canAppendEvent(type: SleepEventType, at date: Date) -> Bool {
        guard let last = lastEventTimeByType[type] else { return true }
        return date.timeIntervalSince(last) > 20
    }

    private func persistSessions(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastPersistTime) > 30 else { return }
        lastPersistTime = now
        SleepSessionStore.saveSessions(sessions)
    }
}
