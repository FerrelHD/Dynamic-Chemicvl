import SwiftUI
import AppKit
import Combine

// MARK: - Mascot Living Model (State Machine & Native Hardware Idle Sensor)
public class MascotModel: ObservableObject {
    @Published public var look: CGSize = .zero
    @Published public var tilt: Double = 0.0
    @Published public var leftOpenness: CGFloat = 1.0
    @Published public var rightOpenness: CGFloat = 1.0
    @Published public var openness: CGFloat = 1.0 { // backward-compatible sync
        didSet {
            leftOpenness = openness
            rightOpenness = openness
        }
    }
    @Published public var smile: CGFloat = 0.0    // 0.0 (oval capsule) to 1.0 (smiling arc)
    @Published public var isHappy: Bool = false
    @Published public var isSleeping: Bool = false
    @Published public var glowPulse: CGFloat = 0.0
    
    // Greeting Phase State Machine (Structured Linear Sequencer)
    public enum GreetingPhase: Equatable {
        case dormant
        case popOut
        case waving
        case popIn
        case slideToClock
    }
    
    @Published public var greetingPhase: GreetingPhase = .dormant
    @Published public var mascotScale: CGFloat = 1.0
    @Published public var handScale: CGFloat = 0.0
    @Published public var handAngle: Double = 0.0
    @Published public var mascotCenterOffset: CGFloat = 0.0
    @Published public var clockScale: CGFloat = 1.0
    @Published public var clockOpacity: Double = 1.0
    
    public var isGreetingActive: Bool {
        greetingPhase != .dormant
    }
    
    private var greetingTask: Task<Void, Never>?
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
        guard !isGreetingActive else { return }
        
        // Native macOS Hardware Event Idle Sensor (checks seconds since last mouse move)
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        
        // 1. AFK >= 2 minutes: Enter peaceful sleep mode (💤)
        if idleSeconds >= 120.0 {
            if !isSleeping {
                enterSleep()
            }
            return
        } else if isSleeping {
            // User moved mouse/trackpad after sleeping -> wake up with quick double-blink!
            wakeUp()
            return
        }
        
