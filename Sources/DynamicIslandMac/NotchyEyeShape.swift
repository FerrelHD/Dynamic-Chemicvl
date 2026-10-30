import SwiftUI
import AppKit

// MARK: - Smile Arc Shape (Expressive curved smile for music / happiness)
public struct SmileArc: Shape {
    public init() {}
    
    public func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.midX, y: r.minY - r.height * 0.4))
        return p
    }
}

// MARK: - Native Yellow Circle Emoji Mascot View (White Oval Eyes)
public struct MascotView: View {
    @ObservedObject public var model: MascotModel
    public var size: CGFloat = 20

    // Exact proportions from user reference design
    private let eyeW: CGFloat = 0.16
    private let eyeH: CGFloat = 0.30
    private let eyeGap: CGFloat = 0.42   // center-to-center distance
    private let eyeLift: CGFloat = 0.06  // eyes lifted 6% above vertical center for curious expression

    // White eye ink with crisp contrast against yellow face and jet-black notch
    private let eyeColor = Color.white

    public init(model: MascotModel, size: CGFloat = 20) {
        self.model = model
        self.size = size
    }

    public var body: some View {
        ZStack {
            wavingHand
            face

            // Symmetrical eyes (supporting independent winking & sleeping)
            ZStack {
                eyeView(openness: model.leftOpenness).offset(x: -size * eyeGap / 2)
                eyeView(openness: model.rightOpenness).offset(x:  size * eyeGap / 2)
            }
            .offset(
                x: model.look.width,
                y: model.look.height - size * eyeLift
            )
        }
        .frame(width: size, height: size)
        .scaleEffect(model.mascotScale)
        .rotationEffect(.degrees(model.tilt))
    }
    
    // Waving Hand Mitten / Paw (Senior Architectural Design: anchor .bottomLeading, 12x15pt at Retina)
    private var wavingHand: some View {
        ZStack(alignment: .bottomLeading) {
            // Palm / arm body
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.90, blue: 0.38),
                            Color(red: 0.98, green: 0.72, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.52, height: size * 0.72)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                )
                // Cute thumb protrusion on the inner-left of the paw
                .overlay(
                    Circle()
                        .fill(Color(red: 1.0, green: 0.86, blue: 0.30))
                        .frame(width: size * 0.26, height: size * 0.26)
                        .offset(x: -size * 0.14, y: -size * 0.08),
                    alignment: .center
                )
        }
        .scaleEffect(model.handScale, anchor: .bottomLeading)
        .rotationEffect(.degrees(model.handAngle), anchor: .bottomLeading)
        .offset(x: size * 0.38, y: -size * 0.14)
    }

    private var glowMultiplier: Double {
        let base = IslandState.shared.mascotGlowIntensity
        return min(1.5, base + Double(model.glowPulse) * 0.5)
    }

    // ponytail: clean radiant 3D yellow base without murky brown shadow or bottom banding
    private var face: some View {
        ZStack {
            // 1. Radiant 3D Spherical Yellow Base (Warm, bright, zero murky brown shadow)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.70), // Crisp sunny highlight point
                            Color(red: 1.0, green: 0.84, blue: 0.22), // Pure vibrant emoji yellow body
                            Color(red: 0.98, green: 0.72, blue: 0.15)  // Warm bright golden edge (clean & cheerful)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.26),
                        startRadius: 0,
                        endRadius: size * 0.70
                    )
                )
            
            // 2. Glossy Specular Crescent Highlight (Glass reflection at top-left)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.10),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.58, height: size * 0.28)
                .offset(x: -size * 0.04, y: -size * 0.26)
                .rotationEffect(.degrees(-6))
            
            // 3. Subtle Outer Glass Rim Stroke (Pure clean light, zero black tint)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.48),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.5, size * 0.035)
                )
        }
        // Dual-layer golden bloom glow (Edge bloom + Outer ambient aura, customizable)
        .shadow(
            color: Color(red: 1.0, green: 0.82, blue: 0.20).opacity(min(1.0, 0.90 * glowMultiplier)),
            radius: max(0.5, 3.0 * CGFloat(glowMultiplier)),
            x: 0,
            y: 0
        )
        .shadow(
            color: Color(red: 1.0, green: 0.82, blue: 0.20).opacity(min(0.85, 0.60 * glowMultiplier)),
            radius: max(1.0, 7.5 * CGFloat(glowMultiplier)),
            x: 0,
            y: 0
        )
    }

    private func eyeView(openness: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(eyeColor)
                .frame(width: size * eyeW, height: size * eyeH)
                .scaleEffect(y: max(0.08, openness), anchor: .center)
                .opacity(Double(1.0 - model.smile))
                .shadow(color: Color.white.opacity(0.40), radius: 0.75, x: 0, y: 0)

            SmileArc()
                .stroke(eyeColor, style: StrokeStyle(lineWidth: max(1.4, size * 0.07), lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.09)
                .opacity(Double(model.smile))
                .shadow(color: Color.white.opacity(0.40), radius: 0.75, x: 0, y: 0)
        }
    }
}

// MARK: - Mascot Live Preview View
public struct MascotPreview: View {
    @ObservedObject public var model: MascotModel
    
    public init(model: MascotModel) {
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                MascotView(model: model, size: 20)
                Text("Notch (20pt)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(spacing: 6) {
                MascotView(model: model, size: 54)
                Text("Living (54pt)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.50))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Compatibility Bridge
public struct NotchyMascotEyesView: View {
    @ObservedObject var state: IslandState
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    public var body: some View {
        MascotView(model: state.mascotModel, size: 20)
    }
}

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
        Capsule()
            .fill(Color.white)
            .frame(width: 3.5, height: 7.0)
    }
}

public typealias MascotEyesView = NotchyMascotEyesView
