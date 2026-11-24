import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func png(size: CGSize, name: String, draw: () -> Void) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    draw()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
}
try png(size: CGSize(width: 1024, height: 1024), name: "icon.png") {
    let bounds = NSRect(x: 64, y: 64, width: 896, height: 896)
    NSBezierPath(roundedRect: bounds, xRadius: 200, yRadius: 200).addClip()
    NSImage(contentsOfFile: "design/icon.png")!.draw(in: bounds)
}
try png(size: CGSize(width: 640, height: 400), name: "background.png") {
    NSGradient(starting: NSColor(calibratedRed: 0.76, green: 0.88, blue: 1, alpha: 1), ending: NSColor(calibratedRed: 0.97, green: 0.99, blue: 1, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: 640, height: 400), angle: 0)
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 290, y: 215)); arrow.line(to: NSPoint(x: 350, y: 215))
    arrow.move(to: NSPoint(x: 330, y: 235)); arrow.line(to: NSPoint(x: 350, y: 215)); arrow.line(to: NSPoint(x: 330, y: 195))
    arrow.lineWidth = 5; arrow.lineCapStyle = .round; NSColor.white.setStroke(); arrow.stroke()
    let text = "Drag to Applications · Перетащите в Applications"
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.darkGray]
    let width = (text as NSString).size(withAttributes: attributes).width
    (text as NSString).draw(at: NSPoint(x: (640 - width) / 2, y: 24), withAttributes: attributes)
}
