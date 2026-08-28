import Foundation
import SwiftUI
import UIKit

struct MindfulnessHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SoundLibrary
    @EnvironmentObject private var player: AudioPlayerService
    @EnvironmentObject private var storyPlayer: StoryPlayerService
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var membership = SleepMembershipSession.shared
    @StateObject private var remoteMindfulness = RemoteMindfulnessLibrary()
    @State private var selectedBanner = 0
    @State private var pendingNatureSceneID: String?
    @State private var selectedNatureScene: SoundScene?
    @State private var pendingRemoteMindfulnessID: Int?
    @State private var selectedRemoteTrack: MindfulnessTrack?
    @State private var remoteMessage: String?
    @State private var presenterIsMoving = false
    @State private var vipPromptTitle = ""
    @State private var vipPromptKind: SleepVIPContentKind = .mindfulness
    @State private var showVIPPrompt = false
    @State private var showMembershipAfterPrompt = false
    @State private var showMembership = false

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

    private var allMeditationItems: [MindfulnessHomeItem] {
        meditationItems + remoteMindfulness.items.map { item in
            MindfulnessHomeItem(
                title: item.title,
                subtitle: "云端正念 · 下载后离线播放",
                icon: "moon.stars.fill",
                colors: remoteColors(for: item.id),
                imageName: "\(Int(item.id.magnitude % 8) + 1)",
                remoteMindfulness: item
            )
        }
    }

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
                    contentSection(
                        title: "正念冥想",
                        subtitle: "跟随声音，把注意力带回当下",
                        items: allMeditationItems,
                        restrictAfterFirstFour: true,
                        showsVoiceCharactersEntry: true,
                        usesHomeCardRatio: true
                    )
                        .padding(.top, -10)
                    contentSection(title: "大自然中入眠", subtitle: "枕着山海风雨，慢慢沉入梦乡", items: natureItems)
                }
                .padding(.bottom, 34)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .appEdgeSwipeBack()
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
        .navigationDestination(isPresented: Binding(
            get: { selectedRemoteTrack != nil },
            set: { if !$0 { selectedRemoteTrack = nil } }
        )) {
            if let track = selectedRemoteTrack {
                MindfulnessPlayerView(track: track)
            }
        }
        .task {
            await remoteMindfulness.load()
        }
        .onReceive(bannerTimer) { _ in
            selectedBanner = (selectedBanner + 1) % banners.count
        }
        .onAppear {
            presenterIsMoving = true
        }
        .onChange(of: player.currentScene?.id) { sceneID in
            guard let sceneID, sceneID == pendingNatureSceneID,
                  let scene = natureItems.compactMap(\.scene).first(where: { $0.id == sceneID }),
                  player.localAudioURL(for: scene) != nil else { return }
            pendingNatureSceneID = nil
            selectedNatureScene = scene
        }
        .alert("提示", isPresented: Binding(
            get: { remoteMessage != nil },
            set: { if !$0 { remoteMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { remoteMessage = nil }
        } message: {
            Text(remoteMessage ?? "")
        }
        .sheet(isPresented: $showVIPPrompt, onDismiss: {
            guard showMembershipAfterPrompt else { return }
            showMembershipAfterPrompt = false
            showMembership = true
        }) {
            SleepVIPUpgradeSheet(
                contentTitle: vipPromptTitle,
                contentKind: vipPromptKind,
                onUpgrade: {
                    showMembershipAfterPrompt = true
                    showVIPPrompt = false
                },
                onCancel: { showVIPPrompt = false }
            )
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showMembership) {
            NavigationStack { SleepMembershipView() }
                .environmentObject(settings)
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
            .overlay(alignment: .bottomTrailing) {
                presenterOverlay
                    .offset(x: 3, y: 0)
                    .zIndex(2)
            }

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
        // 缩短卡片与顶部栏距离，同时为高出卡片的人物保留悬浮空间。
        .padding(.horizontal, 10).padding(.top, 38)
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
            .padding(.top, 46)
            .padding(.leading, 26)
            .padding(.trailing, 150)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .mask(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .compositingGroup()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var presenterOverlay: some View {
        Image("MindfulnessPresenter")
            .resizable()
            .scaledToFit()
            .frame(width: 136, height: 205, alignment: .bottom)
            .scaleEffect(presenterIsMoving ? 1.015 : 0.985, anchor: .bottom)
            .offset(
                x: presenterIsMoving ? -2 : 2,
                y: 0
            )
            .animation(
                .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
                value: presenterIsMoving
            )
            .padding(.trailing, 4)
            .allowsHitTesting(false)
    }

    private func contentSection(
        title: String,
        subtitle: String,
        items: [MindfulnessHomeItem],
        restrictAfterFirstFour: Bool = false,
        showsVoiceCharactersEntry: Bool = false,
        usesHomeCardRatio: Bool = false
    ) -> some View {
        let rowHeight: CGFloat = usesHomeCardRatio ? 229 : 183

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                if showsVoiceCharactersEntry {
                    NavigationLink {
                        VoiceCharactersView()
                    } label: {
                        Label("认识声音人物", systemImage: "person.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.37, green: 0.31, blue: 0.53))
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(.white.opacity(0.86))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(rowHeight), spacing: 12), GridItem(.fixed(rowHeight), spacing: 12)], spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let isVIPContent = (restrictAfterFirstFour && index >= 4)
                            || (item.scene?.requiresVIP == true)
                        destination(
                            for: item,
                            isVIPContent: isVIPContent,
                            usesHomeCardRatio: usesHomeCardRatio
                        )
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 2)
            }
            .frame(height: rowHeight * 2 + 12)
        }
    }

    @ViewBuilder
    private func destination(
        for item: MindfulnessHomeItem,
        isVIPContent: Bool,
        usesHomeCardRatio: Bool
    ) -> some View {
        if isVIPContent && !membership.isVIPActive {
            Button {
                vipPromptTitle = item.title
                vipPromptKind = item.scene == nil ? .mindfulness : .sound
                showVIPPrompt = true
            } label: {
                card(item, isVIPContent: true, usesHomeCardRatio: usesHomeCardRatio)
            }
            .buttonStyle(.plain)
        } else if let track = item.track {
            NavigationLink { MindfulnessPlayerView(track: track) } label: {
                card(item, isVIPContent: isVIPContent, usesHomeCardRatio: usesHomeCardRatio)
            }
            .buttonStyle(.plain)
        } else if let remoteItem = item.remoteMindfulness {
            Button {
                openRemoteMindfulness(remoteItem)
            } label: {
                card(item, isVIPContent: isVIPContent, usesHomeCardRatio: usesHomeCardRatio)
            }
            .buttonStyle(.plain)
        } else if let scene = item.scene {
            Button {
                if storyPlayer.currentStory != nil { storyPlayer.stop() }
                if player.localAudioURL(for: scene) != nil {
                    selectedNatureScene = scene
                } else {
                    pendingNatureSceneID = scene.id
                    player.toggle(scene: scene)
                }
            } label: {
                card(item, isVIPContent: isVIPContent, usesHomeCardRatio: usesHomeCardRatio)
            }
            .buttonStyle(.plain)
        } else {
            Button {} label: {
                card(
                    item,
                    unavailable: true,
                    isVIPContent: isVIPContent,
                    usesHomeCardRatio: usesHomeCardRatio
                )
            }
                .buttonStyle(.plain)
                .disabled(true)
        }
    }

    private func card(
        _ item: MindfulnessHomeItem,
        unavailable: Bool = false,
        isVIPContent: Bool = false,
        usesHomeCardRatio: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let scene = item.scene {
                    CoverImage(scene: scene)
                    LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
                } else if let imageName = item.imageName, let image = mindfulnessImage(named: imageName) {
                    Image(uiImage: image).resizable().scaledToFill()
                    LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.white.opacity(0.13)).frame(width: 90).offset(x: 52, y: -34)
                    Image(systemName: item.icon).font(.system(size: 32, weight: .light)).foregroundStyle(.white)
                }
            }
            .frame(width: 138, height: usesHomeCardRatio ? 184 : 138)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                cardStatus(for: item, unavailable: unavailable).padding(7)
            }
            .overlay(alignment: .topTrailing) {
                if isVIPContent {
                    Label("VIP", systemImage: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(height: 21)
                        .background(.ultraThinMaterial.opacity(0.88))
                        .background(Color.black.opacity(0.16))
                        .clipShape(Capsule())
                        .padding(7)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(unavailable ? "音频即将上线" : item.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }.frame(width: 138, alignment: .leading)
        }
    }

    @ViewBuilder
    private func cardStatus(for item: MindfulnessHomeItem, unavailable: Bool) -> some View {
        if let remoteItem = item.remoteMindfulness,
           let progress = remoteMindfulness.downloadProgress[remoteItem.id] {
            downloadProgressBadge(progress)
        } else if let scene = item.scene, let progress = player.downloadProgress[scene.id] {
            downloadProgressBadge(progress)
        } else {
            let icon: String = {
                if unavailable { return "clock" }
                if let remoteItem = item.remoteMindfulness {
                    return remoteMindfulness.cachedAudioExists(for: remoteItem) ? "play.fill" : "arrow.down"
                }
                guard let scene = item.scene else { return "play.fill" }
                if player.currentScene?.id == scene.id { return player.isPlaying ? "pause.fill" : "play.fill" }
                return player.cachedAudioExists(for: scene) ? "play.fill" : "arrow.down"
            }()
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                .frame(width: 23, height: 23).background(.black.opacity(0.30)).clipShape(Circle())
        }
    }

    private func downloadProgressBadge(_ progress: Double) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.30), lineWidth: 2)
            Circle().trim(from: 0, to: progress).stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))").font(.system(size: 6, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: 26, height: 26).padding(4).background(.black.opacity(0.36)).clipShape(Circle())
    }

    private func openRemoteMindfulness(_ item: RemoteMindfulnessItem) {
        if let activeID = pendingRemoteMindfulnessID {
            if activeID != item.id {
                remoteMessage = "当前正念音频正在下载，请稍候"
            }
            return
        }

        if let localURL = remoteMindfulness.localAudioURL(for: item) {
            openRemotePlayer(item, localURL: localURL)
            return
        }

        pendingRemoteMindfulnessID = item.id
        Task {
            do {
                let localURL = try await remoteMindfulness.download(item)
                guard pendingRemoteMindfulnessID == item.id else { return }
                pendingRemoteMindfulnessID = nil
                openRemotePlayer(item, localURL: localURL)
            } catch is CancellationError {
                pendingRemoteMindfulnessID = nil
            } catch {
                pendingRemoteMindfulnessID = nil
                remoteMessage = "正念音频下载失败，请检查网络后重试"
            }
        }
    }

    private func openRemotePlayer(_ item: RemoteMindfulnessItem, localURL: URL) {
        selectedNatureScene = nil
        selectedRemoteTrack = remoteTrack(for: item, localURL: localURL)
    }

    private func remoteTrack(for item: RemoteMindfulnessItem, localURL: URL) -> MindfulnessTrack {
        let colors = remoteColors(for: item.id)
        return MindfulnessTrack(
            id: "remote-\(item.id)",
            title: item.title,
            subtitle: "云端正念 · 离线播放",
            resourceName: "remote-\(item.id)",
            resourceExtension: item.fileExtension,
            subdirectory: "",
            colors: [colors[0].opacity(0.82), colors[1].opacity(0.75), colors[0].opacity(0.62)],
            accent: colors[1],
            icon: "moon.stars.fill",
            fileURL: localURL
        )
    }

    private func remoteColors(for id: Int) -> [Color] {
        let palettes: [[Color]] = [[.indigo, .blue], [.teal, .cyan], [.green, .mint], [.purple, .pink], [.orange, .yellow]]
        return palettes[Int(id.magnitude % UInt(palettes.count))]
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
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    var imageName: String?
    var track: MindfulnessTrack?
    var scene: SoundScene?
    var remoteMindfulness: RemoteMindfulnessItem?

    init(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        imageName: String? = nil,
        track: MindfulnessTrack? = nil,
        scene: SoundScene? = nil,
        remoteMindfulness: RemoteMindfulnessItem? = nil
    ) {
        if let track {
            id = "track-\(track.id)"
        } else if let scene {
            id = "scene-\(scene.id)"
        } else if let remoteMindfulness {
            id = "remote-\(remoteMindfulness.id)"
        } else {
            id = "item-\(title)"
        }
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colors = colors
        self.imageName = imageName
        self.track = track
        self.scene = scene
        self.remoteMindfulness = remoteMindfulness
    }
}

