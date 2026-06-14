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
    var audioFileName: String?

    init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil, events: [SleepEvent] = [], noiseSamples: [NoiseSample] = [], audioFileName: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
        self.noiseSamples = noiseSamples
        self.audioFileName = audioFileName
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

    var sleepScore: Int {
        let durationHours = duration / 3_600
        let durationPenalty: Double
        if durationHours <= 0 {
            durationPenalty = 35
        } else if durationHours < 6 {
            durationPenalty = (6 - durationHours) * 4
        } else if durationHours > 9 {
            durationPenalty = min((durationHours - 9) * 2, 10)
        } else {
            durationPenalty = 0
        }

        let noisePenalty = min(max(averageNoise - 38, 0) * 0.7, 22)
        let eventPenalty = min(Double(events.count) * 1.8, 28)
        let severeEventPenalty = min(Double(eventCount(for: .snore) + eventCount(for: .bruxism)) * 2.2, 18)
        let score = 100 - durationPenalty - noisePenalty - eventPenalty - severeEventPenalty
        return min(100, max(0, Int(score.rounded())))
    }

    func eventCount(for type: SleepEventType) -> Int {
        events.filter { $0.type == type }.count
    }

    func eventDuration(for type: SleepEventType) -> TimeInterval {
        events
            .filter { $0.type == type }
            .map { max(0, $0.endTime.timeIntervalSince($0.startTime)) }
            .reduce(0, +)
    }
}

enum SleepTrendRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        }
    }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}

struct SleepTrendPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let score: Double
    let durationHours: Double
    let eventCount: Int
    let snoreCount: Int
    let bruxismCount: Int
    let averageNoise: Double
}

enum SleepTrendCalculator {
    static func points(from sessions: [SleepSession], range: SleepTrendRange, calendar: Calendar = .current) -> [SleepTrendPoint] {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: today) ?? today
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }

        return (0..<range.dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let daySessions = sessionsByDay[date] ?? []
            guard !daySessions.isEmpty else {
                return SleepTrendPoint(date: date, score: 0, durationHours: 0, eventCount: 0, snoreCount: 0, bruxismCount: 0, averageNoise: 0)
            }

            let totalDuration = daySessions.map(\.duration).reduce(0, +)
            let totalEvents = daySessions.map { $0.events.count }.reduce(0, +)
            let totalSnore = daySessions.map { $0.eventCount(for: .snore) }.reduce(0, +)
            let totalBruxism = daySessions.map { $0.eventCount(for: .bruxism) }.reduce(0, +)
            let averageScore = Double(daySessions.map(\.sleepScore).reduce(0, +)) / Double(daySessions.count)
            let averageNoise = daySessions.map(\.averageNoise).reduce(0, +) / Double(daySessions.count)

            return SleepTrendPoint(
                date: date,
                score: averageScore,
                durationHours: totalDuration / 3_600,
                eventCount: totalEvents,
                snoreCount: totalSnore,
                bruxismCount: totalBruxism,
                averageNoise: averageNoise
            )
        }
    }
}
