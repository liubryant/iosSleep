import SwiftUI
import Charts

struct SleepHomeView: View {
    @EnvironmentObject private var monitor: SleepMonitorService
    @EnvironmentObject private var healthKit: HealthKitService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusPanel
                    eventSummary

                    if let session = monitor.latestSession {
                        SleepReportView(session: session)
                    } else {
                        ContentUnavailableView("还没有睡眠报告", systemImage: "moon.zzz", description: Text("点击开始睡眠后，应用会记录夜间声音事件。"))
                            .padding(.vertical, 32)
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
}
