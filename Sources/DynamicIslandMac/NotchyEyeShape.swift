import SwiftUI
import AppKit

// MARK: - Vector Native Notchy Mascot Capsule Eye Shape (100% Original NotchFlow Mascot)
public struct NotchyEyeShape: Shape {
    public var isRightEye: Bool = false
    public var eyelidClose: CGFloat = 0.0 // 0.0 (open) to 1.0 (closed slit)
    public var happyArc: CGFloat = 0.0    // 0.0 (neutral) to 1.0 (smiling ^ ^)
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(eyelidClose, happyArc) }
        set {
            eyelidClose = newValue.first
            happyArc = newValue.second
        }
    }
    
    public init(isRightEye: Bool = false, eyelidClose: CGFloat = 0.0, happyArc: CGFloat = 0.0) {
        self.isRightEye = isRightEye
        self.eyelidClose = eyelidClose
        self.happyArc = happyArc
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        if happyArc > 0.05 {
            // Expressive smiling arc (^ ^) when music plays or happy
            let arcPath = Path { p in
                let arcH = h * 0.50 * happyArc
                p.move(to: CGPoint(x: 0.5, y: h * 0.75))
                p.addQuadCurve(to: CGPoint(x: w - 0.5, y: h * 0.75), control: CGPoint(x: w * 0.5, y: h * 0.75 - arcH))
            }
            return arcPath.strokedPath(StrokeStyle(lineWidth: max(2.2, w * 0.40), lineCap: .round, lineJoin: .round))
        }
        
        // Effective height smoothly morphs down to a rounded slit on blink (100% symmetrical)
        let currentH = max(2.5, h * (1.0 - 0.82 * eyelidClose))
        let yOffset = (h - currentH) * 0.5
        
        let capsuleRect = CGRect(x: 0, y: yOffset, width: w, height: currentH)
        let cornerRadius = min(w, currentH) * 0.5
        path.addRoundedRect(in: capsuleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
        
        return path
    }
}

// MARK: - Single Notchy Eye View (Symmetrical Geometry)
public struct NotchySingleEyeView: View {
    public let isRightEye: Bool
    public var eyelidClose: CGFloat
    public var happyArc: CGFloat
    
    public init(isRightEye: Bool = false, eyelidClose: CGFloat = 0.0, happyArc: CGFloat = 0.0) {
        self.isRightEye = isRightEye
        self.eyelidClose = eyelidClose
        self.happyArc = happyArc
    }
    
    public var body: some View {
        ZStack {
            NotchyEyeShape(isRightEye: isRightEye, eyelidClose: eyelidClose, happyArc: happyArc)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.94, green: 0.96, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.white.opacity(0.35), radius: 1.5, x: 0, y: 0)
        }
        .frame(width: 6.5, height: 13.5)
    }
}

// MARK: - Authentic Notchy Living Mascot Eyes View (2-Minute Idle Sensor & Symmetrical Motion)
public struct NotchyMascotEyesView: View {
    @ObservedObject var state: IslandState
    
    @State private var leftEyelidClose: CGFloat = 0.0
    @State private var rightEyelidClose: CGFloat = 0.0
    @State private var happyArcAmount: CGFloat = 0.0
    @State private var lookOffsetX: CGFloat = 0
    @State private var lookOffsetY: CGFloat = 0
    @State private var lookTilt: Double = 0
    @State private var breathScale: CGFloat = 1.0
    
    // Pulse loop (fires every 3.0s to check mouse idle & run state machine)
    private let actionTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: 4.0) {
            NotchySingleEyeView(isRightEye: false, eyelidClose: leftEyelidClose, happyArc: happyArcAmount)
                .scaleEffect(breathScale, anchor: .center)
                .rotationEffect(.degrees(lookTilt))
            
            NotchySingleEyeView(isRightEye: true, eyelidClose: rightEyelidClose, happyArc: happyArcAmount)
                .scaleEffect(breathScale, anchor: .center)
                .rotationEffect(.degrees(lookTilt))
        }
        .offset(x: lookOffsetX, y: lookOffsetY)
        .onReceive(actionTimer) { _ in
            triggerOrganicAction()
        }
    }
    
    private func triggerOrganicAction() {
        guard state.mode == .compact && !state.isPlaying else { return }
        
        // Native macOS Hardware Event Idle Sensor (0% CPU cost)
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let isUserAFK = idleSeconds >= 120.0 // 2 minutes without mouse movement
        
        if !isUserAFK {
            // USER IS ACTIVE: Keep eyes calm and centered, ONLY natural soft blink
            if lookOffsetX != 0 || lookOffsetY != 0 || lookTilt != 0 {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                    lookOffsetX = 0
                    lookOffsetY = 0
                    lookTilt = 0
                }
            }
            
            let roll = Int.random(in: 1...100)
            if roll <= 45 {
                performBlink()
            } else if roll <= 60 {
                performDoubleBlink()
            }
        } else {
            // USER IDLE >= 2 MINUTES: Notchy enters curious exploration (looking left/right, glancing around)
            withAnimation(.easeInOut(duration: 0.45)) {
                breathScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    self.breathScale = 1.0
                }
            }
            
            let roll = Int.random(in: 1...100)
            if roll <= 45 {
                performGlance() // Look left / right with subtle tilt
            } else if roll <= 75 {
                performBlink()
            } else if roll <= 90 {
                performDoubleBlink()
            } else {
                performHappyArc()
            }
        }
    }
    
    // Perfectly symmetrical blink: both eyelids close and open identically
    private func performBlink() {
        withAnimation(.easeIn(duration: 0.09)) {
            leftEyelidClose = 1.0
            rightEyelidClose = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
                self.leftEyelidClose = 0.0
                self.rightEyelidClose = 0.0
            }
        }
    }
    
    private func performDoubleBlink() {
        withAnimation(.easeIn(duration: 0.08)) {
            leftEyelidClose = 1.0
            rightEyelidClose = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.08)) {
                self.leftEyelidClose = 0.0
                self.rightEyelidClose = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.easeIn(duration: 0.08)) {
                    self.leftEyelidClose = 1.0
                    self.rightEyelidClose = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
                        self.leftEyelidClose = 0.0
                        self.rightEyelidClose = 0.0
                    }
                }
            }
        }
    }
    
    private func performGlance() {
        let targets: [(CGFloat, CGFloat, Double)] = [
            (2.2, 0.2, 2.0),
            (-2.2, 0.2, -2.0),
            (0.0, 1.0, 0.0),
            (1.6, -0.5, 1.0)
        ]
        guard let choice = targets.randomElement() else { return }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.70)) {
            lookOffsetX = choice.0
            lookOffsetY = choice.1
            lookTilt = choice.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self.lookOffsetX = 0
                self.lookOffsetY = 0
                self.lookTilt = 0
            }
        }
    }
    
    private func performHappyArc() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            happyArcAmount = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                self.happyArcAmount = 0.0
            }
        }
    }
}

// Backward compatibility aliases
public typealias MascotEyesView = NotchyMascotEyesView
