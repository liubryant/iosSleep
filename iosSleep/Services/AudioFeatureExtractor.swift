import AVFoundation
import Accelerate
import Foundation

struct AudioFeatures {
    let rms: Float
    let peak: Float
    let estimatedDecibel: Double
    let zeroCrossingRate: Float
    /// 频谱质心（Hz），由 FFT 幅度谱计算得到，频率越高表示声音越尖锐/明亮。
    let spectralCentroid: Float
    /// 500Hz 以下能量占总能量的比例。
    let lowBandRatio: Float
    /// 500Hz ~ 2000Hz 能量占总能量的比例。
    let midBandRatio: Float
    /// 2000Hz 以上能量占总能量的比例。
    let highBandRatio: Float
    /// 频谱平坦度（几何均值 / 算术均值），越接近 0 越偏音调性，越接近 1 越偏噪声。
    let spectralFlatness: Float
}

enum AudioFeatureExtractor {
    private static let lowBandCutoff: Float = 500
    private static let highBandCutoff: Float = 2_000

    /// FFT 长度上限 2^12 = 4096，覆盖典型 4096 采样的输入缓冲区。
    private static let maxLog2n: vDSP_Length = 12
    private static let maxFFTLength = 1 << Int(maxLog2n)
    private static let fftSetup: FFTSetup = vDSP_create_fftsetup(maxLog2n, FFTRadix(kFFTRadix2))!

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
        let zeroCrossingRate = estimateZeroCrossingRate(samples: channel, count: count)
        let spectrum = analyzeSpectrum(samples: channel, count: count, sampleRate: Float(buffer.format.sampleRate))

        return AudioFeatures(
            rms: rms,
            peak: peak,
            estimatedDecibel: db,
            zeroCrossingRate: zeroCrossingRate,
            spectralCentroid: spectrum.centroid,
            lowBandRatio: spectrum.lowBandRatio,
            midBandRatio: spectrum.midBandRatio,
            highBandRatio: spectrum.highBandRatio,
            spectralFlatness: spectrum.flatness
        )
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

    private struct SpectrumFeatures {
        let centroid: Float
        let lowBandRatio: Float
        let midBandRatio: Float
        let highBandRatio: Float
        let flatness: Float
    }

    /// 使用 vDSP 实数 FFT 计算幅度谱，并据此得到频谱质心、低/中/高频带能量占比与频谱平坦度。
    private static func analyzeSpectrum(samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> SpectrumFeatures {
        let fftLength = fftLength(for: count)
        let half = fftLength / 2
        let log2n = vDSP_Length(log2(Float(fftLength)))

        var windowed = [Float](repeating: 0, count: fftLength)
        let usable = min(count, fftLength)
        var window = [Float](repeating: 0, count: usable)
        vDSP_hann_window(&window, vDSP_Length(usable), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(usable))

        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPtr in
                    windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        let binWidth = sampleRate / Float(fftLength)
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0
        var lowSum: Float = 0
        var midSum: Float = 0
        var highSum: Float = 0
        var logSum: Float = 0

        for index in 0..<half {
            let magnitude = magnitudes[index]
            let frequency = Float(index) * binWidth
            weightedSum += frequency * magnitude
            totalMagnitude += magnitude
            logSum += log(magnitude + 1e-9)

            if frequency < lowBandCutoff {
                lowSum += magnitude
            } else if frequency < highBandCutoff {
                midSum += magnitude
            } else {
                highSum += magnitude
            }
        }

        guard totalMagnitude > 0 else {
            return SpectrumFeatures(centroid: 0, lowBandRatio: 0, midBandRatio: 0, highBandRatio: 0, flatness: 0)
        }

        let meanMagnitude = totalMagnitude / Float(half)
        let geometricMean = exp(logSum / Float(half))

        return SpectrumFeatures(
            centroid: weightedSum / totalMagnitude,
            lowBandRatio: lowSum / totalMagnitude,
            midBandRatio: midSum / totalMagnitude,
            highBandRatio: highSum / totalMagnitude,
            flatness: meanMagnitude > 0 ? geometricMean / meanMagnitude : 0
        )
    }

    /// 返回不超过 `count` 且不超过 FFT 上限的最大 2 的幂，用作 FFT 长度。
    private static func fftLength(for count: Int) -> Int {
        var length = 64
        while length * 2 <= count && length < maxFFTLength {
            length *= 2
        }
        return length
    }

    private static func estimateZeroCrossingRate(samples: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 1 else { return 0 }
        var crossings = 0

        for index in 1..<count {
            let previous = samples[index - 1]
            let current = samples[index]
            if (previous >= 0 && current < 0) || (previous < 0 && current >= 0) {
                crossings += 1
            }
        }

        return Float(crossings) / Float(count - 1)
    }
}
