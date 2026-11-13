import AppKit

// MARK: - Native Artwork Dominant Color Extraction Test (Self-contained runnable check)
extension NSImage {
    public func extractDominantColor() -> NSColor? {
        var proposed = CGRect(origin: .zero, size: self.size)
        guard let cgImage = self.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
                ?? self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let width = 32
        let height = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        struct HueBucket {
            var count: Int = 0
            var totalR: CGFloat = 0
            var totalG: CGFloat = 0
            var totalB: CGFloat = 0
            var totalSat: CGFloat = 0
            var totalBri: CGFloat = 0
        }
        
        let numBins = 24
        var buckets = [HueBucket](repeating: HueBucket(), count: numBins)
        var fallbackR: CGFloat = 0
        var fallbackG: CGFloat = 0
        var fallbackB: CGFloat = 0
        var totalSamples: CGFloat = 0
        
        for i in 0..<(width * height) {
            let offset = i * 4
            let a = CGFloat(rawData[offset + 3]) / 255.0
            guard a > 0.5 else { continue }
            
            let r = CGFloat(rawData[offset]) / 255.0
            let g = CGFloat(rawData[offset + 1]) / 255.0
            let b = CGFloat(rawData[offset + 2]) / 255.0
            
            fallbackR += r
            fallbackG += g
            fallbackB += b
            totalSamples += 1
            
            let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
            let sat = color.saturationComponent
            let bri = color.brightnessComponent
            
            // Filter extreme black noise (< 0.08) and pure washed-out white (< 0.08 sat at > 0.94 bri)
            if bri < 0.08 || (sat < 0.08 && bri > 0.94) { continue }
            
            // Only bucket pixels that possess authentic chromatic hue (saturation >= 0.12)
            // Neutral / monochrome pixels contribute to fallback average but must not pollute hue bins with false tints
            guard sat >= 0.12 else { continue }
            
            let hue = color.hueComponent
            let bin = min(numBins - 1, max(0, Int(hue * CGFloat(numBins))))
            buckets[bin].count += 1
            buckets[bin].totalR += r
            buckets[bin].totalG += g
            buckets[bin].totalB += b
            buckets[bin].totalSat += sat
            buckets[bin].totalBri += bri
        }
        
        var bestBucket: HueBucket?
        var bestScore: Double = -1
        
        for b in buckets {
            guard b.count > 0 else { continue }
            let countF = Double(b.count)
            let avgSat = Double(b.totalSat) / countF
            let avgBri = Double(b.totalBri) / countF
            
            // Frequency-weighted score with natural saturation & brightness boost
            let score = countF * (1.0 + sqrt(avgSat) * 1.5) * (0.6 + avgBri * 0.4)
            if score > bestScore {
                bestScore = score
                bestBucket = b
            }
        }
        
        if let winner = bestBucket, winner.count > 0 {
            let avgR = winner.totalR / CGFloat(winner.count)
            let avgG = winner.totalG / CGFloat(winner.count)
            let avgB = winner.totalB / CGFloat(winner.count)
            let rawColor = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
            
            // Calibrate for OLED Jet-Black MacBook Notch: keep authentic hue, allow natural brightness & saturation
            let h = rawColor.hueComponent
            let rawSat = rawColor.saturationComponent
            let s: CGFloat
            if rawSat < 0.06 {
                s = 0.0
            } else if rawSat < 0.18 {
                s = rawSat
            } else {
                s = min(0.85, max(0.22, rawSat * 1.05))
            }
            let br = min(0.65, max(0.22, rawColor.brightnessComponent))
            return NSColor(hue: h, saturation: s, brightness: br, alpha: 1.0)
        }
        
        if totalSamples > 0 {
            let fallbackColor = NSColor(
                red: fallbackR / totalSamples,
                green: fallbackG / totalSamples,
                blue: fallbackB / totalSamples,
                alpha: 1.0
            )
            let rawSat = fallbackColor.saturationComponent
            let s: CGFloat
            if rawSat < 0.06 {
                s = 0.0
            } else if rawSat < 0.18 {
                s = rawSat
            } else {
                s = min(0.85, max(0.22, rawSat * 1.05))
            }
            let br = min(0.65, max(0.22, fallbackColor.brightnessComponent))
            return NSColor(hue: fallbackColor.hueComponent, saturation: s, brightness: br, alpha: 1.0)
        }
        
        return nil
    }
}

func makeTestImage(color: NSColor, size: NSSize = NSSize(width: 32, height: 32)) -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    color.drawSwatch(in: NSRect(origin: .zero, size: size))
    img.unlockFocus()
    return img
}

// 1. Test Monochrome / Billie Eilish aesthetic (R=0.39, G=0.38, B=0.38)
let billieColor = NSColor(red: 0.39, green: 0.38, blue: 0.38, alpha: 1.0)
let billieImg = makeTestImage(color: billieColor)
guard let billieExtracted = billieImg.extractDominantColor() else {
    fatalError("Failed to extract color from monochrome image")
}
print("Billie extracted: hue=\(billieExtracted.hueComponent), sat=\(billieExtracted.saturationComponent), bri=\(billieExtracted.brightnessComponent)")
assert(billieExtracted.saturationComponent <= 0.05, "Monochrome artwork must not have forced high saturation (got \(billieExtracted.saturationComponent))")

// 2. Test Pure Vibrant Blue
let blueColor = NSColor(red: 0.10, green: 0.50, blue: 0.95, alpha: 1.0)
let blueImg = makeTestImage(color: blueColor)
guard let blueExtracted = blueImg.extractDominantColor() else {
    fatalError("Failed to extract color from blue image")
}
print("Blue extracted: hue=\(blueExtracted.hueComponent), sat=\(blueExtracted.saturationComponent), bri=\(blueExtracted.brightnessComponent)")
assert(blueExtracted.saturationComponent >= 0.50, "Vibrant blue artwork must retain high saturation")
assert(blueExtracted.hueComponent >= 0.55 && blueExtracted.hueComponent <= 0.65, "Blue hue must be authentic")

// 3. Test Dark Moody Midnight Blue
let darkNavy = NSColor(red: 0.05, green: 0.10, blue: 0.30, alpha: 1.0)
let darkImg = makeTestImage(color: darkNavy)
guard let darkExtracted = darkImg.extractDominantColor() else {
    fatalError("Failed to extract color from dark image")
}
print("Dark Navy extracted: hue=\(darkExtracted.hueComponent), sat=\(darkExtracted.saturationComponent), bri=\(darkExtracted.brightnessComponent)")
assert(darkExtracted.brightnessComponent <= 0.35, "Dark moody artwork must not be clamped up to washed-out milky brightness")

print("✅ All dominant color tests passed successfully!")
