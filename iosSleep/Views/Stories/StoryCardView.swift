import SwiftUI

struct StoryCardView: View {
    @EnvironmentObject private var player: StoryPlayerService
    let story: StoryItem

    var body: some View {
        ZStack(alignment: .bottom) {
            StoryCoverImage(story: story)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)

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

                Text(statusText)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)

            if let progress = player.downloadProgress[story.id] {
                VStack(spacing: 5) {
                    ProgressView(value: progress)
                        .tint(.white)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if !player.isBundledOrCached(story) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
            if player.currentStory?.id == story.id {
                Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.indigo)
                    .clipShape(Circle())
                    .padding(8)
            }
        }
    }

    private var statusText: String {
        player.isBundledOrCached(story) ? "点击播放" : "点击下载后播放"
    }
}

struct StoryCoverImage: View {
    let story: StoryItem

    var body: some View {
        if let url = story.bundledResourceURL(fileName: story.coverFile),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.linearGradient(colors: [.indigo.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
        }
    }
}
