import AppKit

public class CapsLockService {
    public static let shared = CapsLockService()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastState: Bool = false
    
    public init() {}
    
    public func startMonitoring(onChange: @escaping (Bool) -> Void) {
        lastState = NSEvent.modifierFlags.contains(.capsLock)
        
        let checkEvent: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            let isCaps = event.modifierFlags.contains(.capsLock)
            if isCaps != self.lastState {
                self.lastState = isCaps
                DispatchQueue.main.async {
                    onChange(isCaps)
                }
            }
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: checkEvent)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            checkEvent(event)
            return event
        }
    }
}

