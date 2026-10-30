import SwiftUI
import AppKit

// MARK: - Vector Native Spider-Man Mask Eye Shape
public struct SpiderEyeShape: Shape {
    public var isRightEye: Bool = false
    public var eyelidClose: CGFloat = 0.0 // 0.0 (wide open) to 1.0 (closed)
    public var squint: CGFloat = 0.0      // 0.0 (normal) to 1.0 (squinting fierce)
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(eyelidClose, squint) }
        set {
            eyelidClose = newValue.first
            squint = newValue.second
        }
    }
    
    public init(isRightEye: Bool = false, eyelidClose: CGFloat = 0.0, squint: CGFloat = 0.0) {
        self.isRightEye = isRightEye
        self.eyelidClose = eyelidClose
        self.squint = squint
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Base Spider-Man Eye Geometry (Left Eye perspective)
        let topOuter = CGPoint(x: w * 0.96, y: h * (0.08 + 0.50 * eyelidClose + 0.15 * squint))
        let topInner = CGPoint(x: w * 0.10, y: h * (0.35 + 0.40 * eyelidClose + 0.20 * squint))
        let topControl = CGPoint(x: w * 0.55, y: h * (0.12 + 0.65 * eyelidClose + 0.25 * squint))
        
        let bottomOuter = CGPoint(x: w * 0.96, y: h * (0.12 + 0.48 * eyelidClose))
        let bottomInner = CGPoint(x: w * 0.05, y: h * (0.68 - 0.15 * squint))
        let bottomControl = CGPoint(x: w * 0.50, y: h * (0.98 - 0.25 * squint))
        
        path.move(to: topOuter)
        path.addQuadCurve(to: topInner, control: topControl)
        path.addLine(to: bottomInner)
        path.addQuadCurve(to: bottomOuter, control: bottomControl)
        path.closeSubpath()
        
        if isRightEye {
            let transform = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -w, y: 0)
            return path.applying(transform)
        }
        return path
    }
}

// MARK: - Single Spider Eye View with Inset & Border
public struct SpiderSingleEyeView: View {
    public let isRightEye: Bool
    public var eyelidClose: CGFloat
    public var squint: CGFloat
    
    public init(isRightEye: Bool, eyelidClose: CGFloat, squint: CGFloat) {
        self.isRightEye = isRightEye
        self.eyelidClose = eyelidClose
        self.squint = squint
    }
    
    public var body: some View {
        ZStack {
            // 1. Black outer contour
            SpiderEyeShape(isRightEye: isRightEye, eyelidClose: eyelidClose, squint: squint)
                .stroke(Color.black.opacity(0.92), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            
            // 2. White lens fill with depth
            SpiderEyeShape(isRightEye: isRightEye, eyelidClose: eyelidClose, squint: squint)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.93, green: 0.95, blue: 0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(0.7)
        }
        .frame(width: 14, height: 18)
    }
}

