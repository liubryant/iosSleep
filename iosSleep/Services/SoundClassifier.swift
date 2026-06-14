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

        if features.spectralCentroid < 950, features.rms > 0.018, features.zeroCrossingRate < 0.08 {
            let confidence = min(0.92, 0.64 + Double(features.rms * 4))
            return SoundClassification(type: .snore, confidence: confidence)
        }

        if features.peak > 0.2, features.rms > 0.02, features.spectralCentroid > 900, features.spectralCentroid < 2_400 {
            let confidence = min(0.88, 0.62 + Double(features.peak))
            return SoundClassification(type: .cough, confidence: confidence)
        }

        if features.spectralCentroid > 2_400, features.zeroCrossingRate > 0.08, features.peak > 0.08 {
            let confidence = min(0.86, 0.58 + Double(features.zeroCrossingRate * 2))
            return SoundClassification(type: .bruxism, confidence: confidence)
        }

        if features.spectralCentroid > 1_000, features.spectralCentroid < 2_800, features.rms > 0.012, features.zeroCrossingRate > 0.035 {
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
