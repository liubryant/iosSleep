import Foundation

@MainActor
final class StoryLibrary: ObservableObject {
    @Published private(set) var stories: [StoryItem] = []

    func load() async {
        guard let url = Bundle.main.url(forResource: "stories_manifest", withExtension: "json", subdirectory: "StoryResources") else {
            stories = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            stories = try JSONDecoder().decode([StoryItem].self, from: data).sorted { lhs, rhs in
                if lhs.isBundled != rhs.isBundled {
                    return lhs.isBundled
                }
                return lhs.index < rhs.index
            }
        } catch {
            stories = []
            print("Failed to load stories_manifest.json: \(error)")
        }
    }
}
