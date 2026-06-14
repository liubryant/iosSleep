import Foundation

enum AppConstants {
    static let appName = "时光睡眠"

    // MARK: - GroMore
    static let pangleAppID = "5839173"
    static let splashSlotID = "104134551"
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
