import SwiftUI
import AppKit

// MARK: - Mascot Theme / Color Palette (Procedural 3D Gradient & Bloom)
public enum MascotTheme: String, CaseIterable, Identifiable {
    case sunlight = "Sunlight Gold"
    case silver = "Silver Titanium"
    case cyber = "Cyber Ultraviolet"
    case mint = "Neon Mint"
    case obsidian = "Midnight Stealth"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .sunlight: return "Sunlight"
        case .silver: return "Silver"
        case .cyber: return "Cyber"
        case .mint: return "Mint"
        case .obsidian: return "Stealth"
        }
    }
    
    public var gradientColors: [Color] {
        switch self {
        case .sunlight:
            return [
                Color(red: 1.0, green: 0.98, blue: 0.70), // Crisp sunny highlight point
                Color(red: 1.0, green: 0.84, blue: 0.22), // Pure vibrant emoji yellow body
                Color(red: 0.98, green: 0.72, blue: 0.15)  // Warm bright golden edge
            ]
        case .silver:
            return [
                Color(red: 0.96, green: 0.97, blue: 1.00),
                Color(red: 0.78, green: 0.81, blue: 0.86),
                Color(red: 0.60, green: 0.63, blue: 0.68)
            ]
        case .cyber:
            return [
                Color(red: 0.96, green: 0.58, blue: 1.00),
                Color(red: 0.72, green: 0.22, blue: 0.95),
                Color(red: 0.48, green: 0.08, blue: 0.78)
            ]
        case .mint:
            return [
                Color(red: 0.68, green: 1.00, blue: 0.88),
                Color(red: 0.18, green: 0.88, blue: 0.60),
                Color(red: 0.06, green: 0.62, blue: 0.40)
            ]
        case .obsidian:
            return [
                Color(red: 0.35, green: 0.38, blue: 0.44),
                Color(red: 0.18, green: 0.20, blue: 0.24),
                Color(red: 0.10, green: 0.11, blue: 0.14)
            ]
        }
    }
    
    public var glowColor: Color {
        switch self {
        case .sunlight:
            return Color(red: 1.0, green: 0.82, blue: 0.20)
        case .silver:
            return Color(red: 0.85, green: 0.90, blue: 1.00)
        case .cyber:
            return Color(red: 0.88, green: 0.32, blue: 1.00)
        case .mint:
            return Color(red: 0.20, green: 0.95, blue: 0.65)
        case .obsidian:
            return Color.white.opacity(0.35)
        }
    }
    
    public var eyeColor: Color {
        switch self {
        case .sunlight:
            // Warm soft hazel chestnut brown for authentic 3D emoji contrast
            return Color(red: 0.46, green: 0.30, blue: 0.16)
        case .cyber, .mint, .obsidian:
            return Color.white
        case .silver:
            return Color(red: 0.10, green: 0.12, blue: 0.16)
        }
    }
    
    public var eyeShadowColor: Color {
        switch self {
        case .sunlight:
            return Color(red: 0.28, green: 0.16, blue: 0.08).opacity(0.20)
        case .silver:
            return Color.black.opacity(0.25)
        default:
            return Color.white.opacity(0.40)
        }
    }
}

// MARK: - Mascot Eye Expression Style
public enum MascotEyeStyle: String, CaseIterable, Identifiable {
    case classic = "Classic Oval"
    case arcs = "Kawaii Arcs"
    case dots = "Minimal Dots"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .classic: return "Classic"
        case .arcs: return "Kawaii"
        case .dots: return "Minimal"
        }
    }
}

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

// MARK: - Native Circle Emoji Mascot View (White Oval Eyes)
public struct MascotView: View {
    @ObservedObject public var model: MascotModel
    public var size: CGFloat = 20

    // Exact proportions from user reference design
    private let eyeW: CGFloat = 0.16
    private let eyeH: CGFloat = 0.30
    private let eyeGap: CGFloat = 0.42   // center-to-center distance
    private let eyeLift: CGFloat = 0.06  // eyes lifted 6% above vertical center for curious expression

    public init(model: MascotModel, size: CGFloat = 20) {
        self.model = model
        self.size = size
    }

    private var theme: MascotTheme {
        IslandState.shared.mascotTheme
    }

