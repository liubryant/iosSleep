import Foundation

enum AppConstants {
    static let appName = "时光睡眠"
    static let soundServerBaseURL = URL(string: "https://www.cjym123.cn/api/sounds")!
    static let storyServerBaseURL = URL(string: "https://www.cjym123.cn/api/stories")!

    // MARK: - GroMore
    static let pangleAppID = "5839173"
    static let splashSlotID = "104134551"
    static let drawFeedSlotID = "104134653"
    static let rewardedVideoSlotID = "104134740"
    static var isAdDisabled = false

    // MARK: - UMeng
    static let umengAppKey = "6a2e04816f259537c7b8b474"
    static let umengChannel = "App Store"
}

enum ConsentStore {
    static let agreementAcceptedKey = "agreement_accepted"

    static var agreementAccepted: Bool {
        UserDefaults.standard.bool(forKey: agreementAcceptedKey)
    }
}
