import AVFoundation
import AudioToolbox
import CoreAudio

final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private let downsampler = PCM16Downsampler()
    private let chunker: PCM16Chunker

    init(onAudioChunk: @escaping @Sendable (Data) -> Void) {
        chunker = PCM16Chunker(onChunk: onAudioChunk)
    }

    func start(selectedDeviceUID: String?) async throws {
        try await requestPermissionIfNeeded()
        let input = engine.inputNode

        if let uid = selectedDeviceUID, let deviceID = AudioDeviceManager.getDeviceID(for: uid) {
            guard let inputAudioUnit = input.audioUnit else {
                throw MicrophoneCaptureError.audioUnitUnavailable
            }

            var mutableDeviceID = deviceID
            let size = UInt32(MemoryLayout<AudioDeviceID>.size)
            let status = AudioUnitSetProperty(
                inputAudioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableDeviceID,
                size
            )

            if status != noErr {
                print("Failed to set audio input device status: \(status)")
            }
        }

        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let pcm = self.downsampler.convert(buffer: buffer)
            self.chunker.append(pcm)
        }
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        chunker.reset()
    }

    private func requestPermissionIfNeeded() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            if granted {
                return
            }
            throw MicrophoneCaptureError.permissionDenied
        case .denied, .restricted:
            throw MicrophoneCaptureError.permissionDenied
        @unknown default:
            throw MicrophoneCaptureError.permissionDenied
        }
    }
}

enum MicrophoneCaptureError: LocalizedError {
    case permissionDenied
    case audioUnitUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Microphone permission is required. Enable it in System Settings > Privacy & Security > Microphone."
        case .audioUnitUnavailable: "Audio unit is unavailable for the selected microphone."
        }
    }
}
