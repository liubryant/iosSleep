import Foundation
import HealthKit

struct HealthSleepInsight: Equatable {
    let nights: Int
    let totalSleep: TimeInterval
    let averageSleep: TimeInterval
    let deepSleep: TimeInterval
    let coreSleep: TimeInterval
    let remSleep: TimeInterval
    let awakeTime: TimeInterval
    let averageHeartRate: Double?
    let averageHRV: Double?
    let averageRespiratoryRate: Double?
    let averageOxygenSaturation: Double?
    let averageWristTemperature: Double?
    let startDate: Date
    let endDate: Date

    var deepPercentage: Double { percentage(for: deepSleep) }
    var corePercentage: Double { percentage(for: coreSleep) }
    var remPercentage: Double { percentage(for: remSleep) }

    private func percentage(for duration: TimeInterval) -> Double {
        guard totalSleep > 0 else { return 0 }
        return min(100, max(0, duration / totalSleep * 100))
    }
}

@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var isAuthorized = false
    @Published private(set) var statusText = "未授权"
    @Published private(set) var recentInsight: HealthSleepInsight?
    @Published private(set) var isLoadingInsight = false
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var insightMessage: String?

    private let store = HKHealthStore()

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            statusText = "当前设备不可用"
            insightMessage = "当前设备不支持 Apple 健康。"
            return false
        }

        guard !isRequestingAuthorization else { return false }
        isRequestingAuthorization = true
        statusText = "正在请求授权"
        defer { isRequestingAuthorization = false }

        do {
            try await store.requestAuthorization(toShare: [sleepType], read: insightReadTypes(sleepType: sleepType))
            isAuthorized = true
            statusText = "已完成授权"
            return true
        } catch {
            isAuthorized = false
            statusText = "授权失败"
            insightMessage = "Apple 健康授权未完成，请在系统“设置 > 健康 > 数据访问与设备”中允许时光睡眠读取数据后重试。"
            return false
        }
    }

    func requestAndLoadRecentInsight(days: Int = 7) async {
        guard !isLoadingInsight, !isRequestingAuthorization else { return }

        isLoadingInsight = true
        insightMessage = nil
        defer { isLoadingInsight = false }

        guard await requestInsightReadAuthorization() else { return }
        await loadRecentInsight(days: days)
    }

    func loadRecentInsight(days: Int = 7) async {
        guard isAvailable, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            insightMessage = "当前设备不支持 Apple 健康。"
            return
        }

        isLoadingInsight = true
        insightMessage = nil
        defer { isLoadingInsight = false }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -max(1, days), to: endDate) ?? endDate.addingTimeInterval(-604_800)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let sleepSamples = await categorySamples(type: sleepType, predicate: predicate)
        guard !sleepSamples.isEmpty else {
            recentInsight = nil
            insightMessage = "最近 \(days) 天没有可读取的睡眠数据。你可以先用 Apple Watch 或时光睡眠完成一次睡眠记录。"
            return
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let asleepSamples = sleepSamples.filter { asleepValues.contains($0.value) }
        guard !asleepSamples.isEmpty else {
            recentInsight = nil
            insightMessage = "找到了在床记录，但没有可用于分析的睡眠阶段数据。"
            return
        }

        let calendar = Calendar.current
        let nights = Set(asleepSamples.map { calendar.startOfDay(for: $0.endDate) }).count
        let unspecified = duration(of: .asleepUnspecified, in: sleepSamples)
        let deep = duration(of: .asleepDeep, in: sleepSamples)
        let core = duration(of: .asleepCore, in: sleepSamples)
        let rem = duration(of: .asleepREM, in: sleepSamples)
        let stagedTotal = deep + core + rem
        let totalSleep = stagedTotal > 0 ? stagedTotal : unspecified
        let awake = duration(of: .awake, in: sleepSamples)
        let intervals = asleepSamples.map { DateInterval(start: $0.startDate, end: $0.endDate) }

        let heartRate = await sleepingAverage(
            identifier: .heartRate,
            unit: HKUnit(from: "count/min"),
            predicate: predicate,
            intervals: intervals
        )
        let hrv = await sleepingAverage(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            predicate: predicate,
            intervals: intervals
        )
        let respiratoryRate = await sleepingAverage(
            identifier: .respiratoryRate,
            unit: HKUnit(from: "count/min"),
            predicate: predicate,
            intervals: intervals
        )
        let oxygenFraction = await sleepingAverage(
            identifier: .oxygenSaturation,
            unit: .percent(),
            predicate: predicate,
            intervals: intervals
        )
        let wristTemperature = await sleepingAverage(
            identifier: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            predicate: predicate,
            intervals: intervals
        )

        recentInsight = HealthSleepInsight(
            nights: nights,
            totalSleep: totalSleep,
            averageSleep: nights == 0 ? 0 : totalSleep / Double(nights),
            deepSleep: deep,
            coreSleep: core,
            remSleep: rem,
            awakeTime: awake,
            averageHeartRate: heartRate,
            averageHRV: hrv,
            averageRespiratoryRate: respiratoryRate,
            averageOxygenSaturation: oxygenFraction.map { $0 * 100 },
            averageWristTemperature: wristTemperature,
            startDate: startDate,
            endDate: endDate
        )
    }

    func save(session: SleepSession) async {
        guard let end = session.endTime,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        if store.authorizationStatus(for: sleepType) == .notDetermined {
            await requestAuthorization()
        }
        guard store.authorizationStatus(for: sleepType) == .sharingAuthorized else { return }

        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: session.startTime,
            end: end
        )
        try? await store.save(sample)
    }

    @discardableResult
    func requestMindfulnessAuthorization() async -> Bool {
        guard isAvailable,
              let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        do {
            try await store.requestAuthorization(toShare: [mindfulType], read: [])
            return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
        } catch {
            return false
        }
    }

    @discardableResult
    func saveMindfulSession(start: Date, end: Date) async -> Bool {
        guard end > start,
              let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        if store.authorizationStatus(for: mindfulType) == .notDetermined {
            _ = await requestMindfulnessAuthorization()
        }
        guard store.authorizationStatus(for: mindfulType) == .sharingAuthorized else { return false }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        do {
            try await store.save(sample)
            return true
        } catch {
            return false
        }
    }

    private static let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
        .heartRate,
        .heartRateVariabilitySDNN,
        .respiratoryRate,
        .oxygenSaturation,
        .appleSleepingWristTemperature
    ]

    /// 睡眠洞察只读取健康数据，不需要同时申请写入权限。
    /// 将读取与睡眠记录写入授权拆开，避免只读页面因写入权限不可用而无法继续。
    private func requestInsightReadAuthorization() async -> Bool {
        guard isAvailable,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            statusText = "当前设备不可用"
            insightMessage = "当前设备不支持 Apple 健康。睡眠洞察需要在支持健康 App 的 iPhone 上使用。"
            return false
        }

        isRequestingAuthorization = true
        statusText = "等待健康授权"
        defer { isRequestingAuthorization = false }

        do {
            try await store.requestAuthorization(toShare: [], read: insightReadTypes(sleepType: sleepType))
            // 出于隐私保护，HealthKit 不会向 App 返回单项读取权限是否被拒绝。
            // 授权流程正常结束后直接查询；没有权限或没有记录都会以空数据状态呈现。
            isAuthorized = true
            statusText = "已连接 Apple 健康"
            return true
        } catch {
            isAuthorized = false
            statusText = "授权失败"
            insightMessage = "Apple 健康授权未完成，请确认 HealthKit 能力已开启，并在系统设置中允许时光睡眠读取睡眠数据。"
            return false
        }
    }

    private func insightReadTypes(sleepType: HKCategoryType) -> Set<HKObjectType> {
        var readTypes: Set<HKObjectType> = [sleepType]
        Self.quantityIdentifiers.forEach { identifier in
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }
        return readTypes
    }

    private func categorySamples(type: HKCategoryType, predicate: NSPredicate) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }
    }

    private func quantitySamples(type: HKQuantityType, predicate: NSPredicate) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            store.execute(query)
        }
    }

    private func sleepingAverage(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate,
        intervals: [DateInterval]
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let samples = await quantitySamples(type: type, predicate: predicate)
        let values = samples.compactMap { sample -> Double? in
            guard intervals.contains(where: { $0.contains(sample.startDate) }) else { return nil }
            return sample.quantity.doubleValue(for: unit)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func duration(
        of value: HKCategoryValueSleepAnalysis,
        in samples: [HKCategorySample]
    ) -> TimeInterval {
        samples
            .filter { $0.value == value.rawValue }
            .reduce(0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
    }
}
