import AVFoundation
import Foundation
import TensorFlowLiteC

struct SoundClassification {
    let type: SleepEventType
    let confidence: Double
}

protocol SoundClassifying {
    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification?
}

final class HybridSleepSoundClassifier: SoundClassifying {
    private let yamNet = YAMNetSoundClassifier()
    private let fallback = FeatureBasedSleepSoundClassifier()

    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification? {
        if let result = yamNet.classify(buffer: buffer, features: features) {
            return result
        }
        return fallback.classify(buffer: buffer, features: features)
    }
}

struct FeatureBasedSleepSoundClassifier: SoundClassifying {
    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification? {
        guard features.estimatedDecibel > 36 else { return nil }

        if features.estimatedDecibel > 68 {
            return SoundClassification(type: .noise, confidence: 0.82)
        }

        let isLowFrequencyDominant = features.lowBandRatio > 0.5
        let isTonal = features.spectralFlatness < 0.3
        let isBroadband = features.spectralFlatness > 0.35

        // 放屁：低频为主、接近噪声的短促爆发音（峰值远高于均方根）。
        if isLowFrequencyDominant, isBroadband, features.peak > 0.1,
           features.peak > features.rms * 6, features.zeroCrossingRate < 0.045 {
            let confidence = min(0.85, 0.55 + Double(features.peak))
            return SoundClassification(type: .fart, confidence: confidence)
        }

        // 大口呼吸/打鼾：低频为主、音调性强的持续音，按响度区分严重程度。
        if isLowFrequencyDominant, isTonal, features.zeroCrossingRate < 0.08 {
            if features.rms > 0.045 {
                let confidence = min(0.92, 0.6 + Double(features.rms * 3))
                return SoundClassification(type: .heavyBreathing, confidence: confidence)
            }
            if features.rms > 0.018 {
                let confidence = min(0.92, 0.64 + Double(features.rms * 4))
                return SoundClassification(type: .snore, confidence: confidence)
            }
        }

        // 咳嗽：中高频为主的宽频带爆发音，峰值突出。
        if features.peak > 0.2, features.rms > 0.02, isBroadband,
           features.midBandRatio + features.highBandRatio > 0.5 {
            let confidence = min(0.88, 0.62 + Double(features.peak))
            return SoundClassification(type: .cough, confidence: confidence)
        }

        // 鼻塞：中频窄带哨鸣音，音调性强、强度适中、没有咳嗽那样的尖峰冲击。
        if features.midBandRatio > 0.45, isTonal,
           features.rms > 0.012, features.rms < 0.028, features.peak < 0.15 {
            let confidence = min(0.8, 0.55 + Double(features.rms * 5))
            return SoundClassification(type: .nasalCongestion, confidence: confidence)
        }

        // 磨牙：高频能量占比高、过零率高的摩擦音。
        if features.highBandRatio > 0.4, features.zeroCrossingRate > 0.08, features.peak > 0.08 {
            let confidence = min(0.86, 0.58 + Double(features.zeroCrossingRate * 2))
            return SoundClassification(type: .bruxism, confidence: confidence)
        }

        // 说梦话：中高频混合、有一定能量和过零率，但不像磨牙那样尖锐。
        if features.midBandRatio + features.highBandRatio > 0.4, features.rms > 0.012, features.zeroCrossingRate > 0.035 {
            return SoundClassification(type: .sleepTalk, confidence: 0.64)
        }
        return nil
    }
}

final class YAMNetSoundClassifier: SoundClassifying {
    private static let sampleRate: Double = 16_000
    private static let windowSampleCount = 15_600
    private static let hopSampleCount = 7_800
    private static let classCount = 521

    private var model: OpaquePointer?
    private var options: OpaquePointer?
    private var interpreter: OpaquePointer?
    private var sampleBuffer: [Float] = []
    private var labels: [String] = []
    private var recentTypes: [SleepEventType] = []

    init() {
        guard
            let modelURL = Bundle.main.url(
                forResource: "yamnet",
                withExtension: "tflite",
                subdirectory: "ModelResources"
            ),
            let labelURL = Bundle.main.url(
                forResource: "yamnet_class_map",
                withExtension: "csv",
                subdirectory: "ModelResources"
            )
        else {
            return
        }

        labels = Self.loadLabels(from: labelURL)
        modelURL.path.withCString { path in
            model = TfLiteModelCreateFromFile(path)
        }
        guard let model else { return }

        options = TfLiteInterpreterOptionsCreate()
        if let options {
            TfLiteInterpreterOptionsSetNumThreads(options, 2)
        }
        interpreter = TfLiteInterpreterCreate(model, options)
        guard let interpreter, TfLiteInterpreterAllocateTensors(interpreter) == kTfLiteOk else {
            self.interpreter = nil
            return
        }
    }

