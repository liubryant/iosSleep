import Foundation

struct StoryItem: Codable, Identifiable, Hashable {
    let id: String
    let index: Int
    let directory: String
    let title: String
    let author: String?
    let summary: String?
    let coverFile: String
    let audioFile: String
    let textFile: String?
    let duration: TimeInterval?
    let isBundled: Bool

    var coverSubdirectory: String {
        "StoryResources/\(directory)"
    }

    var audioSubdirectory: String {
        "StoryResources/\(directory)"
    }

    func bundledResourceURL(fileName: String, in bundle: Bundle = .main) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let url: URL
        if fileName.hasPrefix("StoryResources/") {
            url = resourceURL.appendingPathComponent(fileName, isDirectory: false)
        } else {
            url = resourceURL
                .appendingPathComponent("StoryResources", isDirectory: true)
                .appendingPathComponent(directory, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var storyTextFile: String { textFile ?? "story.txt" }
    var isArticle: Bool { index >= 1000 || textFile != nil }

    enum CodingKeys: String, CodingKey {
        case id, index, directory, title, author, summary, coverFile, audioFile
        case textFile, duration, isBundled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        index = try container.decode(Int.self, forKey: .index)
        directory = try container.decodeIfPresent(String.self, forKey: .directory) ?? ""
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        coverFile = try container.decodeIfPresent(String.self, forKey: .coverFile) ?? ""
        audioFile = try container.decodeIfPresent(String.self, forKey: .audioFile) ?? ""
        textFile = try container.decodeIfPresent(String.self, forKey: .textFile)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        isBundled = try container.decodeIfPresent(Bool.self, forKey: .isBundled) ?? false
    }
}
