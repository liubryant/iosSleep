import SwiftUI
import Charts

struct SleepReportView: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("睡眠报告")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                metric(title: "时长", value: durationText)
                metric(title: "平均噪音", value: "\(Int(session.averageNoise)) dB")
                metric(title: "峰值", value: "\(Int(session.maxNoise)) dB")
            }

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
}
