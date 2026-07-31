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
        stories = (bundledStories + articles).sorted { lhs, rhs in
            if lhs.isArticle != rhs.isArticle { return !lhs.isArticle }
            if lhs.isBundled != rhs.isBundled { return lhs.isBundled }
            return lhs.index < rhs.index
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
    private let notificationHours = [11, 16, 20]
    private let identifierPrefix = "daily_story_recommendation_"
    private(set) var pendingStoryID: String?

    private override init() {
        super.init()
        center.delegate = self
    }

    func enable(stories: [StoryItem]) async -> Bool {
        guard !stories.isEmpty else { return false }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            await scheduleDailyStories(stories: stories)
            await scheduleTestNotification(stories: stories)
            return true
        } catch {
            return false
        }
    }

    func disable() {
        let identifiers = notificationHours.indices.map { "\(identifierPrefix)\($0)" } + ["story_test_after_launch"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleTestNotification(stories: [StoryItem]) async {
        guard let story = stories.randomElement() else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["story_test_after_launch"])
        let content = UNMutableNotificationContent()
        content.title = "今日故事 · \(story.title)"
        content.body = "时光睡眠为你精选，点击立即播放《\(story.title)》"
        content.sound = .default
        content.userInfo = ["storyID": story.id, "storyIndex": story.index]
        let request = UNNotificationRequest(
            identifier: "story_test_after_launch",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        try? await center.add(request)
    }

    func consumePendingStoryID() -> String? {
        defer { pendingStoryID = nil }
        return pendingStoryID
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
            self.pendingStoryID = storyID
            NotificationCenter.default.post(name: Self.didOpenStory, object: storyID)
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
