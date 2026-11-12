import Foundation

@MainActor
final class SoundLibrary: ObservableObject {
    @Published private(set) var scenes: [SoundScene] = []
    @Published private(set) var favorites: Set<String> = []
    @Published var searchText = ""

    private let favoritesKey = "sounds.favorites"

    static func isIncludedInNatureSleep(_ scene: SoundScene) -> Bool {
        let excludedTitles: Set<String> = ["打字机", "篮球场", "洗碗机", "图书馆", "雨窗", "沉睡小夜曲", "睡吧睡吧", "年"]
        return !excludedTitles.contains(scene.title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favorites = Set(saved)
    }

    var filteredScenes: [SoundScene] {
        let tokens = searchText.split(whereSeparator: \.isWhitespace).map { normalized(String($0)) }
        guard !tokens.isEmpty else { return scenes }
        let phrase = tokens.joined()
        return scenes.compactMap { scene -> (scene: SoundScene, rank: Int)? in
            let title = normalized(scene.title)
            if title == phrase { return (scene, 0) }
            if title.hasPrefix(phrase) { return (scene, 1) }
            if title.contains(phrase) { return (scene, 2) }
            let details = [title, normalized(scene.subtitle), normalized(scene.category)]
            if tokens.allSatisfy({ token in details.contains(where: { $0.contains(token) }) }) {
                return (scene, 3)
            }
            if tokens.allSatisfy({ token in
                title.contains(token) || (token.count > 1 && matchesInOrder(token, in: title))
            }) {
                return (scene, 4)
            }
            return nil
        }.sorted {
            $0.rank == $1.rank ? $0.scene.index < $1.scene.index : $0.rank < $1.rank
        }.map(\.scene)
    }

    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .filter { !$0.isWhitespace }
    }

    private func matchesInOrder(_ token: String, in title: String) -> Bool {
        var letters = token.makeIterator()
        var next = letters.next()
        for character in title where character == next {
            next = letters.next()
            if next == nil { return true }
        }
        return false
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
