import AVFoundation
import CoreML
import Foundation

struct SoundClassification {
    let type: SleepEventType
    let confidence: Double
}

protocol SoundClassifying {
    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification?
}

struct HybridSleepSoundClassifier: SoundClassifying {
    private let yamNet = YAMNetSoundClassifier()
    private let fallback = FeatureBasedSleepSoundClassifier()

    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification? {
        yamNet.classify(buffer: buffer, features: features) ?? fallback.classify(buffer: buffer, features: features)
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
    private let model: MLModel?

    init(modelName: String = "YAMNet") {
        if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            model = try? MLModel(contentsOf: url)
        } else {
            model = nil
        }
    }

    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification? {
        guard model != nil else { return nil }
        _ = AudioFeatureExtractor.melSpectrogram(from: buffer)
        // TODO: Map YAMNet output labels to SleepEventType after adding the compiled model.
        return nil
    }
}