        // 2. USER ACTIVE (< 15s since last move): Keep eyes forward, random blink or wink
        if idleSeconds < 15.0 {
            if look != .zero || tilt != 0 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    look = .zero
                    tilt = 0.0
                }
            }
            
            let roll = Int.random(in: 1...100)
            if roll <= 40 {
                performBlink()
            } else if roll <= 55 {
                performDoubleBlink()
            } else if roll <= 68 {
                performWink() // Playful wink 😉
            }
        } else {
            // 3. USER IDLE (15s to 120s): Curious glancing around
            let roll = Int.random(in: 1...100)
            if roll <= 45 {
                performGlance()
            } else if roll <= 75 {
                performBlink()
            } else if roll <= 85 {
                performWink()
            } else {
                performDoubleBlink()
            }
        }
    }
    
    public func performBlink() {
        guard !isSleeping else { return }
        withAnimation(.easeIn(duration: 0.09)) {
            leftOpenness = 0.0
            rightOpenness = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
            guard let self = self, !self.isSleeping else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                self.leftOpenness = 1.0
                self.rightOpenness = 1.0
            }
        }
    }
    
    public func performDoubleBlink() {
        guard !isSleeping else { return }
        withAnimation(.easeIn(duration: 0.08)) {
            leftOpenness = 0.0
            rightOpenness = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self = self, !self.isSleeping else { return }
            withAnimation(.easeOut(duration: 0.08)) {
                self.leftOpenness = 1.0
                self.rightOpenness = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                guard let self = self, !self.isSleeping else { return }
                withAnimation(.easeIn(duration: 0.08)) {
                    self.leftOpenness = 0.0
                    self.rightOpenness = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
                    guard let self = self, !self.isSleeping else { return }
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                        self.leftOpenness = 1.0
                        self.rightOpenness = 1.0
                    }
                }
            }
        }
    }
    
    public func performWink() {
        guard !isSleeping else { return }
        let winkLeft = Bool.random()
        withAnimation(.easeIn(duration: 0.08)) {
            if winkLeft { leftOpenness = 0.0 } else { rightOpenness = 0.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self = self, !self.isSleeping else { return }
            withAnimation(.spring(response: 0.20, dampingFraction: 0.75)) {
                self.leftOpenness = 1.0
                self.rightOpenness = 1.0
            }
        }
    }
    
    public func enterSleep() {
        isSleeping = true
        withAnimation(.spring(response: 0.65, dampingFraction: 0.80)) {
            leftOpenness = 0.18
            rightOpenness = 0.18
            tilt = 12.0
            look = CGSize(width: 0.8, height: 1.2)
        }
    }
    
    public func wakeUp() {
        isSleeping = false
        withAnimation(.spring(response: 0.22, dampingFraction: 0.70)) {
            tilt = 0.0
            look = .zero
            leftOpenness = 1.0
            rightOpenness = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.performDoubleBlink()
        }
    }
    
    public func glanceTowards(dx: CGFloat, dy: CGFloat) {
        guard !isSleeping else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
            look = CGSize(width: max(-2.5, min(2.5, dx)), height: max(-1.0, min(1.8, dy)))
        }
    }
    
    public func triggerPulse() {
        withAnimation(.easeIn(duration: 0.20)) {
            glowPulse = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            withAnimation(.easeOut(duration: 0.50)) {
                self?.glowPulse = 0.0
            }
        }
    }
    
    public func performGlance() {
        guard !isSleeping else { return }
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
            guard let self = self, !self.isSleeping else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                self.look = .zero
                self.tilt = 0.0
            }
        }
    }
    
    // MARK: - Pre-Greeting Setup (Zero-Flash Instant Start on App Launch)
    public func prepareForInstantGreeting() {
        greetingPhase = .popOut
        mascotScale = 0.05
        mascotCenterOffset = 23.0
        clockScale = 0.001
        clockOpacity = 0.0
        handScale = 0.001
        handAngle = 0.0
        smile = 0.0
        tilt = 0.0
        isSleeping = false
        openness = 1.0
    }
    
    // MARK: - Waving Hand Greeting Sequence (Alur A - Center Morph)
    public func triggerGreetingSequence() {
        greetingTask?.cancel()
        greetingTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // 0. Initial state: Notchy starts at true dead center (+23.0 offset in HStack), clock hidden
            self.prepareForInstantGreeting()
            
            // 1. Pop-out at dead center with bouncy fluid spring (0.35s)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                self.mascotScale = 1.0
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            
            // 2. Extend hand & tilt head with warm smile (0.18s)
            self.greetingPhase = .waving
            withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                self.handScale = 1.0
                self.handAngle = 35.0
                self.tilt = -10.0
                self.smile = 1.0
                self.glowPulse = 0.5
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            
            // 3. Exactly 2 Full Waving Cycles with Double Symmetrical Eye Blink (0.56s)
            // Cycle 1 Left (-15°) + Squint/Blink
            withAnimation(.easeInOut(duration: 0.14)) {
                self.handAngle = -15.0
                self.openness = 0.20
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            if Task.isCancelled { return }
            
            // Cycle 1 Right (+35°) + Eyes open
            withAnimation(.easeInOut(duration: 0.14)) {
                self.handAngle = 35.0
                self.openness = 1.0
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            if Task.isCancelled { return }
            
            // Cycle 2 Left (-15°) + Squint/Blink
            withAnimation(.easeInOut(duration: 0.14)) {
                self.handAngle = -15.0
                self.openness = 0.20
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            if Task.isCancelled { return }
            
            // Cycle 2 Finish neutral (0°) + Eyes open
            withAnimation(.easeInOut(duration: 0.14)) {
                self.handAngle = 0.0
                self.openness = 1.0
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            if Task.isCancelled { return }
            
            // 4. Pop-in: hand folds cleanly inside Notchy (0.18s)
            self.greetingPhase = .popIn
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                self.handScale = 0.001
                self.tilt = 0.0
                self.glowPulse = 0.0
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            
            // 5. Alur A: Notchy glides to left, clock pops in from small to large at default place (0.42s)
            self.greetingPhase = .slideToClock
            withAnimation(.spring(response: 0.40, dampingFraction: 0.72)) {
                self.mascotCenterOffset = 0.0
                self.clockScale = 1.0
                self.clockOpacity = 1.0
                self.smile = 0.0
            }
            try? await Task.sleep(nanoseconds: 420_000_000)
            if Task.isCancelled { return }
            
            // 6. Complete and settle into dormant idle standby
            self.greetingPhase = .dormant
        }
    }
    
    public func cancelGreeting() {
        greetingTask?.cancel()
        greetingTask = nil
        greetingPhase = .dormant
        mascotScale = 1.0
        mascotCenterOffset = 0.0
        clockScale = 1.0
        clockOpacity = 1.0
        handScale = 0.0
        handAngle = 0.0
        tilt = 0.0
        smile = 0.0
        openness = 1.0
        glowPulse = 0.0
    }
}