    private var eyeStyle: MascotEyeStyle {
        IslandState.shared.mascotEyeStyle
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
    
    // Cached 3D Waving Hand Assets per Theme (Pre-rendered for 120Hz zero-overhead fluidity)
    private static var handImageCache: [MascotTheme: NSImage] = [:]
    
    private static let defaultHandImage: NSImage? = {
        if let img = NSImage(named: "MascotHand") { return img }
        if let url = Bundle.main.url(forResource: "MascotHand", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        for path in ["Resources/MascotHand.png", "../Resources/MascotHand.png"] {
            if let img = NSImage(contentsOfFile: path) { return img }
        }
        return nil
    }()

    private func handImage(for theme: MascotTheme) -> NSImage? {
        if let cached = Self.handImageCache[theme] { return cached }
        let assetName: String = {
            switch theme {
            case .sunlight: return "MascotHand"
            case .silver: return "MascotHand_silver"
            case .cyber: return "MascotHand_cyber"
            case .mint: return "MascotHand_mint"
            case .obsidian: return "MascotHand_stealth"
            }
        }()
        
        let loaded: NSImage? = {
            if let img = NSImage(named: assetName) { return img }
            if let url = Bundle.main.url(forResource: assetName, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                return img
            }
            for path in ["Resources/\(assetName).png", "../Resources/\(assetName).png"] {
                if let img = NSImage(contentsOfFile: path) { return img }
            }
            return Self.defaultHandImage
        }()
        
        if let img = loaded {
            Self.handImageCache[theme] = img
        }
        return loaded ?? Self.defaultHandImage
    }

    // MARK: - Waving Hand (3D Mirrored Emoji Asset Hand, Matching Skin Theme)
    private var wavingHand: some View {
        Group {
            if let hand = handImage(for: theme) {
                Image(nsImage: hand)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.78, height: size * 0.78)
                    .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: -0.5, y: 1.0)
            }
        }
        .scaleEffect(model.handScale, anchor: .bottomLeading)
        .rotationEffect(.degrees(model.handAngle), anchor: .bottomLeading)
        .offset(x: size * 0.48, y: -size * 0.22)
    }

    private var glowMultiplier: Double {
        let base = IslandState.shared.mascotGlowIntensity
        return min(1.5, base + Double(model.glowPulse) * 0.5)
    }

    // ponytail: clean radiant 3D procedural base with theme palette & bloom
    private var face: some View {
        ZStack {
            // 1. Radiant 3D Spherical Base
            Circle()
                .fill(
                    RadialGradient(
                        colors: theme.gradientColors,
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
                            Color.white.opacity(theme == .obsidian ? 0.35 : 0.65),
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
        // Dual-layer bloom glow
        .shadow(
            color: theme.glowColor.opacity(min(1.0, 0.90 * glowMultiplier)),
            radius: max(0.5, 3.0 * CGFloat(glowMultiplier)),
            x: 0,
            y: 0
        )
        .shadow(
            color: theme.glowColor.opacity(min(0.85, 0.60 * glowMultiplier)),
            radius: max(1.0, 7.5 * CGFloat(glowMultiplier)),
            x: 0,
            y: 0
        )
    }

    private func eyeView(openness: CGFloat) -> some View {
        let currentEyeColor = theme.eyeColor
        let currentEyeShadow = theme.eyeShadowColor

        return ZStack {
            switch eyeStyle {
            case .classic:
                Capsule()
                    .fill(currentEyeColor)
                    .frame(width: size * eyeW, height: size * eyeH)
                    .scaleEffect(y: max(0.08, openness), anchor: .center)
                    .opacity(Double(1.0 - model.smile))
                    .shadow(color: currentEyeShadow, radius: 0.75, x: 0, y: 0)

                SmileArc()
                    .stroke(currentEyeColor, style: StrokeStyle(lineWidth: max(1.4, size * 0.07), lineCap: .round))
                    .frame(width: size * 0.18, height: size * 0.09)
                    .opacity(Double(model.smile))
                    .shadow(color: currentEyeShadow, radius: 0.75, x: 0, y: 0)
                
            case .arcs:
                SmileArc()
                    .stroke(currentEyeColor, style: StrokeStyle(lineWidth: max(1.4, size * 0.075), lineCap: .round))
                    .frame(width: size * 0.18, height: size * 0.09)
                    .scaleEffect(y: max(0.20, openness), anchor: .center)
                    .shadow(color: currentEyeShadow, radius: 0.75, x: 0, y: 0)
                
            case .dots:
                Circle()
                    .fill(currentEyeColor)
                    .frame(width: size * eyeW, height: size * eyeW)
                    .scaleEffect(y: max(0.12, openness), anchor: .center)
                    .shadow(color: currentEyeShadow, radius: 0.75, x: 0, y: 0)
            }
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
