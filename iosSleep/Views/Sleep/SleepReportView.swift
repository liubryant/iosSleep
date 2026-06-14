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

            recordingControl
            eventSummary

            if !session.events.isEmpty {
                eventChart
            }

            if !session.noiseSamples.isEmpty {
                noiseChart
            }

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
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.indigo)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("睡眠录音")
                    .font(.subheadline.weight(.medium))
                Text(recordingAvailabilityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                requestRecordingPlayback()
            } label: {
                if isLoadingRewardAd {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: isPlayingRecording ? "stop.fill" : "play.fill")
                        .frame(width: 34, height: 34)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(recordingURL == nil || isLoadingRewardAd)
        }
        .padding(10)
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
            eventMetric(type: .snore)
            eventMetric(type: .bruxism)
            eventMetric(type: .cough)
            eventMetric(type: .sleepTalk)
            eventMetric(type: .noise)
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
