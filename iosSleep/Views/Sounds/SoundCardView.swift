import SwiftUI
import UIKit

struct SoundCardView: View {
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService

    let scene: SoundScene
    var isVIPContent = false
    var onVIPRequired: (() -> Void)?

    init(scene: SoundScene, isVIPContent: Bool = false, onVIPRequired: (() -> Void)? = nil) {
        self.scene = scene
        self.isVIPContent = isVIPContent
        self.onVIPRequired = onVIPRequired
    }

    var body: some View {
        Button {
            if let onVIPRequired {
                onVIPRequired()
                return
            }
            if storyPlayer.currentStory != nil {
                storyPlayer.stop()
            }
            player.toggle(scene: scene)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    CoverImage(scene: scene)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if isVIPContent {
                        Label("VIP", systemImage: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(.ultraThinMaterial.opacity(0.88))
                            .background(Color.black.opacity(0.16))
                            .clipShape(Capsule())
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

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

                    if let progress = player.downloadProgress[scene.id] {
                        VStack(spacing: 6) {
                            ProgressView(value: progress)
                                .tint(.white)
                            Text("\(Int(progress * 100))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    } else if !scene.isBundledAudio, !player.cachedAudioExists(for: scene) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.35))
                            .clipShape(Circle())
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if player.currentScene?.id == scene.id {
                        PlayingWaveformIcon(isAnimating: player.isPlaying)
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(.blue, in: Circle())
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.title)
                        .font(.headline)
                        .foregroundStyle(SoundHomeTextColor.title)
                        .lineLimit(1)

                    Text(scene.subtitle.isEmpty ? "助眠声音" : scene.subtitle)
                        .font(.caption)
                        .foregroundStyle(SoundHomeTextColor.detail)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PlayingWaveformIcon: View {
    let isAnimating: Bool

    private let baseHeights: [CGFloat] = [7, 13, 10, 15]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: !isAnimating)) { context in
            HStack(alignment: .center, spacing: 2) {
                ForEach(baseHeights.indices, id: \.self) { index in
                    Capsule()
                        .fill(.white)
                        .frame(
                            width: 2.5,
                            height: barHeight(at: index, date: context.date)
                        )
                }
            }
            .frame(width: 16, height: 16)
        }
    }

    private func barHeight(at index: Int, date: Date) -> CGFloat {
        guard isAnimating else { return baseHeights[index] }
        let phase = date.timeIntervalSinceReferenceDate * 3.5 + Double(index) * 1.35
        let factor = 0.55 + 0.45 * abs(sin(phase))
        return max(4, baseHeights[index] * factor)
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
                .fill(.linearGradient(colors: [.blue.opacity(0.45), .cyan.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
        }
    }
}
