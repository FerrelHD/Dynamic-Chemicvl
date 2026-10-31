import Foundation
import AppKit
import IOKit.pwr_mgt

public class SystemControlService {
    public static let shared = SystemControlService()
    
    private let queue = DispatchQueue(label: "com.dynamicisland.controlservice", qos: .utility)
    private var caffeinateAssertionID: IOPMAssertionID = 0
    
    public var isCaffeinateActive: Bool {
        return caffeinateAssertionID != 0
    }
    
    public func toggleCaffeinate() -> Bool {
        if caffeinateAssertionID != 0 {
            IOPMAssertionRelease(caffeinateAssertionID)
            caffeinateAssertionID = 0
            return false
        } else {
            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Dynamic Island Keep Awake" as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess {
                caffeinateAssertionID = assertionID
                return true
            }
            return false
        }
    }
    
    public func getWifiStatus(completion: @escaping (Bool, String) -> Void) {
        queue.async {
            let powerOut = self.runShell("networksetup -getairportpower en0")
            let isEnabled = powerOut.contains(": On")
            
            var ssid = "Not Connected"
            if isEnabled {
                let airportCmd = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I"
                let airportOut = self.runShell("\(airportCmd) | grep -w SSID")
                let parts = airportOut.components(separatedBy: ":")
                if parts.count >= 2 {
                    let extracted = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty {
                        ssid = extracted
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(isEnabled, isEnabled ? ssid : "Off")
            }
        }
    }
    
    public func toggleWifi(currentlyEnabled: Bool, completion: @escaping (Bool) -> Void) {
        let newState = !currentlyEnabled
        queue.async {
            let cmd = "networksetup -setairportpower en0 \(newState ? "on" : "off")"
            _ = self.runShell(cmd)
            DispatchQueue.main.async {
                completion(newState)
            }
        }
    }
    
    public func toggleBluetooth(currentlyEnabled: Bool, completion: @escaping (Bool) -> Void) {
        let newState = !currentlyEnabled
        queue.async {
            // Membuka panel preferensi Bluetooth atau toggle cepat
            let script = "tell application \"System Preferences\" to reveal pane id \"com.apple.preferences.Bluetooth\""
            _ = self.executeScript(script)
            DispatchQueue.main.async {
                completion(newState)
            }
        }
    }
    
    public func toggleDoNotDisturb(currentlyEnabled: Bool, completion: @escaping (Bool) -> Void) {
        let newState = !currentlyEnabled
        queue.async {
            let script = """
            tell application "System Events"
                try
                    tell process "ControlCenter"
                        set clockItem to first menu bar item of menu bar 1 whose name contains "Clock"
                        key down option
                        click clockItem
                        key up option
                    end tell
                on error
                    key code 122 using {control down}
                end try
            end tell
            """
            _ = self.executeScript(script)
            DispatchQueue.main.async {
                completion(newState)
            }
        }
    }
    
    // MARK: - Lock Screen Immediate (Pure Apple C API, 0ms latency)
    public func lockScreen() {
        typealias SACLockScreenImmediateFunc = @convention(c) () -> Void
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                let lockFunc = unsafeBitCast(sym, to: SACLockScreenImmediateFunc.self)
                lockFunc()
            }
            dlclose(handle)
        } else {
            _ = runShell("/usr/bin/pmset displaysleepnow")
        }
    }
    
    private func runShell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    private func executeScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
}
