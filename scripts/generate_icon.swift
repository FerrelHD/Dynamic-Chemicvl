import Cocoa
import CoreGraphics

// NotchFlow App Icon Generator (macOS Standard Squircle 1024x1024)
// Supports Variant 1 (Hardware Notch) & Variant 2 (Floating Island Pill)

let variant: Int = {
    if CommandLine.arguments.count > 2, let v = Int(CommandLine.arguments[2]) {
        return v
    }
    return 2 // Default: Variant 2 (Floating Island Pill)
}()

let outputPath: String = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon1024.png"

let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil,
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Failed to initialize CGContext")
}

let rect = CGRect(origin: .zero, size: size)
let inset: CGFloat = 100
let squircleRect = rect.insetBy(dx: inset, dy: inset) // 824 x 824
let squircleCornerRadius: CGFloat = 184
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: squircleCornerRadius, cornerHeight: squircleCornerRadius, transform: nil)

// Layer 1: macOS Dock Dual Drop Shadows
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -26), blur: 50, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.58))
context.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
context.addPath(squirclePath)
context.fillPath()
context.restoreGState()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 16, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.38))
context.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
context.addPath(squirclePath)
context.fillPath()
context.restoreGState()

// Clip interior drawing to squircle
context.saveGState()
context.addPath(squirclePath)
context.clip()

// Layer 2: Background Gradient (Deep Space Black to Dark Titanium Slate)
let bgColors = [
    CGColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1.0),
    CGColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0),
    CGColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0)
] as CFArray
if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.45, 1.0]) {
    context.drawLinearGradient(bgGrad,
                               start: CGPoint(x: 512, y: squircleRect.maxY),
                               end: CGPoint(x: 512, y: squircleRect.minY),
                               options: [])
}

func drawNotchyMascot(center: CGPoint, radius: CGFloat) {
    // 3D Spherical Radial Gradient (Sunlight Gold)
    let sunColors = [
        CGColor(red: 1.0, green: 0.98, blue: 0.74, alpha: 1.0),
        CGColor(red: 1.0, green: 0.84, blue: 0.22, alpha: 1.0),
        CGColor(red: 0.96, green: 0.66, blue: 0.10, alpha: 1.0)
    ] as CFArray
    if let sunGrad = CGGradient(colorsSpace: colorSpace, colors: sunColors, locations: [0.0, 0.52, 1.0]) {
        context.saveGState()
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.clip()
        let lightCenter = CGPoint(x: center.x - radius * 0.32, y: center.y + radius * 0.32)
        context.drawRadialGradient(sunGrad, startCenter: lightCenter, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        
        // Specular Reflection
        let specRect = CGRect(x: center.x - radius * 0.65, y: center.y + radius * 0.15, width: radius * 1.15, height: radius * 0.55)
        let specColors = [
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75),
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15),
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
        ] as CFArray
        if let specGrad = CGGradient(colorsSpace: colorSpace, colors: specColors, locations: [0.0, 0.45, 1.0]) {
            context.addEllipse(in: specRect)
            context.clip()
            context.drawLinearGradient(specGrad, start: CGPoint(x: specRect.midX, y: specRect.maxY), end: CGPoint(x: specRect.midX, y: specRect.minY), options: [])
        }
        context.restoreGState()
    }

    // Mascot Rim Stroke
    context.saveGState()
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.38))
    context.setLineWidth(2.0)
    context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    context.strokePath()
    context.restoreGState()

    // White Oval Eyes
    let eyeW = radius * 0.21
    let eyeH = radius * 0.43
    let eyeGap = radius * 0.42
    let eyeY = center.y - (radius * 0.04)
    let leftEyeRect = CGRect(x: center.x - eyeGap - (eyeW / 2.0), y: eyeY - (eyeH / 2.0), width: eyeW, height: eyeH)
    let rightEyeRect = CGRect(x: center.x + eyeGap - (eyeW / 2.0), y: eyeY - (eyeH / 2.0), width: eyeW, height: eyeH)

    for eyeRect in [leftEyeRect, rightEyeRect] {
        let eyePath = CGPath(roundedRect: eyeRect, cornerWidth: eyeW / 2.0, cornerHeight: eyeW / 2.0, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 4, color: CGColor(red: 0.55, green: 0.35, blue: 0.05, alpha: 0.45))
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.addPath(eyePath)
        context.fillPath()
        context.restoreGState()
        
        let twinkleRect = CGRect(x: eyeRect.midX - (eyeW * 0.13), y: eyeRect.maxY - (eyeH * 0.25), width: eyeW * 0.26, height: eyeW * 0.26)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fillEllipse(in: twinkleRect)
    }

    // Gentle Smile Arc
    let smilePath = CGMutablePath()
    let smileCenter = CGPoint(x: center.x, y: center.y - (radius * 0.35))
    let smileW = radius * 0.28
    smilePath.move(to: CGPoint(x: smileCenter.x - smileW / 2.0, y: smileCenter.y + 4))
    smilePath.addQuadCurve(to: CGPoint(x: smileCenter.x + smileW / 2.0, y: smileCenter.y + 4), control: CGPoint(x: smileCenter.x, y: smileCenter.y - 6))
    context.saveGState()
    context.setStrokeColor(CGColor(red: 0.72, green: 0.46, blue: 0.08, alpha: 0.80))
    context.setLineWidth(max(2.5, radius * 0.035))
    context.setLineCap(.round)
    context.addPath(smilePath)
    context.strokePath()
    context.restoreGState()
}

