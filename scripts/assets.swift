import AppKit

// All artwork is drawn from editable geometry; no game assets are redistributed.
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func bitmap(size: NSSize, scale: Int, draw: () -> Void) -> NSBitmapImageRep {
    let result = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale,
        pixelsHigh: Int(size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    result.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: result)!
    NSGraphicsContext.current = context
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return result
}

func polygon(_ points: [NSPoint], color: NSColor) {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    color.setFill()
    path.fill()
}

func drawIcon(size: CGFloat) {
    let transform = NSAffineTransform()
    transform.scale(by: size / 1024)
    transform.concat()
    let shape = NSBezierPath(roundedRect: NSRect(x: 88, y: 88, width: 848, height: 848),
        xRadius: 192, yRadius: 192)
    NSGradient(starting: NSColor(srgbRed: 0.07, green: 0.31, blue: 0.91, alpha: 1),
        ending: NSColor(srgbRed: 0.04, green: 0.69, blue: 0.85, alpha: 1))!.draw(in: shape, angle: 70)
    NSColor.white.withAlphaComponent(0.2).setStroke()
    shape.lineWidth = 3
    shape.stroke()
    polygon([NSPoint(x: 512, y: 750), NSPoint(x: 744, y: 616),
        NSPoint(x: 512, y: 482), NSPoint(x: 280, y: 616)], color: .white)
    polygon([NSPoint(x: 280, y: 575), NSPoint(x: 490, y: 454),
        NSPoint(x: 490, y: 260), NSPoint(x: 280, y: 381)],
        color: .white.withAlphaComponent(0.78))
    polygon([NSPoint(x: 534, y: 454), NSPoint(x: 744, y: 575),
        NSPoint(x: 744, y: 381), NSPoint(x: 534, y: 260)],
        color: .white.withAlphaComponent(0.94))
}

func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color]
    let string = NSString(string: value)
    let width = string.size(withAttributes: attributes).width
    string.draw(at: NSPoint(x: (680 - width) / 2, y: y), withAttributes: attributes)
}

func drawBackground() {
    NSColor(srgbRed: 0.975, green: 0.983, blue: 0.994, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 680, height: 420).fill()
    text("Palworld Mods", y: 338, size: 28, weight: .semibold,
        color: NSColor(srgbRed: 0.10, green: 0.15, blue: 0.22, alpha: 1))
    text("Drag to Applications to install", y: 64, size: 15, weight: .regular,
        color: NSColor(srgbRed: 0.38, green: 0.43, blue: 0.50, alpha: 1))
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 307, y: 212))
    arrow.line(to: NSPoint(x: 371, y: 212))
    arrow.move(to: NSPoint(x: 356, y: 227))
    arrow.line(to: NSPoint(x: 371, y: 212))
    arrow.line(to: NSPoint(x: 356, y: 197))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(srgbRed: 0.51, green: 0.57, blue: 0.66, alpha: 1).setStroke()
    arrow.stroke()
}

let iconset = destination.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = NSSize(width: points, height: points)
        let image = bitmap(size: size, scale: scale) { drawIcon(size: CGFloat(points)) }
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try image.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let background = NSImage(size: NSSize(width: 680, height: 420))
for scale in [1, 2] {
    let representation = bitmap(size: background.size, scale: scale, draw: drawBackground)
    background.addRepresentation(representation)
}
try background.tiffRepresentation!.write(to: destination.appendingPathComponent("InstallerBackground.tiff"))
