import SwiftUI

struct StoryHomeView: View {
    @EnvironmentObject private var library: StoryLibrary
    @EnvironmentObject private var player: StoryPlayerService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @State private var searchText = ""
    @State private var navigationPath: [StoryItem] = []

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var filteredStories: [StoryItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return library.stories }
        return library.stories.filter {
            $0.title.localizedCaseInsensitiveContains(keyword) ||
            ($0.author?.localizedCaseInsensitiveContains(keyword) ?? false) ||
            ($0.summary?.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    storySearchBar

                    if library.articlesEnabled {
                        storySection(title: "故事推荐", stories: filteredStories)
                    } else {
                        storySection(title: "睡前故事", stories: filteredStories)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, player.currentStory == nil && audioPlayer.currentScene == nil ? 18 : 106)
            }
            .overlay {
                if library.stories.isEmpty {
                    ProgressView("正在加载故事…")
                } else if filteredStories.isEmpty {
                    EmptyStateView(title: "未找到相关内容", systemImage: "magnifyingglass", message: "换个标题或作者试试。")
                }
            }
            .navigationTitle("故事")
            .navigationDestination(for: StoryItem.self) { story in
                StoryPlayerView(story: story)
            }
        }
        .task {
            if library.stories.isEmpty {
                await library.load()
            }
            openPendingNotificationStory()
        }
        .onReceive(NotificationCenter.default.publisher(for: StoryNotificationService.didOpenStory)) { _ in
            openPendingNotificationStory()
        }
    }

    private func openPendingNotificationStory() {
        guard let storyID = StoryNotificationService.shared.consumePendingStoryID(),
              let story = library.stories.first(where: { $0.id == storyID }) else { return }
        navigationPath = [story]
    }

    private var storySearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索故事、文章", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func storySection(title: String, stories: [StoryItem]) -> some View {
        if !stories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(stories.count)篇")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(stories) { story in
                        NavigationLink(value: story) {
                            StoryCardView(story: story)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
