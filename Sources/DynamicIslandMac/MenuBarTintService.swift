import AppKit
import CoreGraphics
import UniformTypeIdentifiers

public class MenuBarTintService {
    public static let shared = MenuBarTintService()
    
    private let originalWallpaperKey = "DynamicIsland_OriginalWallpaperURL"
    private let seamlessWallpaperFileName = "seamless_menu_bar_wallpaper.png"
    
    private var wallpapersDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DynamicIslandMac/Wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }
    
    private var seamlessWallpaperURL: URL {
        return wallpapersDirectory.appendingPathComponent(seamlessWallpaperFileName)
    }
    
    public init() {}
    
    /// Applies the seamless black menu bar by rendering a pure black strip across the top of the wallpaper.
    @discardableResult
    public func applySeamlessMenuBar() -> Bool {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        
        // 1. Get current wallpaper URL
        guard let currentURL = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return false
        }
        
        // 2. If current wallpaper is NOT already our seamless wallpaper, save as original
        if currentURL.path != seamlessWallpaperURL.path {
            UserDefaults.standard.set(currentURL.path, forKey: originalWallpaperKey)
        }
        
        // 3. Load source image to process (prefer original wallpaper if currently on seamless)
        let sourceURL: URL
        if currentURL.path == seamlessWallpaperURL.path,
           let originalPath = UserDefaults.standard.string(forKey: originalWallpaperKey),
           FileManager.default.fileExists(atPath: originalPath) {
            sourceURL = URL(fileURLWithPath: originalPath)
        } else {
            sourceURL = currentURL
        }
        
        guard let sourceImage = NSImage(contentsOf: sourceURL),
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        // 4. Calculate dimensions for active screen
        let screenW = screen.frame.width * screen.backingScaleFactor
        let screenH = screen.frame.height * screen.backingScaleFactor
        let menuBarPoints = screen.frame.height - (screen.visibleFrame.origin.y + screen.visibleFrame.height)
        let menuBarHeightPoints = menuBarPoints > 0 ? menuBarPoints : 25.0
        let blackBarHeight = (menuBarHeightPoints + 2.0) * screen.backingScaleFactor
        
        // 5. Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(screenW),
            height: Int(screenH),
            bitsPerComponent: 8,
            bytesPerRow: Int(screenW) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        
        // 6. Draw aspect-filled source image
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let scale = max(screenW / imgW, screenH / imgH)
        let scaledW = imgW * scale
        let scaledH = imgH * scale
        let originX = (screenW - scaledW) / 2.0
        let originY = (screenH - scaledH) / 2.0
        
        context.draw(cgImage, in: CGRect(x: originX, y: originY, width: scaledW, height: scaledH))
        
        // 7. Draw pure OLED black bar at the top (CGContext origin is bottom-left)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: screenH - blackBarHeight, width: screenW, height: blackBarHeight))
        
        // 8. Export to PNG
        guard let outputCGImage = context.makeImage() else { return false }
        
        let outURL = seamlessWallpaperURL
        guard let destination = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, outputCGImage, nil)
        guard CGImageDestinationFinalize(destination) else { return false }
        
        // 9. Apply desktop wallpaper
        do {
            try NSWorkspace.shared.setDesktopImageURL(outURL, for: screen, options: [:])
            return true
        } catch {
            print("Failed to set desktop image: \(error)")
            return false
        }
    }
    
    /// Restores the original desktop wallpaper.
    @discardableResult
    public func restoreOriginalWallpaper() -> Bool {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        guard let originalPath = UserDefaults.standard.string(forKey: originalWallpaperKey),
              FileManager.default.fileExists(atPath: originalPath) else {
            return false
        }
        
        let originalURL = URL(fileURLWithPath: originalPath)
        do {
            try NSWorkspace.shared.setDesktopImageURL(originalURL, for: screen, options: [:])
            return true
        } catch {
            print("Failed to restore wallpaper: \(error)")
            return false
        }
    }
    
    /// Checks if seamless menu bar wallpaper is currently active.
    public var isSeamlessActive: Bool {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let currentURL = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return false
        }
        return currentURL.path == seamlessWallpaperURL.path
    }
}

