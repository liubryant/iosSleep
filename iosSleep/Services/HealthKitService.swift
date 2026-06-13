import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var isAuthorized = false
    @Published private(set) var statusText = "未授权"

    private let store = HKHealthStore()

    func requestAuthorization() async {
        guard isAvailable, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            statusText = "当前设备不可用"
            return
        }

        do {
            try await store.requestAuthorization(toShare: [sleepType], read: [sleepType])
            isAuthorized = true
            statusText = "已授权"
        } catch {
            isAuthorized = false
            statusText = "授权失败"
        }
    }

    func save(session: SleepSession) async {
        guard isAuthorized, let end = session.endTime, let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }

        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: session.startTime,
            end: end
        )
        try? await store.save(sample)
    }
}
