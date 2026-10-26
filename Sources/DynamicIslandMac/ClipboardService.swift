import AppKit

public class ClipboardService {
    public static let shared = ClipboardService()
    
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    public var onNewClip: ((String) -> Void)?
    
    public init() {}
    
    public func startMonitoring(onChange: @escaping (String) -> Void) {
        self.onNewClip = onChange
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let current = NSPasteboard.general.changeCount
            if current != self.lastChangeCount {
                self.lastChangeCount = current
                if let str = NSPasteboard.general.string(forType: .string) {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        DispatchQueue.main.async {
                            self.onNewClip?(str)
                        }
                    }
                }
            }
        }
    }
    
    public func getCurrentClipboard() -> String? {
        if let str = NSPasteboard.general.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return str
            }
        }
        return nil
    }
    
    public func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        self.lastChangeCount = pb.changeCount
    }
    
    deinit {
        timer?.invalidate()
    }
}
