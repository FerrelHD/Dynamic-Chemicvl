import Cocoa
import CoreGraphics

// NotchFlow App Icon Generator (macOS Standard Squircle 1024x1024)
// Design: Solid Matte Dark Canvas + Centered Dynamic Island + Kawaii Notchy (⌒ ⌒) + Digital Clock (09:41) + Status LED

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
context.setShadow(offset: CGSize(width: 0, height: -26), blur: 50, color: CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 0.55))
context.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
context.addPath(squirclePath)
context.fillPath()
context.restoreGState()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 16, color: CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 0.35))
context.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
context.addPath(squirclePath)
context.fillPath()
context.restoreGState()

// Clip interior drawing to squircle
context.saveGState()
context.addPath(squirclePath)
context.clip()

// Layer 2: SOLID Matte Dark Canvas (No Gradient, Pure Clean Matte Dark Slate / Pitch Black)
context.setFillColor(CGColor(red: 0.065, green: 0.075, blue: 0.095, alpha: 1.0))
context.fill(squircleRect)

// Dynamic Island Pill: Centered
let pillW: CGFloat = 660
let pillH: CGFloat = 264
let pillCenter = CGPoint(x: 512, y: 512)
let pillRect = CGRect(x: pillCenter.x - pillW / 2.0, y: pillCenter.y - pillH / 2.0, width: pillW, height: pillH)
let pillCornerR: CGFloat = pillH / 2.0
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillCornerR, cornerHeight: pillCornerR, transform: nil)

// Pill Drop Shadow
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -16), blur: 36, color: CGColor(red: 0.01, green: 0.01, blue: 0.015, alpha: 0.85))
context.setFillColor(CGColor(red: 0.01, green: 0.01, blue: 0.015, alpha: 1.0))
context.addPath(pillPath)
context.fillPath()
context.restoreGState()

// Pill Subtle Rim Light
context.saveGState()
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15))
context.setLineWidth(2.5)
context.addPath(pillPath)
context.strokePath()
context.restoreGState()

// 1. Notchy Mascot inside Left Side of Pill
let mascotCenter = CGPoint(x: pillRect.minX + 132, y: pillCenter.y)
let mascotRadius: CGFloat = 92

// 3D Spherical Radial Gradient (Sunlight Gold)
let sunColors = [
    CGColor(red: 1.0, green: 0.98, blue: 0.74, alpha: 1.0),
    CGColor(red: 1.0, green: 0.84, blue: 0.22, alpha: 1.0),
    CGColor(red: 0.96, green: 0.66, blue: 0.10, alpha: 1.0)
] as CFArray
if let sunGrad = CGGradient(colorsSpace: colorSpace, colors: sunColors, locations: [0.0, 0.52, 1.0]) {
    context.saveGState()
    context.addArc(center: mascotCenter, radius: mascotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    context.clip()
    let lightCenter = CGPoint(x: mascotCenter.x - mascotRadius * 0.32, y: mascotCenter.y + mascotRadius * 0.32)
    context.drawRadialGradient(sunGrad, startCenter: lightCenter, startRadius: 0, endCenter: mascotCenter, endRadius: mascotRadius, options: [])
    
    // Specular Reflection
    let specRect = CGRect(x: mascotCenter.x - mascotRadius * 0.65, y: mascotCenter.y + mascotRadius * 0.15, width: mascotRadius * 1.15, height: mascotRadius * 0.55)
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
context.addArc(center: mascotCenter, radius: mascotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
context.strokePath()
context.restoreGState()

// 2. Kawaii Happy Eyes (⌒ ⌒, No Mouth, No Blush)
let eyeSpan: CGFloat = 34
let eyeArcW: CGFloat = 32
let eyeArcH: CGFloat = 20
let eyeBaseY = mascotCenter.y - 2

for sign in [-1.0, 1.0] {
    let eyeCenterX = mascotCenter.x + CGFloat(sign) * eyeSpan
    let leftX = eyeCenterX - eyeArcW / 2.0
    let rightX = eyeCenterX + eyeArcW / 2.0
    let topY = eyeBaseY + eyeArcH
    
    // Upward bulging happy arc ⌒
    let eyePath = CGMutablePath()
    eyePath.move(to: CGPoint(x: leftX, y: eyeBaseY))
    eyePath.addQuadCurve(to: CGPoint(x: rightX, y: eyeBaseY), control: CGPoint(x: eyeCenterX, y: topY + 6))
    
    context.saveGState()
    context.setStrokeColor(CGColor(red: 0.30, green: 0.17, blue: 0.05, alpha: 0.95)) // Warm deep chestnut
    context.setLineWidth(6.5)
    context.setLineCap(.round)
    context.addPath(eyePath)
    context.strokePath()
    context.restoreGState()
}

// 3. Digital Clock "09:41" (Apple Iconic Time) centered between Notchy and LED
let clockStr = "09:41" as CFString
let font = NSFont.monospacedDigitSystemFont(ofSize: 86, weight: .semibold)
let clockAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 1.0)
]
let attrString = CFAttributedStringCreate(nil, clockStr, clockAttributes as CFDictionary)!
let line = CTLineCreateWithAttributedString(attrString)

let clockStartX: CGFloat = pillRect.minX + 296
let clockStartY: CGFloat = pillCenter.y - 30

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
context.textPosition = CGPoint(x: clockStartX, y: clockStartY)
CTLineDraw(line, context)
context.restoreGState()

// 4. Glowing Green Status LED on Far Right
let greenDotCenter = CGPoint(x: pillRect.maxX - 48, y: pillCenter.y)
let greenRect = CGRect(x: greenDotCenter.x - 7.5, y: greenDotCenter.y - 7.5, width: 15, height: 15)
context.saveGState()
context.setShadow(offset: .zero, blur: 14, color: CGColor(red: 0.18, green: 0.90, blue: 0.35, alpha: 0.95))
context.setFillColor(CGColor(red: 0.20, green: 0.94, blue: 0.42, alpha: 1.0))
context.fillEllipse(in: greenRect)
context.restoreGState()

// Outer Squircle Inner Rim Highlight
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12))
context.setLineWidth(2.5)
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
print("Successfully generated icon at \(outputPath)")
