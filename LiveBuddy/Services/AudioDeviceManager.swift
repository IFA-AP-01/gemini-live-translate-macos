import Foundation
import CoreAudio

struct AudioDevice: Identifiable, Hashable, Codable {
    var id: AudioDeviceID {
        deviceID
    }
    let deviceID: AudioDeviceID
    let uid: String
    let name: String

    var idString: String {
        uid
    }
}

final class AudioDeviceManager {
    static func getInputDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return [] }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else { return [] }
        
        var inputDevices: [AudioDevice] = []
        
        for deviceID in deviceIDs {
            // Check if the device has input channels/streams
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var streamDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(
                deviceID,
                &streamAddress,
                0,
                nil,
                &streamDataSize
            )
            
            guard status == noErr, streamDataSize > 0 else { continue }
            
            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            status = withUnsafeMutablePointer(to: &name) {
                AudioObjectGetPropertyData(
                    deviceID,
                    &nameAddress,
                    0,
                    nil,
                    &nameSize,
                    $0
                )
            }
            
            let deviceName = (status == noErr) ? (name as String) : "Unknown Device"
            
            // Get UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            status = withUnsafeMutablePointer(to: &uid) {
                AudioObjectGetPropertyData(
                    deviceID,
                    &uidAddress,
                    0,
                    nil,
                    &uidSize,
                    $0
                )
            }
            
            let deviceUID = (status == noErr) ? (uid as String) : ""
            
            inputDevices.append(AudioDevice(deviceID: deviceID, uid: deviceUID, name: deviceName))
        }
        
        return inputDevices
    }

    static func getDeviceID(for uid: String) -> AudioDeviceID? {
        getInputDevices().first { $0.uid == uid }?.deviceID
    }
}
