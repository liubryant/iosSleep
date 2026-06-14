import AVFoundation
import SwiftUI
import Charts

struct SleepReportView: View {
    let session: SleepSession
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingRecording = false
    @State private var hasUnlockedRecordingPlayback = false
    @State private var isLoadingRewardAd = false
    @State private var showRewardFailedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("睡眠报告")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(session.sleepScore)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("分")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                metric(title: "时长", value: durationText)
                metric(title: "平均噪音", value: "\(Int(session.averageNoise)) dB")
                metric(title: "峰值", value: "\(Int(session.maxNoise)) dB")
            }

            HStack(spacing: 12) {
                metric(title: "睡眠效率", value: "\(Int(session.sleepEfficiency.rounded()))%")
                metric(title: "睡眠年龄", value: "\(session.sleepAge) 岁")
                metric(title: "深睡时长", value: stageDurationText(.deep))
            }

            recordingControl
            eventSummary

            if !session.events.isEmpty {
                eventChart
            }

            if !session.noiseSamples.isEmpty {
                noiseChart
            }

            sleepDistributionSection

            VStack(alignment: .leading, spacing: 10) {
                Text("事件列表")
                    .font(.headline)
                ForEach(session.events.suffix(20).reversed()) { event in
                    HStack {
                        Image(systemName: event.type.symbolName)
                            .foregroundStyle(.indigo)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text(event.type.title)
                                .font(.subheadline.weight(.medium))
                            Text(event.startTime, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(event.confidence * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onDisappear {
            stopRecordingPlayback()
        }
    }

    private var recordingControl: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 6) {
                    Text("睡眠录音")
                        .font(.headline.weight(.semibold))
                    Text(recordingAvailabilityText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    requestRecordingPlayback()
                } label: {
                    if isLoadingRewardAd {
                        ProgressView()
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: isPlayingRecording ? "stop.fill" : "play.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordingURL == nil || isLoadingRewardAd)
            }

            if isPlayingRecording {
                RecordingWaveformView()
                    .frame(height: 38)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert("暂时无法播放录音", isPresented: $showRewardFailedAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("需要先完成激励视频或点击跳过，之后才能播放睡眠录音。")
        }
    }

    private var eventChart: some View {
        Chart(session.events) { event in
            PointMark(
                x: .value("时间", event.startTime),
                y: .value("类型", event.type.title)
            )
            .foregroundStyle(by: .value("事件", event.type.title))
        }
        .frame(height: 180)
        .chartLegend(position: .bottom)
    }

    private var eventSummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(SleepEventType.allCases) { type in
                eventMetric(type: type)
            }
        }
    }

    private func eventMetric(type: SleepEventType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: type.symbolName)
                .foregroundStyle(.indigo)
            Text("\(session.eventCount(for: type))")
                .font(.title3.weight(.semibold))
            Text(type.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var noiseChart: some View {
        Chart(session.noiseSamples) { sample in
            LineMark(
                x: .value("时间", sample.time),
                y: .value("分贝", sample.decibel)
            )
            .foregroundStyle(.indigo)
            AreaMark(
                x: .value("时间", sample.time),
                y: .value("分贝", sample.decibel)
            )
            .foregroundStyle(.indigo.opacity(0.12))
        }
        .frame(height: 160)
    }

    private var distribution: SleepDistribution {
        session.sleepDistribution
    }

    private var sleepDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("睡眠分布")
                .font(.headline)

            if distribution.totalDuration <= 0 {
                Text("暂无足够数据生成睡眠分布。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    SleepDistributionPieChart(distribution: distribution)
                        .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(SleepStage.allCases) { stage in
                            stageLegendRow(stage)
                        }
                    }
                }

                Text(distributionAnalysisText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stageLegendRow(_ stage: SleepStage) -> some View {
        let minutes = Int(distribution.duration(for: stage) / 60)
        let percent = Int(distribution.percentage(for: stage).rounded())
        return HStack(spacing: 8) {
            Circle()
                .fill(stage.color)
                .frame(width: 10, height: 10)
            Text(stage.title)
                .font(.subheadline)
            Spacer()
            Text("\(minutes) 分钟")
                .font(.subheadline.weight(.medium))
            Text("\(percent)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stageDurationText(_ stage: SleepStage) -> String {
        let minutes = Int(distribution.duration(for: stage) / 60)
        return minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时 \(minutes % 60) 分"
    }

    private var distributionAnalysisText: String {
        var lines: [String] = []

        if let fallAsleep = distribution.fallAsleepTime, let wake = distribution.wakeTime {
            lines.append("您在 \(Self.timeFormatter.string(from: fallAsleep)) 开始入睡，\(Self.timeFormatter.string(from: wake)) 结束睡眠。")
        }

        let deepMinutes = Int(distribution.duration(for: .deep) / 60)
        let deepNote = deepMinutes >= 90 ? "已达到健康参考值" : "低于参考值 90 分钟"
        lines.append("深度睡眠 \(deepMinutes) 分钟（参考值 >90 分钟，\(deepNote)）。")

        let lightMinutes = Int(distribution.duration(for: .light) / 60)
        lines.append("浅睡眠 \(lightMinutes) 分钟。")

        let remMinutes = Int(distribution.duration(for: .rem) / 60)
        lines.append("做梦 \(remMinutes) 分钟。")

        let awakeMinutes = Int(distribution.duration(for: .awake) / 60)
        if awakeMinutes > 0 {
            lines.append("睡眠中觉醒约 \(awakeMinutes) 分钟。")
        }

        return lines.joined(separator: "\n")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func metric(title: String, value: String) -> some View {
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

    private var durationText: String {
        let minutes = Int(session.duration / 60)
        return minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时 \(minutes % 60) 分"
    }

    private var recordingURL: URL? {
        guard let fileName = session.audioFileName else { return nil }
        let url = SleepSessionStore.recordingURL(fileName: fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var recordingAvailabilityText: String {
        if recordingURL == nil { return "暂无可播放录音" }
        return hasUnlockedRecordingPlayback ? "已解锁，可回放夜间声音" : "观看激励视频后可播放，允许跳过"
    }

    private func requestRecordingPlayback() {
        if isPlayingRecording {
            stopRecordingPlayback()
            return
        }

        guard recordingURL != nil else { return }
        guard !hasUnlockedRecordingPlayback else {
            toggleRecordingPlayback()
            return
        }

        isLoadingRewardAd = true
        PangleRewardedVideoAdManager.shared.showForRecordingAccess { granted in
            Task { @MainActor in
                isLoadingRewardAd = false
                if granted {
                    hasUnlockedRecordingPlayback = true
                    toggleRecordingPlayback()
                } else {
                    showRewardFailedAlert = true
                }
            }
        }
    }

    private func toggleRecordingPlayback() {
        if isPlayingRecording {
            stopRecordingPlayback()
            return
        }

        guard let recordingURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlayingRecording = true
        } catch {
            print("Failed to play sleep recording: \(error)")
            stopRecordingPlayback()
        }
    }

    private func stopRecordingPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingRecording = false
    }

    private var scoreColor: Color {
        if session.sleepScore >= 85 { return .green }
        if session.sleepScore >= 70 { return .indigo }
        if session.sleepScore >= 55 { return .orange }
        return .red
    }
}

private struct RecordingWaveformView: View {
    private let barCount = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.indigo.opacity(0.72))
                        .frame(width: 4, height: barHeight(index: index, time: time))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("睡眠录音正在播放")
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = time * 5 + Double(index) * 0.55
        let value = (sin(phase) + 1) / 2
        return 8 + CGFloat(value) * 20
    }
}

private struct SleepDistributionPieChart: View {
    let distribution: SleepDistribution

    private var slices: [(stage: SleepStage, duration: TimeInterval)] {
        SleepStage.allCases.compactMap { stage in
            let duration = distribution.duration(for: stage)
            guard duration > 0 else { return nil }
            return (stage, duration)
        }
    }

    var body: some View {
        let total = slices.map(\.duration).reduce(0, +)
        ZStack {
            if total > 0 {
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    PieSliceShape(startAngle: angle(upTo: index, total: total), endAngle: angle(upTo: index + 1, total: total))
                        .fill(slice.stage.color)
                }
            }
            GeometryReader { proxy in
                Circle()
                    .fill(Color(.tertiarySystemBackground))
                    .padding(min(proxy.size.width, proxy.size.height) * 0.22)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func angle(upTo index: Int, total: Double) -> Angle {
        guard total > 0 else { return .degrees(-90) }
        let cumulative = slices.prefix(index).map(\.duration).reduce(0, +)
        return .degrees(cumulative / total * 360 - 90)
    }
}

extension SleepStage {
    var color: Color {
        switch self {
        case .deep: return .indigo
        case .light: return .cyan
        case .rem: return .purple
        case .awake: return .orange
        }
    }
}

private struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
