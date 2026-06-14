import SwiftUI
import Charts

struct SleepHomeView: View {
    @EnvironmentObject private var monitor: SleepMonitorService
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var trendRange: SleepTrendRange = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusPanel
                    eventSummary
                    trendPanel

                    if let session = monitor.latestSession {
                        SleepReportView(session: session)
                    } else {
                        EmptyStateView(title: "还没有睡眠报告", systemImage: "moon.zzz", message: "点击开始睡眠后，应用会记录夜间声音事件。")
                            .padding(.vertical, 32)
                    }

                    if !monitor.sessions.isEmpty {
                        recentReports
                    }
                }
                .padding()
            }
            .navigationTitle("睡眠")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await healthKit.requestAuthorization() }
                    } label: {
                        Image(systemName: healthKit.isAuthorized ? "heart.fill" : "heart")
                    }
                }
            }
            .alert("需要麦克风权限", isPresented: Binding(
                get: { monitor.permissionDenied },
                set: { _ in monitor.dismissPermissionAlert() }
            )) {
                Button("知道了", role: .cancel) {
                    monitor.dismissPermissionAlert()
                }
            } message: {
                Text("请在系统设置中允许麦克风访问，才能进行睡眠声音监测。")
            }
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(monitor.isMonitoring ? "正在监测" : "今晚睡眠")
                        .font(.title2.weight(.semibold))
                    Text(monitor.isMonitoring ? "环境音量 \(Int(monitor.currentDecibel)) dB" : "开始后会在本地识别打鼾、咳嗽、梦话、磨牙和噪音")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: monitor.isMonitoring ? "record.circle.fill" : "moon.stars.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(monitor.isMonitoring ? .red : .indigo)
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
                Label(monitor.isMonitoring ? "结束睡眠" : "开始睡眠", systemImage: monitor.isMonitoring ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var eventSummary: some View {
        let session = monitor.latestSession
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
            ForEach(SleepEventType.allCases) { type in
                VStack(spacing: 8) {
                    Image(systemName: type.symbolName)
                        .font(.title3)
                        .foregroundStyle(.indigo)
                    Text("\(session?.events.filter { $0.type == type }.count ?? 0)")
                        .font(.title2.weight(.semibold))
                    Text(type.title)
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
                Text("睡眠趋势")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("范围", selection: $trendRange) {
                    ForEach(SleepTrendRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 116)
            }

            if monitor.sessions.isEmpty {
                EmptyStateView(title: "暂无趋势", systemImage: "chart.line.uptrend.xyaxis", message: "完成一次睡眠监测后，这里会显示周/月趋势。")
                    .padding(.vertical, 8)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("睡眠时长", point.durationHours)
                    )
                    .foregroundStyle(.indigo.opacity(0.35))

                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("评分", point.score / 12)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 180)
                .chartYAxisLabel("小时 / 评分")

                HStack(spacing: 12) {
                    trendMetric(title: "平均评分", value: averageScoreText(points))
                    trendMetric(title: "打鼾", value: "\(points.map(\.snoreCount).reduce(0, +)) 次")
                    trendMetric(title: "磨牙", value: "\(points.map(\.bruxismCount).reduce(0, +)) 次")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func trendMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
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
        return "\(Int(average.rounded())) 分"
    }

    private var recentReports: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史报告")
                .font(.title3.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(monitor.sessions.prefix(10)) { session in
                    Button {
                        monitor.select(session: session)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.indigo)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.medium))
                                Text("\(durationText(for: session)) · \(session.events.count) 个事件 · 平均 \(Int(session.averageNoise)) dB")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if monitor.latestSession?.id == session.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
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
        return minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时 \(minutes % 60) 分"
    }
}
