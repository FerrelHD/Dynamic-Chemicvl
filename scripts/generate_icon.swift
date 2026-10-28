import Cocoa
import CoreGraphics

let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil,
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Failed to create CGContext")
}

let rect = CGRect(origin: .zero, size: size)

// Background: macOS squircle inset
let squircleRect = rect.insetBy(dx: 100, dy: 100)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 184, cornerHeight: 184, transform: nil)

// Shadow
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
context.setFillColor(CGColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0))
context.addPath(squirclePath)
context.fillPath()
context.restoreGState()

// Clip to squircle for inner drawing
context.saveGState()
context.addPath(squirclePath)
context.clip()

// Squircle Background Gradient (Obsidian to Midnight Blue)
let gradientColors = [
    CGColor(red: 0.11, green: 0.13, blue: 0.18, alpha: 1.0),
    CGColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
] as CFArray
let gradientLocations: [CGFloat] = [0.0, 1.0]
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
    context.drawLinearGradient(bgGradient,
                               start: CGPoint(x: 512, y: 924),
                               end: CGPoint(x: 512, y: 100),
                               options: [])
}

// Inner subtle glow/border
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15))
context.setLineWidth(4)
context.addPath(squirclePath)
context.strokePath()

// Ambient Aurora Behind the Island
if let auroraGrad = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(red: 1.0, green: 0.22, blue: 0.45, alpha: 0.35),
    CGColor(red: 0.40, green: 0.15, blue: 0.95, alpha: 0.25),
    CGColor(red: 0.0, green: 0.50, blue: 1.0, alpha: 0.0)
] as CFArray, locations: [0.0, 0.45, 1.0]) {
    context.drawRadialGradient(auroraGrad,
                               startCenter: CGPoint(x: 512, y: 550),
                               startRadius: 20,
                               endCenter: CGPoint(x: 512, y: 550),
                               endRadius: 360,
                               options: [])
}

// Dynamic Island Pill Graphic
let pillW: CGFloat = 580
let pillH: CGFloat = 170
let pillRect = CGRect(x: (1024 - pillW) / 2.0, y: 512 - (pillH / 2.0) + 30, width: pillW, height: pillH)
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2.0, cornerHeight: pillH / 2.0, transform: nil)

// Pill drop shadow
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.75))
context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.96))
context.addPath(pillPath)
context.fillPath()
context.restoreGState()

// Pill stroke
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18))
context.setLineWidth(3)
context.addPath(pillPath)
context.strokePath()

// Center Audio Waveform inside the Pill
let waveX = 512.0
let waveY = 512.0 + 30.0
let barHeights: [CGFloat] = [28, 48, 76, 105, 72, 94, 115, 65, 88, 42, 26]
let barWidth: CGFloat = 12
let barSpacing: CGFloat = 12
let totalWaveW = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * barSpacing
var startBarX = waveX - (totalWaveW / 2.0) + (barWidth / 2.0)

for (idx, h) in barHeights.enumerated() {
    let barRect = CGRect(x: startBarX - barWidth / 2.0, y: waveY - h / 2.0, width: barWidth, height: h)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2.0, cornerHeight: barWidth / 2.0, transform: nil)
    
    let progress = CGFloat(idx) / CGFloat(barHeights.count - 1)
    let r = 1.0 - progress * 0.8
    let g = 0.25 + progress * 0.55
    let b = 0.45 + progress * 0.55
    
    context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 0.95))
    context.addPath(barPath)
    context.fillPath()
    
    startBarX += barWidth + barSpacing
}

// Notch Camera / Sensor Aperture indicator
let camRect = CGRect(x: pillRect.minX + 36, y: waveY - 14, width: 28, height: 28)
context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0))
context.fillEllipse(in: camRect)
context.setStrokeColor(CGColor(red: 0.25, green: 0.25, blue: 0.35, alpha: 0.5))
context.setLineWidth(2)
context.strokeEllipse(in: camRect)

let lensRect = camRect.insetBy(dx: 7, dy: 7)
context.setFillColor(CGColor(red: 0.15, green: 0.22, blue: 0.45, alpha: 0.8))
context.fillEllipse(in: lensRect)

// Green Indicator Dot on right
let dotRect = CGRect(x: pillRect.maxX - 60, y: waveY - 7, width: 14, height: 14)
context.setFillColor(CGColor(red: 0.18, green: 0.85, blue: 0.35, alpha: 0.95))
context.fillEllipse(in: dotRect)

context.restoreGState()

guard let image = context.makeImage() else { fatalError("Cannot make image") }
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon1024.png"
let url = URL(fileURLWithPath: outputPath)
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Saved icon to \(outputPath)")

