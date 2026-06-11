import AVFoundation

final class PCM16AudioPlayer {
    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private let player = AVAudioPlayerNode()
    private let queue = DispatchQueue(label: "livebuddy.audio.playback")
    nonisolated(unsafe) private var isPrepared = false

    nonisolated func playPCM16(_ data: Data, sampleRate: Double) {
        guard !data.isEmpty else { return }
        queue.async { [weak self] in
            self?.enqueue(data, sampleRate: sampleRate)
        }
    }

    nonisolated func stop() {
        queue.async { [weak self] in
            self?.player.stop()
            self?.engine.stop()
            self?.isPrepared = false
        }
    }

    private nonisolated func enqueue(_ data: Data, sampleRate: Double) {
        do {
            try prepare(sampleRate: sampleRate)
        } catch {
            return
        }

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else { return }
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let output = buffer.floatChannelData?[0] else { return }

        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for index in 0..<Int(frameCount) {
                output[index] = Float(Int16(littleEndian: samples[index])) / Float(Int16.max)
            }
        }

        player.scheduleBuffer(buffer)
        if !player.isPlaying {
            player.play()
        }
    }

    private nonisolated func prepare(sampleRate: Double) throws {
        guard !isPrepared else { return }
        engine.attach(player)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        isPrepared = true
    }
}