if variant == 1 {
    // VARIANT 1: The Iconic Hardware Notch Bezel with Notchy + Fluid Ambient Sound Wave
    let auraCenter = CGPoint(x: 512, y: squircleRect.maxY - 140)
    let auraColors = [
        CGColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 0.28),
        CGColor(red: 0.95, green: 0.30, blue: 0.65, alpha: 0.16),
        CGColor(red: 0.20, green: 0.50, blue: 1.0, alpha: 0.08),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let auraGrad = CGGradient(colorsSpace: colorSpace, colors: auraColors, locations: [0.0, 0.40, 0.75, 1.0]) {
        context.drawRadialGradient(auraGrad, startCenter: auraCenter, startRadius: 0, endCenter: auraCenter, endRadius: 520, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    // Hardware Notch Shape
    let notchW: CGFloat = 560
    let notchH: CGFloat = 265
    let notchTopY = squircleRect.maxY
    let notchBottomY = notchTopY - notchH
    let notchMinX = 512 - (notchW / 2.0)
    let notchMaxX = 512 + (notchW / 2.0)
    let earR: CGFloat = 34
    let bottomCornerR: CGFloat = 52

    let notchPath = CGMutablePath()
    notchPath.move(to: CGPoint(x: notchMinX - earR, y: notchTopY))
    notchPath.addQuadCurve(to: CGPoint(x: notchMinX, y: notchTopY - earR), control: CGPoint(x: notchMinX, y: notchTopY))
    notchPath.addLine(to: CGPoint(x: notchMinX, y: notchBottomY + bottomCornerR))
    notchPath.addArc(tangent1End: CGPoint(x: notchMinX, y: notchBottomY),
                     tangent2End: CGPoint(x: notchMinX + bottomCornerR, y: notchBottomY),
                     radius: bottomCornerR)
    notchPath.addLine(to: CGPoint(x: notchMaxX - bottomCornerR, y: notchBottomY))
    notchPath.addArc(tangent1End: CGPoint(x: notchMaxX, y: notchBottomY),
                     tangent2End: CGPoint(x: notchMaxX, y: notchBottomY + bottomCornerR),
                     radius: bottomCornerR)
    notchPath.addLine(to: CGPoint(x: notchMaxX, y: notchTopY - earR))
    notchPath.addQuadCurve(to: CGPoint(x: notchMaxX + earR, y: notchTopY), control: CGPoint(x: notchMaxX, y: notchTopY))
    notchPath.closeSubpath()

    // Notch Drop Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 38, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.88))
    context.setFillColor(CGColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1.0))
    context.addPath(notchPath)
    context.fillPath()
    context.restoreGState()

    // Notch Rim Highlight
    context.saveGState()
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.16))
    context.setLineWidth(2.5)
    context.addPath(notchPath)
    context.strokePath()
    context.restoreGState()

    // Notchy Mascot Head
    let mascotCenter = CGPoint(x: 512, y: notchBottomY + 128)
    drawNotchyMascot(center: mascotCenter, radius: 90)

    // Camera Aperture & Green LED
    let camCenter = CGPoint(x: notchMinX + 54, y: mascotCenter.y + 8)
    let camRect = CGRect(x: camCenter.x - 16, y: camCenter.y - 16, width: 32, height: 32)
    context.setFillColor(CGColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0))
    context.fillEllipse(in: camRect)
    context.setStrokeColor(CGColor(red: 0.20, green: 0.22, blue: 0.30, alpha: 0.6))
    context.setLineWidth(1.5)
    context.strokeEllipse(in: camRect)
    let lensInner = camRect.insetBy(dx: 4.5, dy: 4.5)
    context.setFillColor(CGColor(red: 0.10, green: 0.16, blue: 0.32, alpha: 0.85))
    context.fillEllipse(in: lensInner)

    let greenDotCenter = CGPoint(x: notchMaxX - 54, y: mascotCenter.y + 8)
    let greenRect = CGRect(x: greenDotCenter.x - 7, y: greenDotCenter.y - 7, width: 14, height: 14)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 12, color: CGColor(red: 0.18, green: 0.90, blue: 0.35, alpha: 0.90))
    context.setFillColor(CGColor(red: 0.20, green: 0.92, blue: 0.40, alpha: 1.0))
    context.fillEllipse(in: greenRect)
    context.restoreGState()

    // Fluid Audio Waveform Floating Elegantly Below the Notch
    let waveY: CGFloat = 380
    let heights: [CGFloat] = [18, 36, 68, 108, 140, 185, 125, 160, 88, 48, 22]
    let barW: CGFloat = 11
    let barGap: CGFloat = 14
    let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * barGap
    var curX = 512 - (totalW / 2.0)
    
    for (i, h) in heights.enumerated() {
        let bRect = CGRect(x: curX, y: waveY - h / 2.0, width: barW, height: h)
        let bPath = CGPath(roundedRect: bRect, cornerWidth: barW / 2.0, cornerHeight: barW / 2.0, transform: nil)
        let progress = CGFloat(i) / CGFloat(heights.count - 1)
        
        let r = 1.0 - progress * 0.45
        let g = 0.55 + progress * 0.20
        let b = 0.25 + progress * 0.70
        
        context.saveGState()
        context.setShadow(offset: .zero, blur: 8, color: CGColor(red: r, green: g, blue: b, alpha: 0.35))
        context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 0.88))
        context.addPath(bPath)
        context.fillPath()
        context.restoreGState()
        
        curX += barW + barGap
    }

    // Minimal Apple Page Dots Bar
    let dotsY: CGFloat = squircleRect.minY + 95
    let activeW: CGFloat = 32
    let activeH: CGFloat = 7
    let dotSz: CGFloat = 7
    let dotSp: CGFloat = 12
    let dotsTotalW = activeW + (4 * dotSz) + (4 * dotSp)
    var dotX = 512 - (dotsTotalW / 2.0)

    for idx in 0..<5 {
        if idx == 2 {
            let pR = CGRect(x: dotX, y: dotsY - activeH / 2.0, width: activeW, height: activeH)
            let pPath = CGPath(roundedRect: pR, cornerWidth: activeH / 2.0, cornerHeight: activeH / 2.0, transform: nil)
            context.saveGState()
            context.setShadow(offset: .zero, blur: 6, color: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.45))
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
            context.addPath(pPath)
            context.fillPath()
            context.restoreGState()
            dotX += activeW + dotSp
        } else {
            let dR = CGRect(x: dotX, y: dotsY - dotSz / 2.0, width: dotSz, height: dotSz)
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
            context.fillEllipse(in: dR)
            dotX += dotSz + dotSp
        }
    }
} else {
    // VARIANT 2: The Large Centered Island with Notchy & Live Activity Telemetry
    let pillW: CGFloat = 660
    let pillH: CGFloat = 280
    let pillCenter = CGPoint(x: 512, y: 530)
    let pillRect = CGRect(x: pillCenter.x - pillW / 2.0, y: pillCenter.y - pillH / 2.0, width: pillW, height: pillH)
    let pillCornerR: CGFloat = pillH / 2.0
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillCornerR, cornerHeight: pillCornerR, transform: nil)

    // Ambient Aura Glow behind Island
    let auraColors = [
        CGColor(red: 0.42, green: 0.22, blue: 0.75, alpha: 0.25),
        CGColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 0.12),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let auraGrad = CGGradient(colorsSpace: colorSpace, colors: auraColors, locations: [0.0, 0.50, 1.0]) {
        context.drawRadialGradient(auraGrad, startCenter: pillCenter, startRadius: 40, endCenter: pillCenter, endRadius: 420, options: [])
    }

    // Pill Drop Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -22), blur: 44, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.92))
    context.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0))
    context.addPath(pillPath)
    context.fillPath()
    context.restoreGState()

    // Pill Stroke (Subtle Rim Light)
    context.saveGState()
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.16))
    context.setLineWidth(3.0)
    context.addPath(pillPath)
    context.strokePath()
    context.restoreGState()

    // 1. Notchy Mascot inside Left Side of Pill
    let mascotCenter = CGPoint(x: pillRect.minX + 138, y: pillCenter.y)
    drawNotchyMascot(center: mascotCenter, radius: 98)

    // 2. Audio Visualizer Spectrum in Middle
    let waveCenterX = pillCenter.x + 105
    let heights: [CGFloat] = [32, 54, 96, 138, 172, 115, 148, 86, 62, 36]
    let barW: CGFloat = 12
    let barGap: CGFloat = 13
    let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * barGap
    var curX = waveCenterX - (totalW / 2.0)

    for (i, h) in heights.enumerated() {
        let bRect = CGRect(x: curX, y: pillCenter.y - h / 2.0, width: barW, height: h)
        let bPath = CGPath(roundedRect: bRect, cornerWidth: barW / 2.0, cornerHeight: barW / 2.0, transform: nil)
        let progress = CGFloat(i) / CGFloat(heights.count - 1)
        
        // Cyber Neon Palette: Magenta Pink to Electric Sky Cyan
        let r = 0.95 - progress * 0.60
        let g = 0.45 + progress * 0.40
        let b = 0.75 + progress * 0.25
        
        context.saveGState()
        context.setShadow(offset: .zero, blur: 10, color: CGColor(red: r, green: g, blue: b, alpha: 0.45))
        context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 0.95))
        context.addPath(bPath)
        context.fillPath()
        context.restoreGState()
        
        curX += barW + barGap
    }

    // 3. Green Status LED on Right Side
    let greenDotCenter = CGPoint(x: pillRect.maxX - 48, y: pillCenter.y)
    let greenRect = CGRect(x: greenDotCenter.x - 7.5, y: greenDotCenter.y - 7.5, width: 15, height: 15)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 14, color: CGColor(red: 0.18, green: 0.90, blue: 0.35, alpha: 0.95))
    context.setFillColor(CGColor(red: 0.20, green: 0.94, blue: 0.42, alpha: 1.0))
    context.fillEllipse(in: greenRect)
    context.restoreGState()
}

// Outer Squircle Inner Rim Highlight
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.14))
context.setLineWidth(3.0)
context.addPath(squirclePath)
context.strokePath()

context.restoreGState()

guard let image = context.makeImage() else { fatalError("Failed to render CGImage") }
let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Failed to create image destination")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Successfully generated icon variant \(variant) at \(outputPath)")
