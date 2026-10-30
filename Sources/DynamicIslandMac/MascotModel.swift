import SwiftUI
import AppKit
import Combine

// MARK: - Mascot Living Model (State Machine & Native Hardware Idle Sensor)
public class MascotModel: ObservableObject {
    @Published public var look: CGSize = .zero
    @Published public var tilt: Double = 0.0
    @Published public var openness: CGFloat = 1.0 // 1.0 (fully open) to 0.0 (closed slit)
    @Published public var smile: CGFloat = 0.0    // 0.0 (oval capsule) to 1.0 (smiling arc)
    @Published public var isHappy: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // Organic pulse timer: checks mouse movement & drives organic life (0% CPU cost)
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.stepOrganicBehavior()
            }
            .store(in: &cancellables)
    }
    
    public func setHappy(_ happy: Bool) {
        self.isHappy = happy
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            self.smile = happy ? 1.0 : 0.0
        }
    }
    
    private func stepOrganicBehavior() {
        // Native macOS Hardware Event Idle Sensor (checks seconds since last mouse move)
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let isUserAFK = idleSeconds >= 30.0 // 30 seconds without user mouse/trackpad movement
        
        if !isUserAFK {
            // USER ACTIVE: Keep eyes centered and straight ahead, only soft natural blinks
            if look != .zero || tilt != 0 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    look = .zero
                    tilt = 0.0
                }
            }
            
            let roll = Int.random(in: 1...100)
            if roll <= 45 {
                performBlink()
            } else if roll <= 60 {
                performDoubleBlink()
            }
        } else {
            // USER IDLE >= 2 MINUTES: Notchy enters curious exploration (glancing left/right, subtle head tilt)
            let roll = Int.random(in: 1...100)
            if roll <= 50 {
                performGlance()
            } else if roll <= 80 {
                performBlink()
            } else {
                performDoubleBlink()
            }
        }
    }
    
    public func performBlink() {
        withAnimation(.easeIn(duration: 0.09)) {
            openness = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                self?.openness = 1.0
            }
        }
    }
    
    public func performDoubleBlink() {
        withAnimation(.easeIn(duration: 0.08)) {
            openness = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            withAnimation(.easeOut(duration: 0.08)) {
                self?.openness = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                withAnimation(.easeIn(duration: 0.08)) {
                    self?.openness = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                        self?.openness = 1.0
                    }
                }
            }
        }
    }
    
    public func performGlance() {
        let targets: [(CGFloat, CGFloat, Double)] = [
            (2.2, -0.4, 2.5),
            (-2.2, -0.4, -2.5),
            (1.5, 0.4, 1.5),
            (-1.5, 0.4, -1.5)
        ]
        guard let choice = targets.randomElement() else { return }
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            look = CGSize(width: choice.0, height: choice.1)
            tilt = choice.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { [weak self] in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                self?.look = .zero
                self?.tilt = 0.0
            }
        }
    }
}

