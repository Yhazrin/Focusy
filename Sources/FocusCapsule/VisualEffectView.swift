import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
    }
}

struct LiquidGlassView: NSViewRepresentable {
    var intensity: CGFloat = 0.85
    var radius: CGFloat = 20
    var saturation: CGFloat = 1.2

    func makeNSView(context: Context) -> NSView {
        let view = LiquidGlassNSView(frame: .zero, intensity: intensity, radius: radius, saturation: saturation)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if let glass = view as? LiquidGlassNSView {
            glass.intensity = intensity
            glass.radius = radius
            glass.saturation = saturation
            glass.needsDisplay = true
        }
    }
}

final class LiquidGlassNSView: NSView {
    var intensity: CGFloat = 0.85
    var radius: CGFloat = 20
    var saturation: CGFloat = 1.2

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    init(frame frameRect: NSRect, intensity: CGFloat, radius: CGFloat, saturation: CGFloat) {
        self.intensity = intensity
        self.radius = radius
        self.saturation = saturation
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds

        context.saveGState()
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(bounds)

        let blurRadius = radius * 1.5
        context.setShadow(offset: .zero, blur: blurRadius, color: NSColor.black.withAlphaComponent(0.12 * intensity).cgColor)

        let gradientColors = [
            NSColor.white.withAlphaComponent(0.32 * intensity).cgColor,
            NSColor.white.withAlphaComponent(0.10 * intensity).cgColor,
            NSColor.white.withAlphaComponent(0.04 * intensity).cgColor
        ]
        let gradientLocations: [CGFloat] = [0.0, 0.5, 1.0]

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors as CFArray,
            locations: gradientLocations
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.minX, y: bounds.maxY),
                end: CGPoint(x: bounds.maxX, y: bounds.minY),
                options: []
            )
        }

        context.restoreGState()

        let highlightColors = [
            NSColor.white.withAlphaComponent(0.55 * intensity).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        if let highlight = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: highlightColors as CFArray,
            locations: [0.0, 0.5]
        ) {
            context.saveGState()
            context.clip(to: bounds)
            context.drawLinearGradient(
                highlight,
                start: CGPoint(x: bounds.midX, y: bounds.maxY),
                end: CGPoint(x: bounds.midX, y: bounds.midY),
                options: []
            )
            context.restoreGState()
        }

        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.30 * intensity).cgColor)
        context.setLineWidth(0.8)
        let borderRect = bounds.insetBy(dx: 0.4, dy: 0.4)
        context.stroke(borderRect)
        context.restoreGState()
    }
}
