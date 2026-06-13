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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
