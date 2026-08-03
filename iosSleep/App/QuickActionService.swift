import UIKit

enum AppQuickAction: String {
    case nature = "com.iossleep.quickaction.nature"
    case stories = "com.iossleep.quickaction.stories"
}

@MainActor
final class QuickActionService {
    static let shared = QuickActionService()
    static let didRequestAction = Notification.Name("AppQuickActionDidRequest")
    static let didRequestNature = Notification.Name("AppQuickActionDidRequestNature")

    private var pendingAction: AppQuickAction?

    private init() {}

    func receive(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = AppQuickAction(rawValue: shortcutItem.type) else { return false }
        pendingAction = action
        NotificationCenter.default.post(name: Self.didRequestAction, object: action)
        return true
    }

    func consumePendingAction() -> AppQuickAction? {
        defer { pendingAction = nil }
        return pendingAction
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            Task { @MainActor in
                _ = QuickActionService.shared.receive(shortcutItem)
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            completionHandler(QuickActionService.shared.receive(shortcutItem))
        }
    }
}
