import Foundation

#if canImport(UMCommon)
import UMCommon
#endif

final class UMengAnalytics {
    static let shared = UMengAnalytics()

    private var isInitialized = false

    private init() {}

    /// 初始化友盟统计。合规要求：只能在用户同意《用户协议》《隐私政策》后调用。
    func initialize() {
        guard ConsentStore.agreementAccepted else { return }
        guard !isInitialized else { return }

        #if canImport(UMCommon)
        UMConfigure.initWithAppkey(AppConstants.umengAppKey, channel: AppConstants.umengChannel)
        #if DEBUG
        UMConfigure.setLogEnabled(true)
        #else
        UMConfigure.setLogEnabled(false)
        #endif
        isInitialized = true
        print("UMeng initialized: \(AppConstants.umengAppKey)")
        #else
        print("UMeng SDK is not installed. Run pod install first.")
        #endif
    }

    func logEvent(_ eventId: String, attributes: [String: Any]? = nil) {
        guard ConsentStore.agreementAccepted, isInitialized else { return }

        #if canImport(UMCommon)
        if let attributes {
            MobClick.event(eventId, attributes: attributes)
        } else {
            MobClick.event(eventId)
        }
        #endif
    }

    func pageBegin(_ pageName: String) {
        guard ConsentStore.agreementAccepted, isInitialized else { return }

        #if canImport(UMCommon)
        MobClick.beginLogPageView(pageName)
        #endif
    }

    func pageEnd(_ pageName: String) {
        guard ConsentStore.agreementAccepted, isInitialized else { return }

        #if canImport(UMCommon)
        MobClick.endLogPageView(pageName)
        #endif
    }
}
