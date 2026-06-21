import Foundation

struct StoryItem: Codable, Identifiable, Hashable {
    let id: String
    let index: Int
    let directory: String
    let title: String
    let coverFile: String
    let audioFile: String
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
        let url = resourceURL
            .appendingPathComponent("StoryResources", isDirectory: true)
            .appendingPathComponent(directory, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
