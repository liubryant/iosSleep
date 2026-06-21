import SwiftUI

struct StoryHomeView: View {
    @EnvironmentObject private var library: StoryLibrary
    @EnvironmentObject private var player: StoryPlayerService

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(library.stories) { story in
                        NavigationLink(value: story) {
                            StoryCardView(story: story)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .overlay {
                if library.stories.isEmpty {
                    EmptyStateView(title: "暂无故事资源", systemImage: "book.closed", message: "请确认 StoryResources 已导入。")
                }
            }
            .navigationDestination(for: StoryItem.self) { story in
                StoryPlayerView(story: story)
            }
        }
        .task {
            if library.stories.isEmpty {
                await library.load()
            }
        }
    }
}
