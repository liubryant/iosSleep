import AVFoundation
import Accelerate
import Foundation

struct AudioFeatures {
    let rms: Float
    let peak: Float
    let estimatedDecibel: Double
    let spectralCentroid: Float
}

enum AudioFeatureExtractor {
    static func features(from buffer: AVAudioPCMBuffer) -> AudioFeatures? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return nil }

        var meanSquare: Float = 0
        vDSP_measqv(channel, 1, &meanSquare, vDSP_Length(count))
        let rms = sqrt(meanSquare)

        var peak: Float = 0
        vDSP_maxmgv(channel, 1, &peak, vDSP_Length(count))

        let db = max(-80, 20 * log10(Double(max(rms, 0.000_001))) + 90)
        let centroid = estimateSpectralCentroid(samples: channel, count: count, sampleRate: Float(buffer.format.sampleRate))
        return AudioFeatures(rms: rms, peak: peak, estimatedDecibel: db, spectralCentroid: centroid)
    }

    // Lightweight placeholder for the Mel Spectrogram stage. It keeps the public shape
    // needed by a future YAMNet model without forcing a model file into the first build.
    static func melSpectrogram(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?[0] else { return [] }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return [] }
        let bucketCount = 64
        let bucketSize = max(1, count / bucketCount)
        return (0..<bucketCount).map { bucket in
            let start = bucket * bucketSize
            let end = min(start + bucketSize, count)
            guard start < end else { return 0 }
            var mean: Float = 0
            vDSP_meamgv(channel + start, 1, &mean, vDSP_Length(end - start))
            return log1p(mean)
        }
    }

    private static func estimateSpectralCentroid(samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        let step = max(1, count / 64)
        var weighted: Float = 0
        var total: Float = 0

        for index in stride(from: 0, to: count, by: step) {
            let magnitude = abs(samples[index])
            let frequency = Float(index) / Float(count) * sampleRate
            weighted += frequency * magnitude
            total += magnitude
        }

        return total > 0 ? weighted / total : 0
    }
}