private struct RemoteMindfulnessItem: Decodable, Identifiable {
    let id: Int
    let title: String
    let contentType: String?
    let sizeBytes: Int64?
    let sortOrder: Int?
    let downloadUrl: String

    var fileExtension: String {
        let normalized = contentType?.lowercased() ?? ""
        if normalized.contains("mp4") { return "m4a" }
        if normalized.contains("aac") { return "aac" }
        if normalized.contains("wav") { return "wav" }
        if normalized.contains("ogg") { return "ogg" }
        return "mp3"
    }
}

@MainActor
private final class RemoteMindfulnessLibrary: ObservableObject {
    @Published private(set) var items: [RemoteMindfulnessItem] = []
    @Published private(set) var downloadProgress: [Int: Double] = [:]

    private static let serverBaseURL = URL(string: "https://www.cjym123.cn")!
    private var didLoad = false

    func load() async {
        guard !didLoad else { return }
        didLoad = true

        do {
            var request = URLRequest(
                url: Self.serverBaseURL.appendingPathComponent("api/mindfulness"),
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            request.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }

            items = try JSONDecoder().decode([RemoteMindfulnessItem].self, from: data)
                .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.downloadUrl.isEmpty }
        } catch {
            items = []
            print("Failed to load remote mindfulness list: \(error)")
        }
    }

    func cachedAudioExists(for item: RemoteMindfulnessItem) -> Bool {
        FileManager.default.fileExists(atPath: cachedAudioURL(for: item).path)
    }

    func localAudioURL(for item: RemoteMindfulnessItem) -> URL? {
        let url = cachedAudioURL(for: item)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func download(_ item: RemoteMindfulnessItem) async throws -> URL {
        if let localURL = localAudioURL(for: item) { return localURL }

        guard let downloadURL = resolvedDownloadURL(for: item) else {
            throw URLError(.badURL)
        }

        let destinationURL = cachedAudioURL(for: item)
        let expectedLength = max(item.sizeBytes ?? 0, 0)
        downloadProgress[item.id] = 0
        defer { downloadProgress[item.id] = nil }

        return try await Self.streamDownload(
            from: downloadURL,
            to: destinationURL,
            expectedLengthFallback: expectedLength
        ) { [weak self] progress in
            await self?.recordDownloadProgress(progress, for: item.id)
        }
    }

    private func recordDownloadProgress(_ progress: Double, for id: Int) {
        downloadProgress[id] = min(max(progress, 0), 1)
    }

    private func cachedAudioURL(for item: RemoteMindfulnessItem) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mindfulness", isDirectory: true)
            .appendingPathComponent("remote-\(item.id).\(item.fileExtension)")
    }

    private func resolvedDownloadURL(for item: RemoteMindfulnessItem) -> URL? {
        if let absoluteURL = URL(string: item.downloadUrl), absoluteURL.scheme != nil {
            return absoluteURL
        }
        return URL(string: item.downloadUrl, relativeTo: Self.serverBaseURL)?.absoluteURL
    }

    nonisolated private static func streamDownload(
        from url: URL,
        to destinationURL: URL,
        expectedLengthFallback: Int64,
        onProgress: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        let directoryURL = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 120
        )
        request.httpMethod = "GET"
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let expectedLength = max(response.expectedContentLength, expectedLengthFallback)
        let temporaryURL = destinationURL.appendingPathExtension("download")
        try? FileManager.default.removeItem(at: temporaryURL)
        guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var receivedLength: Int64 = 0
        var lastReportedProgress = -1.0
        var buffer = Data()
        buffer.reserveCapacity(32 * 1024)

        do {
            let fileHandle = try FileHandle(forWritingTo: temporaryURL)
            defer { try? fileHandle.close() }

            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= 32 * 1024 {
                    fileHandle.write(buffer)
                    receivedLength += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    let progress = downloadProgress(receivedLength: receivedLength, expectedLength: expectedLength)
                    if progress - lastReportedProgress >= 0.01 {
                        lastReportedProgress = progress
                        await onProgress(progress)
                    }
                }
            }

            if !buffer.isEmpty {
                fileHandle.write(buffer)
                receivedLength += Int64(buffer.count)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }

        guard receivedLength > 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw URLError(.zeroByteResource)
        }

        await onProgress(1)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    nonisolated private static func downloadProgress(receivedLength: Int64, expectedLength: Int64) -> Double {
        if expectedLength > 0 {
            return min(Double(receivedLength) / Double(expectedLength), 0.99)
        }
        let received = Double(receivedLength)
        return min(0.9, 0.08 + received / (received + 1024 * 1024))
    }
}

private struct MindfulnessBanner {
    let eyebrow: String
    let title: String
    let detail: String
    let icon: String
    let colors: [Color]
}
