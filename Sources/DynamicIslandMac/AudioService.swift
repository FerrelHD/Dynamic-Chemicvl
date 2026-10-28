import Foundation
import AppKit

public class AudioService {
    public static let shared = AudioService()
    
    private var lastVolume: Int = -1
    private var lastMuted: Bool? = nil
    private var isMonitoring = false
    private let queue = DispatchQueue(label: "com.dynamicisland.audiomonitor", qos: .utility)
    
    // Pre-compiled AppleScript for instant, zero-alloc execution
    private let queryScript = NSAppleScript(source: "set s to get volume settings\nreturn \"\" & (output volume of s) & \",\" & (output muted of s)")
    
    public func startMonitoring(onChange: @escaping (_ volume: Int, _ isMuted: Bool) -> Void) {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        queue.async { [weak self] in
            while self?.isMonitoring == true {
                if let (vol, muted) = self?.getSystemAudioState() {
                    let volChanged = (self?.lastVolume != -1 && self?.lastVolume != vol)
                    let muteChanged = (self?.lastMuted != nil && self?.lastMuted != muted)
                    
                    if volChanged || muteChanged {
                        DispatchQueue.main.async {
                            onChange(vol, muted)
                        }
                    }
                    self?.lastVolume = vol
                    self?.lastMuted = muted
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
    }
    
    public func stopMonitoring() {
        isMonitoring = false
    }
    
    public func getSystemAudioState() -> (volume: Int, isMuted: Bool)? {
        var error: NSDictionary?
        if let result = queryScript?.executeAndReturnError(&error), error == nil,
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
        let script = "set volume output volume \(clamped) without output muted"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        self.lastVolume = clamped
        self.lastMuted = false
    }
    
    public func toggleMute() {
        let newMute = !(lastMuted ?? false)
        let script = "set volume output muted \(newMute)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        self.lastMuted = newMute
    }
}

