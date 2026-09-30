import AppKit
import CoreGraphics
import Foundation

// Generates a 1024x1024 high-res macOS App Icon featuring a brushed dark-titanium squircle
// and the iconic glowing Cyber-Visor sunglasses with a Terminator Cyber-Red optic eye.
let size = 1024
let width = CGFloat(size)
let height = CGFloat(size)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create CGContext")
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// 1. macOS squircle background (inset 64px per Apple HIG 1024x1024 icon grid)
let iconRect = CGRect(x: 64, y: 64, width: 896, height: 896)
let cornerRadius: CGFloat = 200
let squirclePath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

let bgColors = [
    CGColor(red: 0.16, green: 0.18, blue: 0.23, alpha: 1.0),
    CGColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
] as CFArray
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 512, y: 960),
        end: CGPoint(x: 512, y: 64),
        options: []
    )
}

// Subtle cybernetic red ambient glow in the left-center of the squircle
let glowColors = [
    CGColor(red: 1.0, green: 0.18, blue: 0.15, alpha: 0.30),
    CGColor(red: 1.0, green: 0.18, blue: 0.15, alpha: 0.0)
] as CFArray
if let radialGlow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(
        radialGlow,
        startCenter: CGPoint(x: 365, y: 505),
        startRadius: 10,
        endCenter: CGPoint(x: 365, y: 505),
        endRadius: 340,
        options: []
    )
}
ctx.restoreGState()

// Metallic squircle rim border
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22))
ctx.setLineWidth(6)
ctx.strokePath()
ctx.restoreGState()

// 2. Cyber-Visor wrap-around sunglasses silhouette (centered in 1024x1024)
let visor = CGMutablePath()
visor.move(to: CGPoint(x: 190, y: 615))
visor.addLine(to: CGPoint(x: 834, y: 615))
visor.addLine(to: CGPoint(x: 852, y: 520))
visor.addQuadCurve(to: CGPoint(x: 715, y: 340), control: CGPoint(x: 825, y: 350))
visor.addLine(to: CGPoint(x: 565, y: 348))
visor.addQuadCurve(to: CGPoint(x: 512, y: 465), control: CGPoint(x: 540, y: 455))
visor.addQuadCurve(to: CGPoint(x: 459, y: 348), control: CGPoint(x: 484, y: 455))
visor.addLine(to: CGPoint(x: 309, y: 340))
visor.addQuadCurve(to: CGPoint(x: 172, y: 520), control: CGPoint(x: 199, y: 350))
visor.closeSubpath()

// Drop shadow under visor
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 32, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
ctx.addPath(visor)
ctx.setFillColor(CGColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0))
ctx.fillPath()
ctx.restoreGState()

// Visor metallic dark-chrome lens fill
ctx.saveGState()
ctx.addPath(visor)
ctx.clip()
let visorColors = [
    CGColor(red: 0.28, green: 0.30, blue: 0.36, alpha: 1.0),
    CGColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1.0)
] as CFArray
if let visorGrad = CGGradient(colorsSpace: colorSpace, colors: visorColors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(
        visorGrad,
        start: CGPoint(x: 512, y: 620),
        end: CGPoint(x: 512, y: 340),
        options: []
    )
}
ctx.restoreGState()

// Chrome top brow bar highlight
ctx.saveGState()
ctx.addPath(visor)
ctx.setStrokeColor(CGColor(red: 0.88, green: 0.91, blue: 0.96, alpha: 0.85))
ctx.setLineWidth(14)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// 3. Iconic Glowing Cyber-Red Optic Eye on Left Lens
let eyeCenter = CGPoint(x: 356, y: 492)
let eyeGlowColors = [
    CGColor(red: 1.0, green: 0.15, blue: 0.12, alpha: 0.85),
    CGColor(red: 1.0, green: 0.15, blue: 0.12, alpha: 0.0)
] as CFArray
if let eyeGlow = CGGradient(colorsSpace: colorSpace, colors: eyeGlowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(
        eyeGlow,
        startCenter: eyeCenter,
        startRadius: 8,
        endCenter: eyeCenter,
        endRadius: 115,
        options: []
    )
}

let outerRingRect = CGRect(x: eyeCenter.x - 52, y: eyeCenter.y - 52, width: 104, height: 104)
ctx.setFillColor(CGColor(red: 1.0, green: 0.22, blue: 0.18, alpha: 1.0))
ctx.fillEllipse(in: outerRingRect)

let hotCoreRect = CGRect(x: eyeCenter.x - 22, y: eyeCenter.y - 22, width: 44, height: 44)
ctx.setFillColor(CGColor(red: 1.0, green: 0.88, blue: 0.80, alpha: 1.0))
ctx.fillEllipse(in: hotCoreRect)

// 4. Right Lens Cybernetic HUD Telemetry Bars
let hudBar1 = CGRect(x: 590, y: 500, width: 145, height: 22)
ctx.addPath(CGPath(roundedRect: hudBar1, cornerWidth: 11, cornerHeight: 11, transform: nil))
ctx.setFillColor(CGColor(red: 1.0, green: 0.26, blue: 0.20, alpha: 0.90))
ctx.fillPath()

let hudBar2 = CGRect(x: 590, y: 460, width: 92, height: 14)
ctx.addPath(CGPath(roundedRect: hudBar2, cornerWidth: 7, cornerHeight: 7, transform: nil))
ctx.setFillColor(CGColor(red: 1.0, green: 0.26, blue: 0.20, alpha: 0.45))
ctx.fillPath()

guard let cgImage = ctx.makeImage() else {
    fatalError("Failed to make CGImage")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/icon_1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to create PNG data")
}
try pngData.write(to: outputURL)
print("✅ Generated 1024x1024 icon at \(outputPath)")
