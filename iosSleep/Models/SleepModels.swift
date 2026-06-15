import Foundation

enum SleepEventType: String, CaseIterable, Codable, Identifiable {
    case snore
    case cough
    case sleepTalk
    case bruxism
    case noise
    case heavyBreathing
    case nasalCongestion
    case fart
    case breathHolding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snore: return "打鼾"
        case .cough: return "咳嗽"
        case .sleepTalk: return "说梦话"
        case .bruxism: return "磨牙"
        case .noise: return "环境噪音"
        case .heavyBreathing: return "大口呼吸"
        case .nasalCongestion: return "鼻塞"
        case .fart: return "放屁"
        case .breathHolding: return "憋气"
        }
    }

    var symbolName: String {
        switch self {
        case .snore: return "wind"
        case .cough: return "lungs.fill"
        case .sleepTalk: return "bubble.left.and.bubble.right.fill"
        case .bruxism: return "mouth.fill"
        case .noise: return "speaker.wave.3.fill"
        case .heavyBreathing: return "wind"
        case .nasalCongestion: return "nose.fill"
        case .fart: return "aqi.medium"
        case .breathHolding: return "pause.circle.fill"
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
        let severeEventCount = eventCount(for: .snore) + eventCount(for: .bruxism) + eventCount(for: .heavyBreathing)
            + eventCount(for: .breathHolding) * 2
        let severeEventPenalty = min(Double(severeEventCount) * 2.2, 18)
        let score = 100 - durationPenalty - noisePenalty - eventPenalty - severeEventPenalty
        return min(100, max(60, Int(score.rounded())))
    }

    /// 睡眠分布：将本次睡眠按声音特征划分为深睡/浅睡/做梦/觉醒区间。
    var sleepDistribution: SleepDistribution {
        SleepStageAnalyzer.analyze(session: self)
    }

    /// 睡眠效率 = 实际睡眠时长 / 在床时长，百分比。
    var sleepEfficiency: Double {
        let distribution = sleepDistribution
        guard distribution.totalDuration > 0 else { return 0 }
        return min(100, max(0, distribution.sleepDuration / distribution.totalDuration * 100))
    }

    /// 睡眠年龄：综合睡眠评分、深睡比例、睡眠效率和呼吸/磨牙事件估算的参考年龄。
    var sleepAge: Int {
        let distribution = sleepDistribution
        let sleepDuration = distribution.sleepDuration
        let deepRatio = sleepDuration > 0 ? distribution.duration(for: .deep) / sleepDuration : 0

        var age = 28.0
        age += Double(75 - sleepScore) * 0.35
        age += max(0, 0.22 - deepRatio) * 160
        age += max(0, 85 - sleepEfficiency) * 0.3
        let disruptiveEvents = eventCount(for: .snore) + eventCount(for: .bruxism)
            + eventCount(for: .heavyBreathing) + eventCount(for: .breathHolding)
        age += Double(disruptiveEvents) * 0.6

        return Int(min(60, max(16, age.rounded())))
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

enum SleepStage: String, CaseIterable, Identifiable, Hashable {
    case deep
    case light
    case rem
    case awake

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deep: return "深度睡眠"
        case .light: return "浅睡眠"
        case .rem: return "做梦"
        case .awake: return "睡中觉醒"
        }
    }
}

struct SleepStageSegment: Identifiable, Hashable {
    let id = UUID()
    let stage: SleepStage
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval {
        max(0, endTime.timeIntervalSince(startTime))
    }
}

struct SleepDistribution {
    let segments: [SleepStageSegment]
    let fallAsleepTime: Date?
    let wakeTime: Date?

    var totalDuration: TimeInterval {
        segments.map(\.duration).reduce(0, +)
    }

    /// 总睡眠时长（不含睡中觉醒时段）。
    var sleepDuration: TimeInterval {
        totalDuration - duration(for: .awake)
    }

    func duration(for stage: SleepStage) -> TimeInterval {
        segments.filter { $0.stage == stage }.map(\.duration).reduce(0, +)
    }

    func percentage(for stage: SleepStage) -> Double {
        guard totalDuration > 0 else { return 0 }
        return duration(for: stage) / totalDuration * 100
    }
}

/// 基于环境噪音水平与识别事件，将一次睡眠会话划分为深睡/浅睡/做梦/觉醒区间。
/// 这是一种启发式估算，用于在没有专用生理传感器的情况下给出可解释的睡眠分布参考。
enum SleepStageAnalyzer {
    private static let windowSize: TimeInterval = 5 * 60
    private static let disruptiveTypes: Set<SleepEventType> = [
        .snore, .bruxism, .cough, .heavyBreathing, .nasalCongestion, .fart, .noise, .breathHolding
    ]

