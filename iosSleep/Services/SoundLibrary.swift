import Foundation

@MainActor
final class SoundLibrary: ObservableObject {
    @Published private(set) var scenes: [SoundScene] = []
    @Published private(set) var favorites: Set<String> = []
    @Published var searchText = ""

    private let favoritesKey = "sounds.favorites"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favorites = Set(saved)
    }

    var filteredScenes: [SoundScene] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return scenes }
        return scenes.filter { scene in
            scene.title.localizedCaseInsensitiveContains(text) ||
            scene.subtitle.localizedCaseInsensitiveContains(text) ||
            scene.category.localizedCaseInsensitiveContains(text)
        }
    }

    func load() async {
        guard let url = Bundle.main.url(forResource: "sounds_manifest", withExtension: "json", subdirectory: "SoundResources") else {
            scenes = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            scenes = try JSONDecoder().decode([SoundScene].self, from: data).sorted { $0.index < $1.index }
        } catch {
            scenes = []
            print("Failed to load sounds_manifest.json: \(error)")
        }
    }

    func isFavorite(_ scene: SoundScene) -> Bool {
        favorites.contains(scene.id)
    }

    func toggleFavorite(_ scene: SoundScene) {
        if favorites.contains(scene.id) {
            favorites.remove(scene.id)
        } else {
            favorites.insert(scene.id)
        }
        UserDefaults.standard.set(Array(favorites), forKey: favoritesKey)
    }
}
