import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let set = root.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels)/1024); transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 55, y: 55, width: 914, height: 914), xRadius: 215, yRadius: 215)
        NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.94, alpha: 1), ending: NSColor(calibratedRed: 0.18, green: 0.71, blue: 0.80, alpha: 1))!.draw(in: tile, angle: 40)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: 160, y: 435, width: 400, height: 270), xRadius: 35, yRadius: 35).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 335, y: 300, width: 525, height: 355), xRadius: 38, yRadius: 38).fill()
        NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.63, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 365, y: 345, width: 465, height: 280), xRadius: 18, yRadius: 18).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 570, y: 235, width: 55, height: 75), xRadius: 8, yRadius: 8).fill()
        NSBezierPath(roundedRect: NSRect(x: 490, y: 205, width: 215, height: 32), xRadius: 14, yRadius: 14).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