    static func analyze(session: SleepSession) -> SleepDistribution {
        guard let endTime = session.endTime, endTime > session.startTime else {
            return SleepDistribution(segments: [], fallAsleepTime: nil, wakeTime: nil)
        }

        let baselineNoise = session.averageNoise
        var segments: [SleepStageSegment] = []
        var cursor = session.startTime

        while cursor < endTime {
            let windowEnd = min(cursor.addingTimeInterval(windowSize), endTime)
            let stage = stage(for: session, from: cursor, to: windowEnd, baselineNoise: baselineNoise)

            if let last = segments.last, last.stage == stage {
                segments[segments.count - 1] = SleepStageSegment(stage: stage, startTime: last.startTime, endTime: windowEnd)
            } else {
                segments.append(SleepStageSegment(stage: stage, startTime: cursor, endTime: windowEnd))
            }

            cursor = windowEnd
        }

        var fallAsleepTime = session.startTime
        if let first = segments.first, first.stage == .awake {
            fallAsleepTime = first.endTime
        }

        return SleepDistribution(segments: segments, fallAsleepTime: fallAsleepTime, wakeTime: endTime)
    }

    private static func stage(for session: SleepSession, from start: Date, to end: Date, baselineNoise: Double) -> SleepStage {
        let samples = session.noiseSamples.filter { $0.time >= start && $0.time < end }
        let averageDecibel = samples.isEmpty
            ? baselineNoise
            : samples.map(\.decibel).reduce(0, +) / Double(samples.count)

        let events = session.events.filter { $0.startTime < end && $0.endTime > start }
        let disruptiveCount = events.filter { disruptiveTypes.contains($0.type) }.count
        let sleepTalkCount = events.filter { $0.type == .sleepTalk }.count

        if averageDecibel > baselineNoise + 12 || disruptiveCount >= 3 {
            return .awake
        }
        if sleepTalkCount >= 1 || (averageDecibel > baselineNoise + 4 && disruptiveCount >= 1) {
            return .rem
        }
        if averageDecibel < baselineNoise - 3 && disruptiveCount == 0 {
            return .deep
        }
        return .light
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

extension SleepSession {
    /// 当用户还没有任何睡眠记录时，用于展示的示例「优秀」睡眠报告。
    /// 数据经过设计，呈现 8 小时睡眠、低噪音环境与较少干扰事件下的详细分析效果。
    static var sample: SleepSession {
        let calendar = Calendar.current
        let now = Date()
        // 结束时间取最近一次的早上 7:00（如果当前时间早于 7:00，则取昨天的 7:00），
        // 呈现「23:00 入睡 - 次日 7:00 起床」的正常夜间睡眠时段。
        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.hour = 7
        endComponents.minute = 0
        endComponents.second = 0
        var endTime = calendar.date(from: endComponents) ?? now
        if endTime > now {
            endTime = calendar.date(byAdding: .day, value: -1, to: endTime) ?? endTime
        }
        let startTime = endTime.addingTimeInterval(-8 * 3_600)

        var noiseSamples: [NoiseSample] = []
        let totalMinutes = 480
        for minute in 0..<totalMinutes {
            let t = Double(minute)
            let decibel = 31
                + 5 * sin(2 * Double.pi * t / 90)
                + 1.5 * sin(2 * Double.pi * t / 23)
            noiseSamples.append(NoiseSample(time: startTime.addingTimeInterval(t * 60), decibel: decibel))
        }

        func eventTime(_ minute: Double) -> Date {
            startTime.addingTimeInterval(minute * 60)
        }

        let events: [SleepEvent] = [
            SleepEvent(type: .cough, startTime: eventTime(46), endTime: eventTime(46).addingTimeInterval(2), confidence: 0.86, peakDecibel: 41),
            SleepEvent(type: .snore, startTime: eventTime(132), endTime: eventTime(132).addingTimeInterval(6), confidence: 0.78, peakDecibel: 38),
            SleepEvent(type: .sleepTalk, startTime: eventTime(214), endTime: eventTime(214).addingTimeInterval(4), confidence: 0.81, peakDecibel: 40),
            SleepEvent(type: .sleepTalk, startTime: eventTime(362), endTime: eventTime(362).addingTimeInterval(3), confidence: 0.83, peakDecibel: 39)
        ]

        return SleepSession(startTime: startTime, endTime: endTime, events: events, noiseSamples: noiseSamples, audioFileName: nil)
    }
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
