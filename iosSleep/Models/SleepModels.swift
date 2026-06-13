import Foundation

enum SleepEventType: String, CaseIterable, Codable, Identifiable {
    case snore
    case cough
    case sleepTalk
    case bruxism
    case noise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snore: return "打鼾"
        case .cough: return "咳嗽"
        case .sleepTalk: return "说梦话"
        case .bruxism: return "磨牙"
        case .noise: return "环境噪音"
        }
    }

    var symbolName: String {
        switch self {
        case .snore: return "wind"
        case .cough: return "lungs.fill"
        case .sleepTalk: return "bubble.left.and.bubble.right.fill"
        case .bruxism: return "mouth.fill"
        case .noise: return "speaker.wave.3.fill"
        }
    }
}

struct SleepEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let type: SleepEventType
    let startTime: Date
    let endTime: Date
    let confidence: Double
    let peakDecibel: Double

    init(id: UUID = UUID(), type: SleepEventType, startTime: Date, endTime: Date, confidence: Double, peakDecibel: Double) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.peakDecibel = peakDecibel
    }
}

struct NoiseSample: Identifiable, Codable, Hashable {
    let id: UUID
    let time: Date
    let decibel: Double

    init(id: UUID = UUID(), time: Date, decibel: Double) {
        self.id = id
        self.time = time
        self.decibel = decibel
    }
}

struct SleepSession: Identifiable, Codable, Hashable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var events: [SleepEvent]
    var noiseSamples: [NoiseSample]

    init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil, events: [SleepEvent] = [], noiseSamples: [NoiseSample] = []) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
        self.noiseSamples = noiseSamples
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var averageNoise: Double {
        guard !noiseSamples.isEmpty else { return 0 }
        return noiseSamples.map(\.decibel).reduce(0, +) / Double(noiseSamples.count)
    }

    var maxNoise: Double {
        noiseSamples.map(\.decibel).max() ?? 0
    }
}
