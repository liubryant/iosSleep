import SwiftUI
import UIKit

struct MindfulnessHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @State private var selectedBanner = 0
    @State private var pendingNatureSceneID: String?
    @State private var selectedNatureScene: SoundScene?

    private let bannerTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    private let banners: [MindfulnessBanner] = [
        .init(
            eyebrow: "认识正念", title: "正念，是温柔地回到此刻",
            detail: "不评判此刻的感受，只是留意呼吸、身体与正在发生的一切。",
            icon: "figure.mind.and.body",
            colors: [Color(red: 0.10, green: 0.34, blue: 0.36), Color(red: 0.35, green: 0.58, blue: 0.51)]
        ),
        .init(
            eyebrow: "开始练习", title: "从一次自然呼吸开始",
            detail: "找一个舒服的姿势，闭上眼睛，跟随声音，把注意力放在呼吸上。",
            icon: "wind",
            colors: [Color(red: 0.25, green: 0.27, blue: 0.48), Color(red: 0.49, green: 0.48, blue: 0.70)]
        ),
        .init(
            eyebrow: "练习提示", title: "走神了，也完全没关系",
            detail: "发现思绪飘走时，不必责备自己，轻轻觉察，再慢慢回到当下。",
            icon: "leaf.fill",
            colors: [Color(red: 0.42, green: 0.29, blue: 0.20), Color(red: 0.69, green: 0.51, blue: 0.34)]
        )
    ]

    private let meditationItems: [MindfulnessHomeItem] = [
        .init(title: "深度睡眠疗愈", subtitle: "卸下疲惫，沉入安稳梦境", icon: "moon.stars.fill", colors: [.indigo, .blue], imageName: "1", track: .deepSleep),
        .init(title: "日间提神", subtitle: "唤醒精神，找回清晰专注", icon: "sun.max.fill", colors: [.orange, .yellow], imageName: "2", track: .daytimeEnergy),
        .init(title: "散步冥想", subtitle: "跟随脚步，感受此时此地", icon: "figure.walk", colors: [.green, .teal], imageName: "3", track: .walking),
        .init(title: "睡前释放情绪", subtitle: "温柔放下今天的情绪", icon: "cloud.moon.fill", colors: [.purple, .indigo], imageName: "4", track: .emotionalRelease),
        .init(title: "安定身心助眠", subtitle: "舒缓呼吸，让身体松下来", icon: "heart.circle.fill", colors: [.teal, .cyan], imageName: "5", track: .calmingSleep),
        .init(title: "缓解疲倦", subtitle: "短暂休息，恢复身心能量", icon: "leaf.fill", colors: [.mint, .green], imageName: "6", track: .fatigueRelief),
        .init(title: "快速入睡", subtitle: "平静思绪，更快进入睡眠", icon: "zzz", colors: [.blue, .indigo], imageName: "7", track: .quickSleep),
        .init(title: "考前失眠解放", subtitle: "减少紧张，安心迎接明天", icon: "book.closed.fill", colors: [.pink, .purple], imageName: "8", track: .examSleep)
    ]

    private var natureItems: [MindfulnessHomeItem] {
        library.scenes.suffix(20).map { scene in
            MindfulnessHomeItem(
                title: scene.title,
                subtitle: scene.subtitle.isEmpty ? "聆听自然，安然入眠" : scene.subtitle,
                icon: "leaf.fill",
                colors: natureColors(for: scene.index),
                scene: scene
            )
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    contentSection(title: "正念冥想", subtitle: "跟随声音，把注意力带回当下", items: meditationItems)
                        .padding(.top, -10)
                    contentSection(title: "大自然中入眠", subtitle: "枕着山海风雨，慢慢沉入梦乡", items: natureItems)
                }
                .padding(.bottom, 34)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preference(key: MindfulnessFlowVisibilityPreferenceKey.self, value: true)
        .navigationDestination(isPresented: Binding(
            get: { selectedNatureScene != nil },
            set: { if !$0 { selectedNatureScene = nil } }
        )) {
            if let scene = selectedNatureScene {
                MindfulnessPlayerView(track: natureTrack(for: scene))
            }
        }
        .onReceive(bannerTimer) { _ in
            selectedBanner = (selectedBanner + 1) % banners.count
        }
        .onChange(of: player.currentScene?.id) { sceneID in
            guard let sceneID, sceneID == pendingNatureSceneID,
                  let scene = natureItems.compactMap(\.scene).first(where: { $0.id == sceneID }),
                  player.localAudioURL(for: scene) != nil else { return }
            pendingNatureSceneID = nil
            selectedNatureScene = scene
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Spacer()
            Text("自在正念").font(.headline.weight(.semibold))
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            TabView(selection: $selectedBanner) {
                ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                    GeometryReader { geometry in
                        bannerCard(banner)
                            .frame(
                                width: max(geometry.size.width - 20, 0),
                                height: geometry.size.height
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 164)

            HStack(spacing: 7) {
                ForEach(banners.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedBanner ? Color.primary.opacity(0.72) : Color.primary.opacity(0.16))
                        .frame(width: index == selectedBanner ? 20 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.25), value: selectedBanner)
                        .onTapGesture { withAnimation { selectedBanner = index } }
                }
            }
        }
        .padding(.horizontal, 10).padding(.top, 18)
    }

    private func bannerCard(_ banner: MindfulnessBanner) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: banner.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(.white.opacity(0.10)).frame(width: 210, height: 210).offset(x: 220, y: -88)
            Circle().fill(.white.opacity(0.07)).frame(width: 130, height: 130).blur(radius: 4).offset(x: -35, y: 78)
            Image(systemName: banner.icon)
                .font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.20))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 26)

            VStack(alignment: .leading, spacing: 11) {
                Text(banner.title)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                Text(banner.detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(3)
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .frame(width: 285, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .position(x: 166.5, y: 79)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .mask(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .compositingGroup()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func contentSection(title: String, subtitle: String, items: [MindfulnessHomeItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(244), spacing: 16), GridItem(.fixed(244), spacing: 16)], spacing: 16) {
                    ForEach(items) { item in destination(for: item) }
                }
                .padding(.horizontal, 20).padding(.vertical, 2)
            }
            .frame(height: 504)
        }
    }

    @ViewBuilder
    private func destination(for item: MindfulnessHomeItem) -> some View {
        if let track = item.track {
            NavigationLink { MindfulnessPlayerView(track: track) } label: { card(item) }.buttonStyle(.plain)
        } else if let scene = item.scene {
            Button {
                if storyPlayer.currentStory != nil { storyPlayer.stop() }
                if player.localAudioURL(for: scene) != nil {
                    selectedNatureScene = scene
                } else {
                    pendingNatureSceneID = scene.id
                    player.toggle(scene: scene)
                }
            } label: { card(item) }
            .buttonStyle(.plain)
        } else {
            Button {} label: { card(item, unavailable: true) }.buttonStyle(.plain).disabled(true)
        }
    }

    private func card(_ item: MindfulnessHomeItem, unavailable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack {
                if let scene = item.scene {
                    CoverImage(scene: scene)
                    LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
                } else if let imageName = item.imageName, let image = mindfulnessImage(named: imageName) {
                    Image(uiImage: image).resizable().scaledToFill()
                    LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.white.opacity(0.13)).frame(width: 120).offset(x: 70, y: -45)
                    Image(systemName: item.icon).font(.system(size: 42, weight: .light)).foregroundStyle(.white)
                }
            }
            .frame(width: 184, height: 184)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                cardStatus(for: item, unavailable: unavailable).padding(9)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(unavailable ? "音频即将上线" : item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(width: 184, alignment: .leading)
        }
    }

    @ViewBuilder
    private func cardStatus(for item: MindfulnessHomeItem, unavailable: Bool) -> some View {
        if let scene = item.scene, let progress = player.downloadProgress[scene.id] {
            ZStack {
                Circle().stroke(.white.opacity(0.30), lineWidth: 3)
                Circle().trim(from: 0, to: progress).stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 34, height: 34).padding(5).background(.black.opacity(0.36)).clipShape(Circle())
        } else {
            let icon: String = {
                if unavailable { return "clock" }
                guard let scene = item.scene else { return "play.fill" }
                if player.currentScene?.id == scene.id { return player.isPlaying ? "pause.fill" : "play.fill" }
                return player.cachedAudioExists(for: scene) ? "play.fill" : "arrow.down"
            }()
            Image(systemName: icon)
                .font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(.black.opacity(0.30)).clipShape(Circle())
        }
    }

    private func sceneTrack(_ scene: SoundScene) -> MindfulnessTrack {
        let colors = natureColors(for: scene.index)
        return MindfulnessTrack(id: "nature-\(scene.id)", title: scene.title, subtitle: scene.subtitle, resourceName: (scene.audioFile as NSString).deletingPathExtension, resourceExtension: (scene.audioFile as NSString).pathExtension, subdirectory: scene.audioSubdirectory, colors: [colors[0].opacity(0.82), colors[1].opacity(0.75), colors[0].opacity(0.62)], accent: colors[1], icon: "leaf.fill")
    }

    private func natureTrack(for scene: SoundScene) -> MindfulnessTrack {
        var track = sceneTrack(scene)
        track.fileURL = player.localAudioURL(for: scene)
        return track
    }

    private func natureColors(for index: Int) -> [Color] {
        let palettes: [[Color]] = [[.teal, .cyan], [.blue, .indigo], [.green, .mint], [.orange, .pink], [.purple, .blue]]
        return palettes[max(index, 0) % palettes.count]
    }

    private func mindfulnessImage(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "SoundResources/Mindfulness/Covers"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct MindfulnessFlowVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct MindfulnessHomeItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    var imageName: String?
    var track: MindfulnessTrack?
    var scene: SoundScene?
}

private struct MindfulnessBanner {
    let eyebrow: String
    let title: String
    let detail: String
    let icon: String
    let colors: [Color]
}