    deinit {
        if let interpreter {
            TfLiteInterpreterDelete(interpreter)
        }
        if let options {
            TfLiteInterpreterOptionsDelete(options)
        }
        if let model {
            TfLiteModelDelete(model)
        }
    }

    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification? {
        guard interpreter != nil else { return nil }
        sampleBuffer.append(contentsOf: Self.monoSamples16k(from: buffer))
        guard sampleBuffer.count >= Self.windowSampleCount else { return nil }

        let waveform = Array(sampleBuffer.prefix(Self.windowSampleCount))
        sampleBuffer.removeFirst(min(Self.hopSampleCount, sampleBuffer.count))
        guard let scores = invoke(waveform: waveform) else { return nil }
        return sleepClassification(from: scores, features: features)
    }

    private func invoke(waveform: [Float]) -> [Float]? {
        guard
            let interpreter,
            let input = TfLiteInterpreterGetInputTensor(interpreter, 0),
            TfLiteTensorType(input) == kTfLiteFloat32,
            TfLiteTensorByteSize(input) == waveform.count * MemoryLayout<Float>.stride
        else {
            return nil
        }

        let inputStatus = waveform.withUnsafeBytes { bytes in
            TfLiteTensorCopyFromBuffer(input, bytes.baseAddress, bytes.count)
        }
        guard inputStatus == kTfLiteOk, TfLiteInterpreterInvoke(interpreter) == kTfLiteOk,
              let output = TfLiteInterpreterGetOutputTensor(interpreter, 0),
              TfLiteTensorType(output) == kTfLiteFloat32
        else {
            return nil
        }

        let outputCount = TfLiteTensorByteSize(output) / MemoryLayout<Float>.stride
        guard outputCount >= Self.classCount else { return nil }
        var scores = [Float](repeating: 0, count: outputCount)
        let outputStatus = scores.withUnsafeMutableBytes { bytes in
            TfLiteTensorCopyToBuffer(output, bytes.baseAddress, bytes.count)
        }
        return outputStatus == kTfLiteOk ? scores : nil
    }

    private func sleepClassification(
        from scores: [Float],
        features: AudioFeatures
    ) -> SoundClassification? {
        let candidates = scores.enumerated()
            .filter { $0.offset < labels.count }
            .sorted { $0.element > $1.element }
            .prefix(8)

        for candidate in candidates {
            let label = labels[candidate.offset]
            let confidence = Double(candidate.element)
            guard let type = Self.sleepType(for: label) else { continue }
            guard confidence >= Self.threshold(for: type) else { continue }

            // 低响度下忽略除呼吸以外的分类，降低远处电视和环境底噪误报。
            if features.estimatedDecibel < 30, type != .heavyBreathing {
                continue
            }

            recentTypes.append(type)
            if recentTypes.count > 4 {
                recentTypes.removeFirst(recentTypes.count - 4)
            }

            let confirmations = recentTypes.filter { $0 == type }.count
            let isTransient = type == .cough || type == .noise
            guard isTransient || confirmations >= 2 else { return nil }
            return SoundClassification(type: type, confidence: confidence)
        }
        return nil
    }

    private static func sleepType(for label: String) -> SleepEventType? {
        switch label {
        case "Snoring":
            return .snore
        case "Cough", "Throat clearing", "Sneeze":
            return .cough
        case "Breathing", "Gasp", "Pant":
            return .heavyBreathing
        case "Wheeze":
            return .nasalCongestion
        case "Speech", "Conversation", "Narration, monologue", "Whispering":
            return .sleepTalk
        case "Chewing, mastication":
            return .bruxism
        case "Noise", "White noise", "Rustle":
            return .noise
        default:
            return nil
        }
    }

    private static func threshold(for type: SleepEventType) -> Double {
        switch type {
        case .snore:
            return 0.55
        case .cough:
            return 0.48
        case .heavyBreathing, .nasalCongestion:
            return 0.52
        case .sleepTalk:
            return 0.62
        case .bruxism:
            return 0.58
        case .noise:
            return 0.66
        default:
            return 0.6
        }
    }

    private static func monoSamples16k(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?[0] else { return [] }
        let sourceCount = Int(buffer.frameLength)
        guard sourceCount > 0 else { return [] }

        let sourceRate = buffer.format.sampleRate
        if abs(sourceRate - sampleRate) < 1 {
            return Array(UnsafeBufferPointer(start: channel, count: sourceCount))
        }

        let outputCount = max(1, Int(Double(sourceCount) * sampleRate / sourceRate))
        var output = [Float](repeating: 0, count: outputCount)
        let scale = sourceRate / sampleRate
        for index in 0..<outputCount {
            let position = Double(index) * scale
            let lower = min(Int(position), sourceCount - 1)
            let upper = min(lower + 1, sourceCount - 1)
            let fraction = Float(position - Double(lower))
            output[index] = channel[lower] * (1 - fraction) + channel[upper] * fraction
        }
        return output
    }

    private static func loadLabels(from url: URL) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content.split(whereSeparator: \.isNewline).dropFirst().compactMap { row in
            let columns = parseCSVRow(String(row))
            return columns.count >= 3 ? columns[2] : nil
        }
    }

    private static func parseCSVRow(_ row: String) -> [String] {
        var values: [String] = []
        var current = ""
        var quoted = false
        for character in row {
            if character == "\"" {
                quoted.toggle()
            } else if character == ",", !quoted {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values
    }
}
