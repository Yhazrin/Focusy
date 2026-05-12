import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        get { false }
        set { }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let model: AppModel
    private var dragStartFrame: NSRect?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        refreshDockMetrics()

        let root = CapsulePanelView(
            model: model,
            onDrag: { [weak self] translation in self?.drag(translation) },
            onDragEnded: { [weak self] in self?.finishDrag() },
            onLayoutChanged: { [weak self] in self?.updateSize(animated: true) }
        )
        let hosting = ClearHostingView(rootView: root)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        hosting.layerContentsRedrawPolicy = .onSetNeedsDisplay

        let panel = KeyablePanel(
            contentRect: defaultFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.invalidateShadow()
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = hosting
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.isOpaque = false
        panel.contentView?.layer?.masksToBounds = false
        panel.delegate = self
        self.panel = panel
        updateSize(animated: false)
        panel.orderFrontRegardless()
    }

    func toggleExpanded() {
        model.toggleExpanded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.updateSize(animated: true)
        }
    }

    func updateSize(animated: Bool) {
        guard let panel else { return }
        refreshDockMetrics(for: panel.screen)
        let oldFrame = panel.frame
        let size = nsSize(CapsuleLayout.size(isExpanded: model.isExpanded, mode: model.dockMode, metrics: model.metrics))
        let frame = frameForCurrentMode(from: oldFrame, size: size)
        if animated {
            panel.animator().setFrame(frame, display: true)
        } else {
            panel.setFrame(frame, display: true)
        }
        panel.contentView?.needsDisplay = true
    }

    private func drag(_ translation: CGSize) {
        guard let panel else { return }
        if dragStartFrame == nil {
            if model.isExpanded == false && model.dockMode != .floating {
                model.dockMode = .floating
                updateSize(animated: false)
            }
            dragStartFrame = panel.frame
        }
        guard let start = dragStartFrame else { return }
        let frame = NSRect(
            x: start.origin.x + translation.width,
            y: start.origin.y + translation.height,
            width: start.width,
            height: start.height
        )
        panel.setFrame(frame, display: true)
        panel.contentView?.needsDisplay = true
    }

    private func finishDrag() {
        guard let panel else { return }
        dragStartFrame = nil
        let decision = dockDecision(for: panel.frame)
        model.dockMode = decision
        if model.isExpanded {
            model.isExpanded = false
        }
        if decision != .floating {
            model.playLiquidMorph()
        }
        refreshDockMetrics(for: panel.screen)
        let size = nsSize(CapsuleLayout.size(isExpanded: false, mode: decision, metrics: model.metrics))
        let snapped = frame(for: decision, from: panel.frame, size: size)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(snapped, display: true)
        }
    }

    private func defaultFrame() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = nsSize(CapsuleLayout.size(isExpanded: false, mode: .floating, metrics: model.metrics))
        return NSRect(
            x: screen.midX - size.width / 2,
            y: screen.maxY - size.height - 14,
            width: size.width,
            height: size.height
        )
    }

    private func dockDecision(for frame: NSRect) -> CapsuleDockMode {
        guard let screen = panel?.screen?.frame ?? NSScreen.main?.frame else { return .floating }
        let topDistance = abs(screen.maxY - frame.maxY)
        let leftDistance = abs(frame.minX - screen.minX)
        let rightDistance = abs(screen.maxX - frame.maxX)

        if leftDistance < 92 || frame.midX < screen.minX + 92 {
            return .shelfLeft
        }
        if rightDistance < 92 || frame.midX > screen.maxX - 92 {
            return .shelfRight
        }
        if topDistance < 92 || frame.maxY > screen.maxY - 72 {
            return .island
        }
        return .floating
    }

    private func frameForCurrentMode(from oldFrame: NSRect, size: NSSize) -> NSRect {
        if model.isExpanded {
            var frame = oldFrame
            switch model.dockMode {
            case .floating:
                frame.origin.x = oldFrame.midX - size.width / 2
                frame.origin.y = oldFrame.midY - size.height / 2
            case .island:
                frame.origin.x = oldFrame.midX - size.width / 2
                frame.origin.y += oldFrame.height - size.height
            case .shelfLeft:
                frame.origin.x = oldFrame.minX
                frame.origin.y = oldFrame.midY - size.height / 2
            case .shelfRight:
                frame.origin.x = oldFrame.maxX - size.width
                frame.origin.y = oldFrame.midY - size.height / 2
            }
            frame.size = size
            return constrained(frame, useVisibleFrame: true)
        }
        return frame(for: model.dockMode, from: oldFrame, size: size)
    }

    private func frame(for mode: CapsuleDockMode, from oldFrame: NSRect, size: NSSize) -> NSRect {
        let dockScreen = panel?.screen?.frame ?? NSScreen.main?.frame
        let visibleScreen = panel?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let screen = dockScreen, let visible = visibleScreen else {
            return NSRect(origin: oldFrame.origin, size: size)
        }
        var frame = NSRect(origin: oldFrame.origin, size: size)
        switch mode {
        case .floating:
            frame.origin.x = oldFrame.midX - size.width / 2
            frame.origin.y = oldFrame.midY - size.height / 2
        case .island:
            frame.origin.x = screen.midX - size.width / 2
            frame.origin.y = screen.maxY - size.height
        case .shelfLeft:
            frame.origin.x = screen.minX
            frame.origin.y = min(max(oldFrame.midY - size.height / 2, visible.minY + 8), visible.maxY - size.height - 8)
        case .shelfRight:
            frame.origin.x = screen.maxX - size.width
            frame.origin.y = min(max(oldFrame.midY - size.height / 2, visible.minY + 8), visible.maxY - size.height - 8)
        }
        return constrained(frame, useVisibleFrame: mode == .floating)
    }

    private func constrained(_ frame: NSRect, useVisibleFrame: Bool) -> NSRect {
        let chosen = useVisibleFrame ? (panel?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame) : (panel?.screen?.frame ?? NSScreen.main?.frame)
        guard let screen = chosen else { return frame }
        var result = frame
        result.origin.x = min(max(result.origin.x, screen.minX), screen.maxX - result.width)
        result.origin.y = min(max(result.origin.y, screen.minY), screen.maxY - result.height)
        return result
    }

    private func nsSize(_ size: CGSize) -> NSSize {
        NSSize(width: size.width, height: size.height)
    }

    private func refreshDockMetrics(for screen: NSScreen? = nil) {
        let screen = screen ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.frame
        let menuBarHeight = max(24, frame.maxY - screen.visibleFrame.maxY)
        let safeTop: CGFloat
        if #available(macOS 12.0, *) {
            safeTop = screen.safeAreaInsets.top
        } else {
            safeTop = 0
        }
        let topHeight = min(max(safeTop > 0 ? safeTop : menuBarHeight, 28), 46)
        let hasNotch: Bool
        let notchWidth: CGFloat
        if #available(macOS 12.0, *) {
            let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            hasNotch = leftWidth > 0 || rightWidth > 0
            notchWidth = hasNotch ? max(120, frame.width - leftWidth - rightWidth) : 0
        } else {
            hasNotch = false
            notchWidth = 0
        }
        let wingWidth: CGFloat = hasNotch ? 116 : 0
        let topWidth = hasNotch
            ? min(max(notchWidth + wingWidth * 2, 340), frame.width - 120)
            : 286
        let metrics = CapsuleMetrics(
            topDockHeight: topHeight,
            topDockWidth: topWidth,
            notchGapWidth: notchWidth,
            hasNotch: hasNotch,
            shelfWidth: 44,
            shelfHeight: min(max(frame.height * 0.22, 164), 220),
            floatingDiameter: 58
        )
        if model.metrics != metrics {
            model.metrics = metrics
        }
    }
}
