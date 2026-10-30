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
            face

            // Symmetrical eyes (moving together inside the yellow circle)
            ZStack {
                eyeView.offset(x: -size * eyeGap / 2)
                eyeView.offset(x:  size * eyeGap / 2)
            }
            .offset(
                x: model.look.width,
                y: model.look.height - size * eyeLift
            )
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(model.tilt))
    }

    private var face: some View {
        ZStack {
            // 1. Base Spherical 3D Radial Lighting (Light Source from top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.65), // Specular light reflection point
                            Color(red: 1.0, green: 0.82, blue: 0.26), // Vibrant emoji yellow body
                            Color(red: 0.95, green: 0.68, blue: 0.12), // Deep golden curvature
                            Color(red: 0.84, green: 0.50, blue: 0.05)  // Warm amber shadow at perimeter
                        ],
                        center: UnitPoint(x: 0.35, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.72
                    )
                )
            
            // 2. Glossy Specular Crescent Highlight (Glass / Aqua shine at top-left)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.68),
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.62, height: size * 0.32)
                .offset(x: -size * 0.04, y: -size * 0.26)
                .rotationEffect(.degrees(-6))
            
            // 3. Subtle Bottom Bounce Light (Ambient reflected light from beneath)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 1.0, green: 0.92, blue: 0.55).opacity(0.40)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.54, height: size * 0.18)
                .offset(y: size * 0.36)
            
            // 4. Subtle Outer Glass Rim Stroke
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.5, size * 0.035)
                )
        }
        .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 1.0)
    }

    private var eyeView: some View {
        ZStack {
            Capsule()
                .fill(eyeColor)
                .frame(width: size * eyeW, height: size * eyeH)
                .scaleEffect(y: max(0.08, model.openness), anchor: .center)
                .opacity(Double(1.0 - model.smile))
                // Micro depth shadow onto the 3D spherical surface
                .shadow(color: Color(red: 0.65, green: 0.38, blue: 0.02).opacity(0.50), radius: 0.75, x: 0, y: 0.75)
                .shadow(color: Color.white.opacity(0.40), radius: 0.75, x: 0, y: 0)

            SmileArc()
                .stroke(eyeColor, style: StrokeStyle(lineWidth: max(1.4, size * 0.07), lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.09)
                .opacity(Double(model.smile))
                .shadow(color: Color(red: 0.65, green: 0.38, blue: 0.02).opacity(0.50), radius: 0.75, x: 0, y: 0.75)
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
