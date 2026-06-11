import AVFoundation

final class PCM16Chunker {
    private let lock = NSLock()
    nonisolated(unsafe) private var pending = Data()
    private let chunkSize = 3_200
    private let onChunk: @Sendable (Data) -> Void

    init(onChunk: @escaping @Sendable (Data) -> Void) {
        self.onChunk = onChunk
    }

    nonisolated func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        while pending.count >= chunkSize {
            let chunk = pending.prefix(chunkSize)
            onChunk(Data(chunk))
            pending.removeFirst(chunkSize)
        }
    }

    nonisolated func reset() {
        lock.lock()
        defer { lock.unlock() }
        pending.removeAll(keepingCapacity: true)
    }
}

final class PCM16Downsampler {
    private let targetSampleRate: Double = 16_000

    nonisolated func convert(buffer: AVAudioPCMBuffer) -> Data {
        guard let channels = buffer.floatChannelData else { return Data() }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        guard channelCount > 0, frameCount > 0 else { return Data() }

        var mono = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            var sample: Float = 0
            for channel in 0..<channelCount {
                sample += channels[channel][frame]
            }
            mono[frame] = sample / Float(channelCount)
        }
        return convertMonoFloat(mono, sourceSampleRate: buffer.format.sampleRate)
    }

    nonisolated func convertInterleavedFloat32(_ samples: [Float], sourceSampleRate: Double, channels: Int) -> Data {
        guard channels > 0 else { return Data() }
        let frames = samples.count / channels
        guard frames > 0 else { return Data() }
        var mono = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            var sample: Float = 0
            for channel in 0..<channels {
                sample += samples[frame * channels + channel]
            }
            mono[frame] = sample / Float(channels)
        }
        return convertMonoFloat(mono, sourceSampleRate: sourceSampleRate)
    }

    nonisolated func convertInt16PCM(_ samples: [Int16], sourceSampleRate: Double, channels: Int) -> Data {
        guard channels > 0 else { return Data() }
        let frames = samples.count / channels
        guard frames > 0 else { return Data() }
        var mono = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            var sample: Float = 0
            for channel in 0..<channels {
                sample += Float(Int16(littleEndian: samples[frame * channels + channel])) / Float(Int16.max)
            }
            mono[frame] = sample / Float(channels)
        }
        return convertMonoFloat(mono, sourceSampleRate: sourceSampleRate)
    }

    private nonisolated func convertMonoFloat(_ samples: [Float], sourceSampleRate: Double) -> Data {
        guard !samples.isEmpty, sourceSampleRate > 0 else { return Data() }
        let ratio = targetSampleRate / sourceSampleRate
        let outputCount = max(1, Int(Double(samples.count) * ratio))
        var output = Data(capacity: outputCount * 2)

        for index in 0..<outputCount {
            let sourcePosition = Double(index) / ratio
            let lower = min(Int(sourcePosition), samples.count - 1)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(sourcePosition - Double(lower))
            let sample = samples[lower] + (samples[upper] - samples[lower]) * fraction
            var intSample = Int16(max(-1, min(1, sample)) * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &intSample) { output.append(contentsOf: $0) }
        }

        return output
    }
}
