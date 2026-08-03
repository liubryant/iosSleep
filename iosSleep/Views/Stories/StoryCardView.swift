import SwiftUI

struct StoryCardView: View {
    @EnvironmentObject private var player: StoryPlayerService
    let story: StoryItem

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                StoryCoverImage(story: story)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .gray.opacity(0.2), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(story.author?.isEmpty == false ? story.author! : statusText)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)

                if story.isArticle {
                    Text("散文")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.blue.opacity(0.92))
                        .clipShape(Capsule())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
            if player.currentStory?.id == story.id {
                Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.blue)
                    .clipShape(Circle())
                    .padding(8)
            }
        }
    }

    private var statusText: String {
        player.isBundledOrCached(story) ? "点击播放" : "免费朗读"
    }
}

struct StoryCoverImage: View {
    let story: StoryItem

    var body: some View {
        if !story.coverFile.isEmpty,
           let url = story.bundledResourceURL(fileName: story.coverFile),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.linearGradient(colors: [.blue.opacity(0.45), .cyan.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
        }
    }
}
