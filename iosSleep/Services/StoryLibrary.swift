import Foundation
import UserNotifications

@MainActor
final class StoryLibrary: ObservableObject {
    @Published private(set) var stories: [StoryItem] = []
    @Published private(set) var articlesEnabled = false

    func load() async {
        guard let bundledStories = decodeResource("stories_manifest") else {
            stories = []
            return
        }

        let enabled = await RemoteContentConfig.fetchStorySwitch() == 1
        articlesEnabled = enabled
        let articles = enabled ? (decodeResource("contemporary_articles") ?? []) : []
        if enabled {
            stories = (bundledStories + articles).shuffled()
        } else {
            stories = bundledStories.sorted { $0.index < $1.index }
        }
    }

    private func decodeResource(_ name: String) -> [StoryItem]? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "StoryResources"
        ) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([StoryItem].self, from: data)
        } catch {
            print("Failed to load \(name).json: \(error)")
            return nil
        }
    }
}

@MainActor
final class StoryNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = StoryNotificationService()
    static let didOpenStory = Notification.Name("StoryNotificationDidOpenStory")

    private let center = UNUserNotificationCenter.current()
    static let notificationHours = [21, 22]
    static var reminderScheduleText: String {
        notificationHours.map { String(format: "%02d:00", $0) }.joined(separator: "、")
    }
    private let notificationHours = StoryNotificationService.notificationHours
    private let identifierPrefix = "daily_story_recommendation_"
    private let notificationIconMigrationKey = "notification_icon_migrated_to_app_icon_current"
    @Published private(set) var pendingStoryID: String?

    private override init() {
        super.init()
        center.delegate = self
        clearLegacyNotificationsIfNeeded()
    }

    /// 通知中心会保留旧版本通知及其 App 图标快照。更换 App Icon 后只执行一次清理，
    /// 后续新建的通知将统一读取当前安装包中的 AppIconCurrent。
    private func clearLegacyNotificationsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: notificationIconMigrationKey) else { return }
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        UserDefaults.standard.set(true, forKey: notificationIconMigrationKey)
    }

    func enable(stories: [StoryItem]) async -> Bool {
        guard !stories.isEmpty else { return false }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            await scheduleDailyStories(stories: stories)
            return true
        } catch {
            return false
        }
    }

    /// 首次进入首页时主动请求系统通知权限；已经选择过的用户不重复弹窗。
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func disable() {
        // 同时移除旧版 11/16/20 点对应的三个任务，避免升级后残留 20 点通知。
        let scheduleCount = max(notificationHours.count, 3)
        // 同时移除旧版本遗留的 5 秒测试通知。
        let identifiers = (0..<scheduleCount).map { "\(identifierPrefix)\($0)" } + ["story_test_after_launch"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func peekPendingStoryID() -> String? {
        return pendingStoryID
    }

    /// 统一处理通知、桌面快捷菜单等入口发起的故事详情跳转。
    func requestOpenStory(_ storyID: String) {
        pendingStoryID = storyID
        NotificationCenter.default.post(name: Self.didOpenStory, object: storyID)
    }

    func clearPendingStoryID(_ storyID: String) {
        guard pendingStoryID == storyID else { return }
        pendingStoryID = nil
    }

    private func scheduleDailyStories(stories: [StoryItem]) async {
        disable()
        for (index, hour) in notificationHours.enumerated() {
            guard let story = stories.randomElement() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "今日故事 · \(story.title)"
            content.body = "时光睡眠为你精选，点击立即播放《\(story.title)》"
            content.sound = .default
            content.userInfo = ["storyID": story.id, "storyIndex": story.index]
            attachCover(of: story, to: content)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: 0),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func attachCover(of story: StoryItem, to content: UNMutableNotificationContent) {
        guard !story.coverFile.isEmpty,
              let coverURL = story.bundledResourceURL(fileName: story.coverFile),
              let attachment = try? UNNotificationAttachment(
                identifier: "story-cover-\(story.id)",
                url: coverURL,
                options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
              ) else { return }
        content.attachments = [attachment]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let storyID = response.notification.request.content.userInfo["storyID"] as? String
        Task { @MainActor in
            if let storyID {
                self.requestOpenStory(storyID)
            }
            completionHandler()
        }
    }
}

private enum RemoteContentConfig {
    private struct Response: Decodable {
        struct Content: Decodable {
            let storySwitch: FlexibleInt?
        }
        let resultCode: Int?
        let data: Content?
    }

    private struct FlexibleInt: Decodable {
        let value: Int

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Int.self) {
                value = number
            } else {
                value = Int(try container.decode(String.self)) ?? 0
            }
        }
    }

    static func fetchStorySwitch() async -> Int {
        guard let url = URL(string: "https://www.cjym123.cn/api/info") else { return 0 }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadRevalidatingCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return 0 }
            let result = try JSONDecoder().decode(Response.self, from: data)
            guard result.resultCode == 200 else { return 0 }
            return result.data?.storySwitch?.value == 1 ? 1 : 0
        } catch {
            return 0
        }
    }
}
