import Foundation
import AppKit
import CoreAudio

public class AudioService {
    public static let shared = AudioService()
    
    private var lastVolume: Int = -1
    private var lastMuted: Bool? = nil
    private var isMonitoring = false
    private var currentOutputDevice: AudioDeviceID = 0
    private var changeHandler: ((_ volume: Int, _ isMuted: Bool) -> Void)?
    
    // CoreAudio property addresses
    private var defaultDeviceAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var volMainAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private var volCh1Addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: 1
    )
    private var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private init() {}
    
    public func startMonitoring(onChange: @escaping (_ volume: Int, _ isMuted: Bool) -> Void) {
        guard !isMonitoring else { return }
        isMonitoring = true
        self.changeHandler = onChange
        
        attachListeners()
        
        if let (vol, muted) = getSystemAudioState() {
            self.lastVolume = vol
            self.lastMuted = muted
        }
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        detachListeners()
        changeHandler = nil
    }
    
    private func attachListeners() {
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddr,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleDeviceChange()
        }
        
        currentOutputDevice = fetchDefaultOutputDevice()
        attachDeviceListeners(for: currentOutputDevice)
    }
    
    private func detachListeners() {
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddr,
            DispatchQueue.main
        ) { _, _ in }
        detachDeviceListeners(for: currentOutputDevice)
    }
    
    private func attachDeviceListeners(for dev: AudioDeviceID) {
        guard dev != 0 else { return }
        let queue = DispatchQueue.main
        
        AudioObjectAddPropertyListenerBlock(dev, &volMainAddr, queue) { [weak self] _, _ in
            self?.notifyStateChange()
        }
        AudioObjectAddPropertyListenerBlock(dev, &volCh1Addr, queue) { [weak self] _, _ in
            self?.notifyStateChange()
        }
        AudioObjectAddPropertyListenerBlock(dev, &muteAddr, queue) { [weak self] _, _ in
            self?.notifyStateChange()
        }
    }
    
    private func detachDeviceListeners(for dev: AudioDeviceID) {
        guard dev != 0 else { return }
        let queue = DispatchQueue.main
        AudioObjectRemovePropertyListenerBlock(dev, &volMainAddr, queue) { _, _ in }
        AudioObjectRemovePropertyListenerBlock(dev, &volCh1Addr, queue) { _, _ in }
        AudioObjectRemovePropertyListenerBlock(dev, &muteAddr, queue) { _, _ in }
    }
    
    private func handleDeviceChange() {
        detachDeviceListeners(for: currentOutputDevice)
        currentOutputDevice = fetchDefaultOutputDevice()
        attachDeviceListeners(for: currentOutputDevice)
        // Silently synchronize baseline audio state of the new output device (e.g. Bluetooth connect/disconnect)
        // without triggering a false Volume/Mute HUD banner.
        if let (vol, muted) = getSystemAudioState() {
            self.lastVolume = vol
            self.lastMuted = muted
        }
    }
    
    private func fetchDefaultOutputDevice() -> AudioDeviceID {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = defaultDeviceAddr
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return err == noErr ? dev : 0
    }
    
    private func notifyStateChange() {
        guard let (vol, muted) = getSystemAudioState() else { return }
        let volChanged = (self.lastVolume != -1 && self.lastVolume != vol)
        let muteChanged = (self.lastMuted != nil && self.lastMuted != muted)
        
        if volChanged || muteChanged {
            self.lastVolume = vol
            self.lastMuted = muted
            self.changeHandler?(vol, muted)
        }
    }
    
    public func getSystemAudioState() -> (volume: Int, isMuted: Bool)? {
        let dev = currentOutputDevice != 0 ? currentOutputDevice : fetchDefaultOutputDevice()
        guard dev != 0 else {
            return getSystemAudioStateAppleScript()
        }
        
        var volFloat: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var addr = volMainAddr
        var err = AudioObjectGetPropertyData(dev, &addr, 0, nil, &volSize, &volFloat)
        if err != noErr {
            addr = volCh1Addr
            err = AudioObjectGetPropertyData(dev, &addr, 0, nil, &volSize, &volFloat)
        }
        
        var muteInt: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var mAddr = muteAddr
        let mErr = AudioObjectGetPropertyData(dev, &mAddr, 0, nil, &muteSize, &muteInt)
        
        if err == noErr {
            let vol = Int(round(volFloat * 100.0))
            let isMuted = (mErr == noErr && muteInt != 0)
            return (max(0, min(100, vol)), isMuted)
        }
        
        return getSystemAudioStateAppleScript()
    }
    
    private func getSystemAudioStateAppleScript() -> (volume: Int, isMuted: Bool)? {
        let script = NSAppleScript(source: "set s to get volume settings\nreturn \"\" & (output volume of s) & \",\" & (output muted of s)")
        var error: NSDictionary?
        if let result = script?.executeAndReturnError(&error), error == nil,
           let str = result.stringValue {
            let parts = str.split(separator: ",")
            if parts.count >= 2, let vol = Int(parts[0].trimmingCharacters(in: .whitespaces)) {
                let muted = parts[1].trimmingCharacters(in: .whitespaces).lowercased() == "true"
                return (vol, muted)
            }
        }
        return nil
    }
    
    public func getSystemVolume() -> Int? {
        return getSystemAudioState()?.volume
    }
    
    public func setSystemVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        let dev = currentOutputDevice != 0 ? currentOutputDevice : fetchDefaultOutputDevice()
        if dev != 0 {
            var volFloat = Float32(clamped) / 100.0
            let volSize = UInt32(MemoryLayout<Float32>.size)
            var addr = volMainAddr
            if AudioObjectSetPropertyData(dev, &addr, 0, nil, volSize, &volFloat) != noErr {
                var ch1 = volCh1Addr
                AudioObjectSetPropertyData(dev, &ch1, 0, nil, volSize, &volFloat)
                var ch2 = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioObjectPropertyScopeOutput, mElement: 2)
                AudioObjectSetPropertyData(dev, &ch2, 0, nil, volSize, &volFloat)
            }
        } else {
            let script = "set volume output volume \(clamped) without output muted"
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        self.lastVolume = clamped
        self.lastMuted = false
    }
    
    public func toggleMute() {
        let newMute = !(lastMuted ?? false)
        let dev = currentOutputDevice != 0 ? currentOutputDevice : fetchDefaultOutputDevice()
        if dev != 0 {
            var muteVal: UInt32 = newMute ? 1 : 0
            let muteSize = UInt32(MemoryLayout<UInt32>.size)
            var addr = muteAddr
            AudioObjectSetPropertyData(dev, &addr, 0, nil, muteSize, &muteVal)
        } else {
            let script = "set volume output muted \(newMute)"
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        self.lastMuted = newMute
    }
    
    // MARK: - Microphone Mute Control (On-Demand only)
    private var lastInputVolume: Int = 50
    
    public func isMicMuted() -> Bool {
        var error: NSDictionary?
        let script = "input volume of (get volume settings)"
        if let appleScript = NSAppleScript(source: script) {
            let res = appleScript.executeAndReturnError(&error)
            if error == nil {
                return res.int32Value == 0
            }
        }
        return false
    }
    
    public func toggleMicrophoneMute() -> Bool {
        let currentlyMuted = isMicMuted()
        let newVolume = currentlyMuted ? (lastInputVolume > 0 ? lastInputVolume : 75) : 0
        if !currentlyMuted {
            var error: NSDictionary?
            let script = "input volume of (get volume settings)"
            if let appleScript = NSAppleScript(source: script) {
                let res = appleScript.executeAndReturnError(&error)
                if error == nil && res.int32Value > 0 {
                    lastInputVolume = Int(res.int32Value)
                }
            }
        }
        let setScript = "set volume input volume \(newVolume)"
        if let appleScript = NSAppleScript(source: setScript) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        return !currentlyMuted
    }
}
