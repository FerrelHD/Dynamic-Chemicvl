import Foundation
import AppKit

public class AudioService {
    public static let shared = AudioService()
    
    private var lastVolume: Int = -1
    private var isMonitoring = false
    private let queue = DispatchQueue(label: "com.dynamicisland.audiomonitor", qos: .utility)
    
    public func startMonitoring(onVolumeChange: @escaping (Int) -> Void) {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        queue.async { [weak self] in
            while self?.isMonitoring == true {
                if let vol = self?.getSystemVolume() {
                    if self?.lastVolume != -1 && self?.lastVolume != vol {
                        DispatchQueue.main.async {
                            onVolumeChange(vol)
                        }
                    }
                    self?.lastVolume = vol
                }
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }
    
    public func stopMonitoring() {
        isMonitoring = false
    }
    
    public func getSystemVolume() -> Int? {
        var error: NSDictionary?
        let script = "output volume of (get volume settings)"
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                return Int(result.int32Value)
            }
        }
        return nil
    }
    
    public func setSystemVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        let script = "set volume output volume \(clamped)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        self.lastVolume = clamped
    }
}

