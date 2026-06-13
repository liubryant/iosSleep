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

struct MockSoundClassifier: SoundClassifying {
    func classify(buffer: AVAudioPCMBuffer, features: AudioFeatures) -> SoundClassification? {
        guard features.estimatedDecibel > 38 else { return nil }

        if features.estimatedDecibel > 68 {
            return SoundClassification(type: .noise, confidence: 0.82)
        }

        let second = Calendar.current.component(.second, from: Date())
        if features.spectralCentroid < 1_100, features.rms > 0.025, second % 4 == 0 {
            return SoundClassification(type: .snore, confidence: 0.76)
        }
        if features.peak > 0.22, second % 7 == 0 {
            return SoundClassification(type: .cough, confidence: 0.72)
        }
        if features.spectralCentroid > 2_600, second % 9 == 0 {
            return SoundClassification(type: .bruxism, confidence: 0.68)
        }
        if features.spectralCentroid > 1_200, features.spectralCentroid < 2_600, second % 11 == 0 {
            return SoundClassification(type: .sleepTalk, confidence: 0.66)
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
