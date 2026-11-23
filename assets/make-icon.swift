// Renders assets/icon.svg into assets/AppIcon.icns (needs macOS 14+ for SVG support):
//   swiftc assets/make-icon.swift -o /tmp/make-icon && /tmp/make-icon assets/icon.svg /tmp/AppIcon.iconset \
//     && iconutil -c icns /tmp/AppIcon.iconset -o assets/AppIcon.icns
import AppKit
let src = NSImage(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
let out = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (px, name) in [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),(128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")] {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  src.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
