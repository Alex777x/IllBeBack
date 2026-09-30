import AppKit
import SwiftUI

/// Renders the custom Terminator-inspired **Cyber-Visor** menu bar icon and high-res app emblem.
/// 100% original vector geometry — safe for Mac App Store review.
public enum CyberVisorIcon {

    /// Generates the `20x16pt` menu bar `NSImage` for the current state.
    /// - Parameters:
    ///   - isActive: Whether sleep prevention is currently active.
    ///   - isColored: Whether the glowing red eye dot is enabled when active.
    @MainActor
    public static func makeMenuBarImage(isActive: Bool, isColored: Bool) -> NSImage {
        let size = NSSize(width: 20, height: 16)
        let showRedEye = isActive && isColored

        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)

            // Visor outer wrap-around sunglasses silhouette
            let visorPath = CGMutablePath()
            visorPath.move(to: CGPoint(x: 1.2, y: 12.2))
            visorPath.addLine(to: CGPoint(x: 18.8, y: 12.2))
            visorPath.addLine(to: CGPoint(x: 19.3, y: 9.6))
            visorPath.addQuadCurve(to: CGPoint(x: 15.6, y: 4.0), control: CGPoint(x: 18.5, y: 4.3))
            visorPath.addLine(to: CGPoint(x: 11.6, y: 4.2))
            visorPath.addQuadCurve(to: CGPoint(x: 10.0, y: 7.4), control: CGPoint(x: 10.8, y: 7.2))
            visorPath.addQuadCurve(to: CGPoint(x: 8.4, y: 4.2), control: CGPoint(x: 9.2, y: 7.2))
            visorPath.addLine(to: CGPoint(x: 4.4, y: 4.0))
            visorPath.addQuadCurve(to: CGPoint(x: 0.7, y: 9.6), control: CGPoint(x: 1.5, y: 4.3))
            visorPath.closeSubpath()

            if !isActive {
                // INACTIVE STATE: Clean hollow template visor outline
                NSColor.black.withAlphaComponent(0.82).setStroke()
                ctx.setLineWidth(1.55)
                ctx.setLineJoin(.round)
                ctx.addPath(visorPath)
                ctx.strokePath()

                // Subtle inactive optic slit on left lens
                let slitRect = CGRect(x: 4.2, y: 7.7, width: 3.0, height: 1.3)
                let slitPath = CGPath(roundedRect: slitRect, cornerWidth: 0.65, cornerHeight: 0.65, transform: nil)
                NSColor.black.withAlphaComponent(0.45).setFill()
                ctx.addPath(slitPath)
                ctx.fillPath()
            } else if !showRedEye {
                // ACTIVE MONOCHROME STATE: Solid filled template visor with cut-out optic eye & HUD scanline
                ctx.saveGState()
                ctx.addPath(visorPath)

                let eyeCenter = CGPoint(x: 5.5, y: 8.3)
                let eyeOuter = CGRect(x: eyeCenter.x - 2.3, y: eyeCenter.y - 2.3, width: 4.6, height: 4.6)
                ctx.addEllipse(in: eyeOuter)

                let hudBar = CGRect(x: 12.2, y: 7.7, width: 4.4, height: 1.3)
                ctx.addPath(CGPath(roundedRect: hudBar, cornerWidth: 0.65, cornerHeight: 0.65, transform: nil))

                NSColor.black.setFill()
                ctx.drawPath(using: .eoFill)
                ctx.restoreGState()

                let pupilRect = CGRect(x: 5.5 - 0.95, y: 8.3 - 0.95, width: 1.9, height: 1.9)
                NSColor.black.setFill()
                ctx.fillEllipse(in: pupilRect)
            } else {
                // ACTIVE WITH RED EYE DOT:
                // Cut-out aperture for the left eye + HUD slit on right lens, with a vivid red Terminator dot in the left eye!
                let frameColor = NSColor.labelColor
                ctx.saveGState()
                ctx.addPath(visorPath)

                let eyeCenter = CGPoint(x: 5.5, y: 8.3)
                let eyeAperture = CGRect(x: eyeCenter.x - 2.45, y: eyeCenter.y - 2.45, width: 4.9, height: 4.9)
                ctx.addEllipse(in: eyeAperture)

                let hudBar = CGRect(x: 12.2, y: 7.7, width: 4.4, height: 1.3)
                ctx.addPath(CGPath(roundedRect: hudBar, cornerWidth: 0.65, cornerHeight: 0.65, transform: nil))

                frameColor.setFill()
                ctx.drawPath(using: .eoFill)
                ctx.restoreGState()

                // Vivid glowing red Terminator dot inside the left eye aperture
                let redGlow = CGRect(x: eyeCenter.x - 2.2, y: eyeCenter.y - 2.2, width: 4.4, height: 4.4)
                NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.12, alpha: 0.35).setFill()
                ctx.fillEllipse(in: redGlow)

