import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                SoundHomeView()
                    .tabItem {
                        Label("声音", systemImage: "waveform")
                    }

                SleepHomeView()
                    .tabItem {
                        Label("睡眠", systemImage: "moon.zzz.fill")
                    }

                StoryHomeView()
                    .tabItem {
                        Label("故事", systemImage: "book.closed.fill")
                    }

                ProfileView()
                    .tabItem {
                        Label("我的", systemImage: "person.crop.circle")
                    }
            }
            .tint(.indigo)

            if let story = storyPlayer.currentStory {
                GlobalStoryMiniPlayerView(story: story)
                    .padding(.horizontal)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            } else if let scene = player.currentScene {
                GlobalMiniPlayerView(scene: scene)
                    .padding(.horizontal)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: player.currentScene?.id)
        .animation(.easeInOut(duration: 0.2), value: storyPlayer.currentStory?.id)
        .onChange(of: player.currentScene?.id) { id in
            guard id != nil, storyPlayer.currentStory != nil else { return }
            storyPlayer.stop()
        }
        .onChange(of: storyPlayer.currentStory?.id) { id in
            guard id != nil, player.currentScene != nil else { return }
            player.stop()
        }
    }
}

private struct GlobalMiniPlayerView: View {
    @EnvironmentObject private var player: AudioPlayerService
    let scene: SoundScene

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(scene: scene)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(scene.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(scene.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let timer = player.sleepTimerText {
                    Text(timer)
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
            }

            Spacer()

            Button {
                player.toggle(scene: scene)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent)

            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

private struct GlobalStoryMiniPlayerView: View {
    @EnvironmentObject private var player: StoryPlayerService
    let story: StoryItem

    var body: some View {
        HStack(spacing: 12) {
            StoryCoverImage(story: story)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("睡前故事")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.resume()
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent)

            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}
