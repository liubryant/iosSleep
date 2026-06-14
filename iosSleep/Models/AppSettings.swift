import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: Keys.isLoggedIn) }
    }

    @Published var saveAudioClips: Bool {
        didSet { UserDefaults.standard.set(saveAudioClips, forKey: Keys.saveAudioClips) }
    }

    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: Keys.sensitivity) }
    }

    @Published var agreementAccepted: Bool {
        didSet { UserDefaults.standard.set(agreementAccepted, forKey: Keys.agreementAccepted) }
    }

    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: Keys.isLoggedIn)
        saveAudioClips = UserDefaults.standard.object(forKey: Keys.saveAudioClips) as? Bool ?? true
        sensitivity = UserDefaults.standard.object(forKey: Keys.sensitivity) as? Double ?? 0.65
        agreementAccepted = UserDefaults.standard.bool(forKey: Keys.agreementAccepted)
    }

    func login() {
        isLoggedIn = true
    }

    func logout() {
        isLoggedIn = false
    }

    func acceptAgreement() {
        agreementAccepted = true
    }
}

private enum Keys {
    static let isLoggedIn = "profile.isLoggedIn"
    static let saveAudioClips = "settings.saveAudioClips"
    static let sensitivity = "settings.sensitivity"
    static let agreementAccepted = "agreement_accepted"
}
