import AppKit
import Foundation

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let shape = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 212, yRadius: 212)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0.2, alpha: 0.15)
        shadow.shadowBlurRadius = 30
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        NSColor.white.setFill(); shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor(red: 0.97, green: 0.99, blue: 1, alpha: 1), NSColor(red: 0.80, green: 0.88, blue: 1, alpha: 1), NSColor(red: 0.79, green: 0.92, blue: 0.90, alpha: 1)])!.draw(in: shape, angle: -65)
        NSColor.white.withAlphaComponent(0.85).setStroke(); shape.lineWidth = 4; shape.stroke()
        let face = NSBezierPath(ovalIn: NSRect(x: 203, y: 203, width: 618, height: 618))
        NSColor.white.withAlphaComponent(0.45).setFill(); face.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke(); face.lineWidth = 3; face.stroke()
        let ring = NSBezierPath()
        ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 277, startAngle: 90, endAngle: -235, clockwise: true)
        ring.lineWidth = 24; ring.lineCapStyle = .round
        NSColor(red: 0.29, green: 0.49, blue: 0.91, alpha: 1).setStroke(); ring.stroke()
        let hands = NSBezierPath()
        hands.move(to: NSPoint(x: 512, y: 672)); hands.line(to: NSPoint(x: 512, y: 512)); hands.line(to: NSPoint(x: 625, y: 445))
        hands.lineWidth = 27; hands.lineCapStyle = .round; hands.lineJoinStyle = .round
        NSColor(red: 0.20, green: 0.34, blue: 0.56, alpha: 1).setStroke(); hands.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let data = bitmap.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size)\(suffix).png"))
    }
}
