import Foundation

struct LocalizedText: Codable, Hashable {
    let en: String?
    let zhHans: String?
    let zhHant: String?
    let ja: String?

    enum CodingKeys: String, CodingKey {
        case en
        case zhHans = "zh-Hans"
        case zhHant = "zh-Hant"
        case ja
    }

    var displayText: String {
        zhHans?.nilIfEmpty ?? zhHant?.nilIfEmpty ?? en?.nilIfEmpty ?? ja?.nilIfEmpty ?? ""
    }
}

struct SoundScene: Codable, Identifiable, Hashable {
    let id: String
    let index: Int
    let directory: String
    let title: String
    let subtitle: String
    let category: String
    let coverFile: String
    let audioFile: String
    let duration: TimeInterval?

    var coverSubdirectory: String {
        "SoundResources/\(directory)"
    }

    var audioSubdirectory: String {
        "SoundResources/\(directory)"
    }

    var isBundledAudio: Bool {
        index <= 20
    }

    /// 普通用户可免费聆听资源列表中的前 30 个声音。
    /// 使用清单内稳定的 index 判断，避免搜索、收藏或分类后权限顺序发生变化。
    var requiresVIP: Bool {
        index > 30
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
