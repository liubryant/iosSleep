import SwiftUI
import Charts

struct SleepHomeView: View {
    @EnvironmentObject private var monitor: SleepMonitorService
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var trendRange: SleepTrendRange = .week
    @SceneStorage("sleep.home.selectedPage") private var storedPageRawValue = SleepHomePage.start.rawValue

    private var selectedPage: SleepHomePage {
        SleepHomePage(rawValue: storedPageRawValue) ?? .start
    }

    private var selectedPageBinding: Binding<SleepHomePage> {
        Binding(
            get: { selectedPage },
            set: { storedPageRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sleepTopBar

                TabView(selection: selectedPageBinding) {
                    ScrollView {
                        VStack(spacing: 16) {
                            statusPanel
                                .padding(.horizontal, 4)
                            eventSummary
                            reportContent
                        }
                        .padding()
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                    .tag(SleepHomePage.start)

                    ScrollView {
                        VStack(spacing: 16) {
                            reportContent
                        }
                        .padding()
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                    .tag(SleepHomePage.report)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert(SleepL10n.text("需要麦克风权限"), isPresented: Binding(
                get: { monitor.permissionDenied },
                set: { _ in monitor.dismissPermissionAlert() }
            )) {
                Button(SleepL10n.text("知道了"), role: .cancel) {
                    monitor.dismissPermissionAlert()
                }
            } message: {
                Text(SleepL10n.text("请在系统设置中允许麦克风访问，才能进行睡眠声音监测。"))
            }
            .alert(SleepL10n.text("未生成睡眠报告"), isPresented: Binding(
                get: { monitor.reportTooShort },
                set: { _ in monitor.dismissReportTooShortAlert() }
            )) {
                Button(SleepL10n.text("知道了"), role: .cancel) {
                    monitor.dismissReportTooShortAlert()
                }
            } message: {
                Text(SleepL10n.text("本次睡眠时长不足 2 小时，不会生成睡眠报告。"))
            }
        }
    }

    private var sleepTopBar: some View {
        sleepPageTabs
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var sleepPageTabs: some View {
        HStack(spacing: 28) {
            ForEach(SleepHomePage.allCases) { page in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        storedPageRawValue = page.rawValue
                    }
                } label: {
                    VStack(spacing: 9) {
                        Text(verbatim: SleepL10n.text(page.title))
                            .font(selectedPage == page ? .title2 : .title3)
                            .fontWeight(selectedPage == page ? .semibold : .regular)
                            .foregroundStyle(selectedPage == page ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedPage == page ? Color.blue : Color.clear)
                            .frame(width: underlineWidth(for: page))
                            .frame(height: 3)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func underlineWidth(for page: SleepHomePage) -> CGFloat {
        switch page {
        case .start:
            return 44
        case .report:
            return 44
        }
    }

    private var reportContent: some View {
        Group {
            trendPanel

            if let session = monitor.latestSession {
                SleepReportView(session: session)
            } else {
                SleepReportView(session: .sample, isSample: true)
            }

            if !monitor.sessions.isEmpty {
                recentReports
            }
        }
    }

    private var statusPanel: some View {
        ZStack {
            HolidayCover()
                .scaledToFill()
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))

            LinearGradient(
                colors: [.black.opacity(0.14), .black.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SleepL10n.text(monitor.isMonitoring ? SleepL10n.text("正在监测") : SleepL10n.text("今晚睡眠")))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                        if monitor.isMonitoring, let startTime = monitor.currentSession?.startTime {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                Text(SleepL10n.text("已进行"))
                                Text(startTime, style: .timer)
                                    .monospacedDigit()
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.92))
                        }
                        Text(SleepL10n.text(monitor.isMonitoring ? SleepL10n.format("环境音量 {0} dB", [String(describing: Int(monitor.currentDecibel))]) : SleepL10n.text("开始后会在本地识别打鼾、咳嗽、梦话、磨牙和噪音")))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    Spacer()
                    Image(systemName: monitor.isMonitoring ? "record.circle.fill" : "moon.stars.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(monitor.isMonitoring ? .red : .white)
                }

                Button {
                    if monitor.isMonitoring {
                        monitor.stop()
                        if let session = monitor.latestSession {
                            Task { await healthKit.save(session: session) }
                        }
                    } else {
                        Task { await monitor.start() }
                    }
                } label: {
                    Label(monitor.isMonitoring ? SleepL10n.text("结束睡眠") : SleepL10n.text("开始睡眠"), systemImage: monitor.isMonitoring ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(white: 0.17))
                .foregroundStyle(.white)
                .controlSize(.regular)
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 6)
    }

    private var eventSummary: some View {
        let session = monitor.latestSession
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
            ForEach(SleepEventType.allCases) { type in
                VStack(spacing: 8) {
                    Image(systemName: type.symbolName)
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text(SleepL10n.text("\(session?.events.filter { $0.type == type }.count ?? 0)"))
                        .font(.title2.weight(.semibold))
                    Text(verbatim: SleepL10n.text(type.title))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var trendPanel: some View {
        let points = SleepTrendCalculator.points(from: monitor.sessions, range: trendRange)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(SleepL10n.text("睡眠趋势"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker(SleepL10n.text("范围"), selection: $trendRange) {
                    ForEach(SleepTrendRange.allCases) { range in
                        Text(verbatim: SleepL10n.text(range.title)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 116)
            }

            if monitor.sessions.isEmpty {
                EmptyStateView(title: SleepL10n.text("暂无趋势"), systemImage: "chart.line.uptrend.xyaxis", message: SleepL10n.text("完成一次睡眠监测后，这里会显示周/月趋势。"))
                    .padding(.vertical, 8)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value(SleepL10n.text("日期"), point.date, unit: .day),
                        y: .value(SleepL10n.text("睡眠时长"), point.durationHours)
                    )
                    .foregroundStyle(.blue.opacity(0.35))

                    LineMark(
                        x: .value(SleepL10n.text("日期"), point.date, unit: .day),
                        y: .value(SleepL10n.text("评分"), point.score / 12)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 180)
                .chartYAxisLabel(SleepL10n.text("小时 / 评分"))

                HStack(spacing: 12) {
                    trendMetric(title: SleepL10n.text("平均评分"), value: averageScoreText(points))
                    trendMetric(title: SleepL10n.text("打鼾"), value: SleepL10n.format("{0} 次", [String(describing: points.map(\.snoreCount).reduce(0, +))]))
                    trendMetric(title: SleepL10n.text("磨牙"), value: SleepL10n.format("{0} 次", [String(describing: points.map(\.bruxismCount).reduce(0, +))]))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func trendMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: SleepL10n.text(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: SleepL10n.text(value))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func averageScoreText(_ points: [SleepTrendPoint]) -> String {
        let scoredPoints = points.filter { $0.score > 0 }
        guard !scoredPoints.isEmpty else { return "--" }
        let average = scoredPoints.map(\.score).reduce(0, +) / Double(scoredPoints.count)
        return SleepL10n.format("{0} 分", [String(describing: Int(average.rounded()))])
    }

    private var recentReports: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(SleepL10n.text("历史报告"))
                .font(.title3.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(monitor.sessions.prefix(10)) { session in
                    Button {
                        monitor.select(session: session)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(SleepL10n.text(Self.reportDateFormatter.string(from: session.startTime)))
                                    .font(.subheadline.weight(.medium))
                                Text(SleepL10n.format("{0} · {1} 个事件 · 平均 {2} dB", [String(describing: durationText(for: session)), String(describing: session.events.count), String(describing: Int(session.averageNoise))]))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if monitor.latestSession?.id == session.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if session.id != monitor.sessions.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func durationText(for session: SleepSession) -> String {
        let minutes = Int(session.duration / 60)
        return minutes < 60 ? SleepL10n.format("{0} 分钟", [String(describing: minutes)]) : SleepL10n.format("{0} 小时 {1} 分", [String(describing: minutes / 60), String(describing: minutes % 60)])
    }

    private static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMdHHmm")
        return formatter
    }()
}

private enum SleepHomePage: String, CaseIterable, Identifiable {
    case start
    case report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: return "开始睡眠"
        case .report: return "睡眠报告"
        }
    }
}

private struct HolidayCover: View {
    var body: some View {
        if let url = Bundle.main.url(
            forResource: "cover",
            withExtension: "jpg",
            subdirectory: SleepL10n.text("SoundResources/011_春雨")
        ),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
        } else {
            LinearGradient(
                colors: [.blue.opacity(0.6), .cyan.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
