import SwiftUI

@main
struct iosSleepApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var soundLibrary = SoundLibrary()
    @StateObject private var player = AudioPlayerService()
    @StateObject private var storyLibrary = StoryLibrary()
    @StateObject private var storyPlayer = StoryPlayerService()
    @StateObject private var mindfulnessPlayer = MindfulnessAudioPlayer()
    @StateObject private var sleepMonitor = SleepMonitorService()
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var settings = AppSettings()
    @StateObject private var sdkManager = AppSDKManager.shared

    var body: some Scene {
        WindowGroup {
            StartupGateView()
                .environmentObject(soundLibrary)
                .environmentObject(player)
                .environmentObject(storyLibrary)
                .environmentObject(storyPlayer)
                .environmentObject(mindfulnessPlayer)
                .environmentObject(sleepMonitor)
                .environmentObject(healthKit)
                .environmentObject(settings)
                .environmentObject(sdkManager)
        }
    }
}

enum SleepL10n {
    static func text(_ key: String) -> String {
        let translated = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        if translated != key { return translated }
        for template in templates {
            guard let match = template.expression.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) else { continue }
            let localized = Bundle.main.localizedString(forKey: template.key, value: template.key, table: nil)
            guard localized != template.key else { continue }
            let arguments = (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: key).map { String(key[$0]) } ?? ""
            }
            var result = localized
            for index in arguments.indices.reversed() {
                result = result.replacingOccurrences(of: "{\(index)}", with: text(arguments[index]))
            }
            return result
        }
        return key
    }

    private static let templates: [(key: String, expression: NSRegularExpression)] = templateKeys.compactMap { key in
        var pattern = NSRegularExpression.escapedPattern(for: key)
        for index in (0..<10).reversed() {
            pattern = pattern.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: "{\(index)}"), with: "([\\s\\S]*?)")
        }
        guard let expression = try? NSRegularExpression(pattern: "^" + pattern + "$") else { return nil }
        return (key, expression)
    }

    private static let templateKeys: [String] = [
    "你目前表现更突出的倾向是{0}。五个维度共同构成完整画像，不代表能力高低，也不会把你限制在固定类型里。",
    "最近 {0} 天没有可读取的睡眠数据。你可以先用 Apple Watch 或时光睡眠完成一次睡眠记录。",
    "深度睡眠 {0} 分钟（参考值 >90 分钟，{1}）。",
    "打开 {0} 官方 App，并确认设备已经完成同步。",
    "{0} · {1} 个事件 · 平均 {2} dB",
    "验证手机号 {0} 后修改密码，之后可使用密码登录",
    "您在 {0} 开始入睡，{1} 结束睡眠。",
    "时光睡眠为你精选，点击立即播放《{0}》",
    "验证手机号 {0} 后将永久注销账号",
    "会员权益已恢复，有效期至 {0}",
    "支付成功，订阅有效期至 {0}",
    "睡眠中觉醒约 {0} 分钟。",
    "已保存 {0} 次测评结果",
    "开通会员即可播放「{0}」",
    "{0} 小时 {1} 分",
    "会员权益有效期至 {0}",
    "{0}，{1} 摄氏度",
    "听一段练习 · {0}",
    "每天 {0} 精选故事",
    "浅睡眠 {0} 分钟。",
    "环境音量 {0} dB",
    "今日故事 · {0}",
    "做梦 {0} 分钟。",
    "未找到{0}音频资源",
    "正在下载… {0}%",
    "{0} 分钟后停止",
    "{0}小时{1}分",
    "学习与工作：{0}",
    "沟通与关系：{0}",
    "{0} 连接指南",
    "{0}，时光睡眠",
    "成长提醒：{0}",
    "有效期至 {0}",
    "{0} 次/分",
    "取消收藏{0}",
    "第 {0} 题",
    "近 {0} 天",
    "{0} 分钟",
    "优势：{0}",
    "{0} 分",
    "{0} 岁",
    "{0} 晚",
    "{0} 次",
    "收藏{0}",
    "{0}秒",
    "{0}篇"
]

    static func format(_ key: String, _ arguments: [String]) -> String {
        var result = text(key)
        for index in arguments.indices.reversed() {
            result = result.replacingOccurrences(of: "{\(index)}", with: text(arguments[index]))
        }
        return result
    }
}
