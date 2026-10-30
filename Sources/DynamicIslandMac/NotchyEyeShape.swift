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
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.86, blue: 0.40), // Bright emoji yellow top
                        Color(red: 1.0, green: 0.80, blue: 0.28)  // Warm amber yellow bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color.black.opacity(0.20), radius: 1, x: 0, y: 0.5)
    }

    private var eyeView: some View {
        ZStack {
            Capsule()
                .fill(eyeColor)
                .frame(width: size * eyeW, height: size * eyeH)
                .scaleEffect(y: max(0.08, model.openness), anchor: .center)
                .opacity(Double(1.0 - model.smile))
                .shadow(color: Color.white.opacity(0.35), radius: 1.0, x: 0, y: 0)

            SmileArc()
                .stroke(eyeColor, style: StrokeStyle(lineWidth: max(1.4, size * 0.07), lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.09)
                .opacity(Double(model.smile))
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
