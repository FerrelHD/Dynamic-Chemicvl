import Foundation
import IOKit.ps

public struct BatteryStatus {
    public let level: Int
    public let isCharging: Bool
    public let isPlugged: Bool
}

private func powerSourceNotificationCallback(_ context: UnsafeMutableRawPointer?) {
    BatteryService.shared.handlePowerChange()
}

public class BatteryService {
    public static let shared = BatteryService()
    
    private var runLoopSource: CFRunLoopSource?
    private var lastPluggedState: Bool?
    private var onChangeHandler: ((BatteryStatus, Bool) -> Void)?
    
    public init() {}
    
    public func getStatus() -> BatteryStatus {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatteryStatus(level: 100, isCharging: false, isPlugged: false)
        }
        
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let isPlugged = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let pct = max > 0 ? Int((Double(current) / Double(max)) * 100) : 0
            return BatteryStatus(level: pct, isCharging: isCharging, isPlugged: isPlugged)
        }
        
        return BatteryStatus(level: 100, isCharging: false, isPlugged: false)
    }
    
    public func startMonitoring(onChange: @escaping (BatteryStatus, Bool) -> Void) {
        let initial = getStatus()
        self.lastPluggedState = initial.isPlugged
        self.onChangeHandler = onChange
        
        let source = IOPSNotificationCreateRunLoopSource(powerSourceNotificationCallback, nil)?.takeRetainedValue()
        if let source = source {
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
    
    fileprivate func handlePowerChange() {
        let current = getStatus()
        let powerStateChanged = (lastPluggedState != current.isPlugged)
        lastPluggedState = current.isPlugged
        
        DispatchQueue.main.async { [weak self] in
            self?.onChangeHandler?(current, powerStateChanged)
        }
    }
    
    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}