                let redDot = CGRect(x: eyeCenter.x - 1.55, y: eyeCenter.y - 1.55, width: 3.1, height: 3.1)
                NSColor(calibratedRed: 1.0, green: 0.18, blue: 0.14, alpha: 1.0).setFill()
                ctx.fillEllipse(in: redDot)

                let hotCore = CGRect(x: eyeCenter.x - 0.55, y: eyeCenter.y - 0.55, width: 1.1, height: 1.1)
                NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.80, alpha: 1.0).setFill()
                ctx.fillEllipse(in: hotCore)
            }

            return true
        }

        image.isTemplate = !showRedEye
        return image
    }
}

/// SwiftUI vector emblem for the inline About card and previews.
public struct CyberVisorEmblemView: View {
    public let isActive: Bool
    public let isColored: Bool
    public var size: CGFloat = 44

    public init(isActive: Bool = true, isColored: Bool = true, size: CGFloat = 44) {
        self.isActive = isActive
        self.isColored = isColored
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.17, blue: 0.20),
                            Color(red: 0.08, green: 0.09, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.blue.opacity(0.45)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )

            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height

                var visor = Path()
                visor.move(to: CGPoint(x: w * 0.14, y: h * 0.36))
                visor.addLine(to: CGPoint(x: w * 0.86, y: h * 0.36))
                visor.addLine(to: CGPoint(x: w * 0.88, y: h * 0.48))
                visor.addQuadCurve(
                    to: CGPoint(x: w * 0.73, y: h * 0.68),
                    control: CGPoint(x: w * 0.85, y: h * 0.67)
                )
                visor.addLine(to: CGPoint(x: w * 0.56, y: h * 0.67))
                visor.addQuadCurve(
                    to: CGPoint(x: w * 0.50, y: h * 0.54),
                    control: CGPoint(x: w * 0.53, y: h * 0.55)
                )
                visor.addQuadCurve(
                    to: CGPoint(x: w * 0.44, y: h * 0.67),
                    control: CGPoint(x: w * 0.47, y: h * 0.55)
                )
                visor.addLine(to: CGPoint(x: w * 0.27, y: h * 0.68))
                visor.addQuadCurve(
                    to: CGPoint(x: w * 0.12, y: h * 0.48),
                    control: CGPoint(x: w * 0.15, y: h * 0.67)
                )
                visor.closeSubpath()

                context.fill(visor, with: .color(Color.white.opacity(0.92)))

                let eyeAccent = Color(red: 1.0, green: 0.20, blue: 0.16)
                let eyeCenter = CGPoint(x: w * 0.31, y: h * 0.51)
                let glowRect = CGRect(x: eyeCenter.x - w * 0.11, y: eyeCenter.y - w * 0.11, width: w * 0.22, height: w * 0.22)
                context.fill(Path(ellipseIn: glowRect), with: .color(eyeAccent.opacity(0.42)))

                let eyeRect = CGRect(x: eyeCenter.x - w * 0.065, y: eyeCenter.y - w * 0.065, width: w * 0.13, height: w * 0.13)
                context.fill(Path(ellipseIn: eyeRect), with: .color(eyeAccent))

                let pupilRect = CGRect(x: eyeCenter.x - w * 0.025, y: eyeCenter.y - w * 0.025, width: w * 0.05, height: w * 0.05)
                context.fill(Path(ellipseIn: pupilRect), with: .color(.white))

                let hudRect = CGRect(x: w * 0.59, y: h * 0.49, width: w * 0.17, height: h * 0.045)
                context.fill(
                    Path(roundedRect: hudRect, cornerRadius: h * 0.022),
                    with: .color(eyeAccent.opacity(0.85))
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.22), radius: 4, y: 2)
    }
}
