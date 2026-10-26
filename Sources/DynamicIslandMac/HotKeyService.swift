import Foundation
import Carbon
import AppKit

private func hotKeyEventHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let theEvent = theEvent else { return noErr }
    
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    
    if status == noErr && hotKeyID.signature == OSType(0x4449534C) { // 'DISL'
        DispatchQueue.main.async {
            HotKeyService.shared.onHotKeyPressed?()
        }
    }
    
    return noErr
}

public class HotKeyService {
    public static let shared = HotKeyService()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    public var onHotKeyPressed: (() -> Void)?
    
    public init() {}
    
    public func registerDefaultHotKey(action: @escaping () -> Void) {
        self.onHotKeyPressed = action
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        // Option + Space (kVK_Space = 49, optionKey = 0x0800)
        let hotKeyID = EventHotKeyID(signature: OSType(0x4449534C), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("⌨️ Global Shortcut Registered: Option + Space")
        } else {
            print("⚠️ Failed to register global shortcut: \(status)")
        }
    }
    
    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

