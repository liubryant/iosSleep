import SwiftUI

struct StoryHomeView: View {
    @Binding var requestedStoryID: String?
    @EnvironmentObject private var library: StoryLibrary
    @EnvironmentObject private var player: StoryPlayerService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @ObservedObject private var notificationService = StoryNotificationService.shared
    @State private var searchText = ""
    @State private var navigationPath: [StoryItem] = []

    private var columns: [GridItem] {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        }
        return [GridItem(.adaptive(minimum: 160), spacing: 16)]
    }

    private var filteredStories: [StoryItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches: [StoryItem]
        if keyword.isEmpty {
            matches = library.stories
        } else {
            matches = library.stories.filter {
                $0.title.localizedCaseInsensitiveContains(keyword) ||
                ($0.author?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                ($0.summary?.localizedCaseInsensitiveContains(keyword) ?? false)
            }
        }

        // 稳定分组，不改变收藏组和普通组各自原有的推荐顺序。
        return matches.filter { library.isFavorite($0) }
            + matches.filter { !library.isFavorite($0) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    storySearchBar

                    if library.articlesEnabled {
                        storySection(title: SleepL10n.text("故事推荐"), stories: filteredStories)
                    } else {
                        storySection(title: SleepL10n.text("睡前故事"), stories: filteredStories)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 18 + (player.currentStory == nil && audioPlayer.currentScene == nil ? 0 : miniPlayerOverlayInset))
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .overlay {
                if library.stories.isEmpty {
                    ProgressView(SleepL10n.text("正在加载故事…"))
                } else if filteredStories.isEmpty {
                    EmptyStateView(title: SleepL10n.text("未找到相关内容"), systemImage: "magnifyingglass", message: SleepL10n.text("换个标题或作者试试。"))
                }
            }
            .navigationTitle(SleepL10n.text("故事"))
            .navigationDestination(for: StoryItem.self) { story in
                StoryPlayerView(story: story) { nextStory in
                    navigationPath = [nextStory]
                }
            }
        }
        .task(id: notificationService.pendingStoryID) {
            if library.stories.isEmpty {
                await library.load()
            }
            await openPendingNotificationStory()
        }
        .task(id: requestedStoryID) {
            await openRequestedStory()
        }
        .onChange(of: requestedStoryID) { _ in
            Task { @MainActor in
                await openRequestedStory()
            }
        }
        .onAppear {
            Task { @MainActor in
                await openRequestedStory()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: StoryNotificationService.didOpenStory)) { _ in
            Task { @MainActor in
                await openPendingNotificationStory()
            }
        }
    }

    @MainActor
    private func openPendingNotificationStory() async {
        guard let storyID = StoryNotificationService.shared.peekPendingStoryID() else { return }
        if library.stories.isEmpty {
            await library.load()
        }
        guard let story = library.stories.first(where: { $0.id == storyID }) else { return }
        navigationPath = [story]
        StoryNotificationService.shared.clearPendingStoryID(storyID)
    }

    @MainActor
    private func openRequestedStory() async {
        guard let storyID = requestedStoryID else { return }
        if library.stories.isEmpty {
            await library.load()
        }
        guard let story = library.stories.first(where: { $0.id == storyID }) else { return }
        navigationPath = [story]
        requestedStoryID = nil
        StoryNotificationService.shared.clearPendingStoryID(storyID)
    }

    private var storySearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(SleepL10n.text("搜索故事、文章"), text: $searchText)
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
                    Text(verbatim: SleepL10n.text(title))
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(SleepL10n.format("{0}篇", [String(describing: stories.count)]))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(stories) { story in
                        ZStack(alignment: .bottomTrailing) {
                            NavigationLink(value: story) {
                                StoryCardView(story: story)
                            }
                            .buttonStyle(.plain)

                            Button {
                                library.toggleFavorite(story)
                            } label: {
                                Image(systemName: library.isFavorite(story) ? "heart.fill" : "heart")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(library.isFavorite(story) ? Color.red : Color.white)
                                    .frame(width: 28, height: 28)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay {
                                        Circle().stroke(.white.opacity(0.25), lineWidth: 0.5)
                                    }
                                    .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                            }
                            .buttonStyle(.plain)
                            .padding(7)
                            .accessibilityLabel(library.isFavorite(story) ? SleepL10n.format("取消收藏{0}", [String(describing: story.title)]) : SleepL10n.format("收藏{0}", [String(describing: story.title)]))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
