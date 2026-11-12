import SwiftUI
import UIKit

struct DailyInspirationCard: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let entry = DailyInspiration(day: DailyInspiration.day(for: context.date))
            NavigationLink {
                DailyInspirationView(entry: entry)
            } label: {
                VStack(alignment: .leading, spacing: 15) {
                    Label("今日灵感", systemImage: "sparkle")
                        .font(.subheadline.weight(.semibold))

                    Text(entry.text)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .lineSpacing(5)
                        .frame(maxWidth: 480, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(entry.date.formatted(.dateTime.month().day().locale(DailyInspiration.displayLocale)))  ·  \(entry.theme.rawValue)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.74))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    InspirationScenery(theme: entry.theme, composition: .card)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .contentShape(RoundedRectangle(cornerRadius: 24))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct DailyInspirationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var membership = SleepMembershipSession.shared
    @State private var vipPrompt: SleepVIPPromptContent?
    @AppStorage("dailyInspiration.favoriteDays") private var savedDays = ""
    @State private var day: Int
    @State private var showArchive = false
    @State private var shareImage: InspirationShareImage?
    @State private var showShareError = false

    init(entry: DailyInspiration) {
        _day = State(initialValue: entry.day)
    }

    private var entry: DailyInspiration { DailyInspiration(day: day) }
    private var favorites: Set<Int> { Set(savedDays.split(separator: ",").compactMap { Int($0) }) }
    private var isFavorite: Bool { favorites.contains(day) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer(minLength: min(geometry.size.height * 0.20, 160))
                    InspirationQuote(entry: entry)
                    HStack(spacing: 12) {
                        Button(action: toggleFavorite) {
                            Label(isFavorite ? "已收藏" : "收藏", systemImage: isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(isFavorite ? Color(red: 1, green: 0.78, blue: 0.73) : .white)
                                .modifier(InspirationCapsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isFavorite ? .isSelected : [])
                    }

                    if let practice = entry.practice {
                        if practice.requiresVIP && !membership.isVIPActive {
                            Button { vipPrompt = SleepVIPPromptContent(title: practice.title, kind: .mindfulness) } label: {
                                Label("听一段练习 · \(practice.title)", systemImage: "play.circle")
                                    .modifier(InspirationCapsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                MindfulnessPlayerView(track: practice)
                            } label: {
                                Label("听一段练习 · \(practice.title)", systemImage: "play.circle")
                                    .modifier(InspirationCapsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(minHeight: geometry.size.height, alignment: .bottomLeading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            InspirationScenery(theme: entry.theme, composition: .portrait)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                iconButton("返回", icon: "chevron.left") { dismiss() }
                Spacer()
                iconButton("日历与收藏", icon: "calendar") { showArchive = true }
                iconButton("分享图片", icon: "square.and.arrow.up", action: share)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
            .overlay {
                Text("今日灵感")
                    .font(.headline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .allowsHitTesting(false)
            }
            .background(Color(white: 0.25).opacity(0.48))
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .appEdgeSwipeBack()
        .preference(key: MindfulnessFlowVisibilityPreferenceKey.self, value: true)
        .modifier(MindfulnessVIPPrompt(prompt: $vipPrompt))
        .sheet(isPresented: $showArchive) {
            InspirationArchive(day: day, favorites: favorites) { day = $0 }
        }
        .sheet(item: $shareImage) { image in
            InspirationShareSheet(image: image.image)
                .presentationDetents([.medium, .large])
        }
        .alert("暂时无法生成分享图片", isPresented: $showShareError) {
            Button("好", role: .cancel) {}
        }
    }

    private func iconButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.13), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func toggleFavorite() {
        var updated = favorites
        if updated.remove(day) == nil { updated.insert(day) }
        savedDays = updated.sorted().map(String.init).joined(separator: ",")
    }

    @MainActor
    private func share() {
        let renderer = ImageRenderer(content:
            VStack {
                HStack {
                    Label("今日灵感", systemImage: "sparkle")
                    Spacer()
                    Text("DAILY NOTES")
                        .font(.caption.monospaced())
                        .tracking(3)
                }
                .font(.headline)
                Spacer()
                InspirationQuote(entry: entry)
            }
            .padding(32)
            .frame(width: 360, height: 540)
            .foregroundStyle(.white)
            .background {
                InspirationScenery(theme: entry.theme, composition: .portrait)
            }
            .environment(\.dynamicTypeSize, .medium)
        )
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareImage = InspirationShareImage(image: image)
        } else {
            showShareError = true
        }
    }
}

private struct InspirationQuote: View {
    let entry: DailyInspiration

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Text(entry.date.formatted(.dateTime.day().locale(Locale(identifier: "en_US_POSIX"))))
                    .font(.system(size: 60, weight: .ultraLight, design: .serif))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.date.formatted(.dateTime.year().month().day().locale(DailyInspiration.displayLocale)))
                        .font(.caption.monospacedDigit())
                    Text(entry.theme.rawValue)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.86))
            }

            Capsule()
                .fill(Color(red: 0.91, green: 0.76, blue: 0.56))
                .frame(width: 26, height: 2)
                .accessibilityHidden(true)

            Text(entry.text)
                .font(.system(.title, design: .serif).weight(.medium))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("—  时光睡眠")
                .font(.footnote.weight(.medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.83))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspirationCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
    }
}

private struct InspirationScenery: View {
    enum Composition {
        case card, portrait
    }

    let theme: DailyInspiration.Theme
    let composition: Composition


    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.10, green: 0.19, blue: 0.31)
                if let image = MindfulnessCover.image(at: theme.coverIndex) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .saturation(0.64)
                }
                if composition == .card {
                    LinearGradient(colors: [.black.opacity(0.82), .black.opacity(0.62), .black.opacity(0.20)],
                                   startPoint: .leading, endPoint: .trailing)
                } else {
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.48), location: 0),
                        .init(color: .black.opacity(0.13), location: 0.28),
                        .init(color: Color(red: 0.03, green: 0.08, blue: 0.16).opacity(0.88), location: 0.78),
                        .init(color: Color(red: 0.02, green: 0.05, blue: 0.11), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

private struct InspirationArchive: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Date
    @State private var showingFavorites = false
    let favorites: Set<Int>
    let onOpen: (Int) -> Void

    init(day: Int, favorites: Set<Int>, onOpen: @escaping (Int) -> Void) {
        _selection = State(initialValue: DailyInspiration(day: day).date)
        self.favorites = favorites
        self.onOpen = onOpen
    }

    private var today: Int { DailyInspiration.day(for: Date()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("查看", selection: $showingFavorites) {
                    Text("往期日历").tag(false)
                    Text("我的收藏").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if showingFavorites {
                    if favorites.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "heart")
                                .font(.title)
                            Text("收藏的灵感会留在这里")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                    } else {
                        List(favorites.sorted(by: >), id: \.self) { day in
                            let entry = DailyInspiration(day: day)
                            Button { open(day) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.date.formatted(.dateTime.year().month().day().locale(DailyInspiration.displayLocale)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(entry.text)
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            DatePicker("选择日期", selection: $selection,
                                       in: DailyInspiration.firstDate...DailyInspiration(day: today).date,
                                       displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .environment(\.calendar, DailyInspiration.calendar)
                                .environment(\.locale, DailyInspiration.displayLocale)
                            Button("查看这一天") { open(DailyInspiration.day(for: selection)) }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: 440)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 10)
            .navigationTitle("灵感手记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func open(_ day: Int) {
        onOpen(day)
        dismiss()
    }
}

private struct InspirationShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct InspirationShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
