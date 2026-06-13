import SwiftUI
import UIKit

struct SoundCardView: View {
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService

    let scene: SoundScene

    var body: some View {
        Button {
            player.toggle(scene: scene)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    CoverImage(scene: scene)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        library.toggleFavorite(scene)
                    } label: {
                        Image(systemName: library.isFavorite(scene) ? "heart.fill" : "heart")
                            .foregroundStyle(library.isFavorite(scene) ? .red : .white)
                            .padding(8)
                            .background(.black.opacity(0.25))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(scene.subtitle.isEmpty ? "助眠声音" : scene.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(minHeight: 34, alignment: .top)
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                if player.currentScene?.id == scene.id {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.indigo)
                        .clipShape(Circle())
                        .padding(14)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CoverImage: View {
    let scene: SoundScene

    var body: some View {
        if let url = Bundle.main.url(forResource: "cover", withExtension: "jpg", subdirectory: scene.coverSubdirectory),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.linearGradient(colors: [.indigo.opacity(0.4), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
        }
    }
}
