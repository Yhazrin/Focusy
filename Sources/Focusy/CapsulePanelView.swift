import AppKit
import SwiftUI
import FocusyCore

struct CapsulePanelView: View {
    @ObservedObject var model: AppModel
    var onDrag: (CGSize) -> Void
    var onDragEnded: () -> Void
    var onLayoutChanged: () -> Void

    @State private var revealContent = false

    var body: some View {
        ZStack {
            CapsuleShell(isExpanded: model.isExpanded, mode: model.dockMode, metrics: model.metrics)

            if !model.isExpanded && model.dockMode == .floating {
                floatingOrb
                    .contentShape(Circle())
                    .gesture(dragGesture)
                    .onTapGesture { model.expandFromDock() }
            } else if !model.isExpanded && model.dockMode.isShelf {
                shelfContent
                    .contentShape(RoundedRectangle(cornerRadius: CapsuleLayout.cornerRadius(isExpanded: false, mode: model.dockMode), style: .continuous))
                    .gesture(dragGesture)
                    .onTapGesture { model.expandFromDock() }
            } else {
                VStack(spacing: 0) {
                    header
                        .frame(height: model.isExpanded ? 54 : (model.dockMode == .island ? 36 : 54))
                        .contentShape(Rectangle())
                        .gesture(dragGesture)
                        .onTapGesture { model.toggleExpanded() }

                    if model.isExpanded {
                        expandedContent
                            .opacity(revealContent ? 1 : 0)
                            .offset(y: revealContent ? 0 : -12)
                            .scaleEffect(revealContent ? 1 : 0.96, anchor: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }
                .padding(contentPadding)
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .background(Color.clear)
        .scaleEffect(liquidScale, anchor: liquidAnchor)
        .offset(y: liquidOffsetY)
        .animation(.spring(response: 0.4, dampingFraction: 0.62, blendDuration: 0.1).speed(1.15), value: model.isLiquidMorphing)
        .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.12).speed(1.1), value: model.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.12).speed(1.1), value: model.dockMode.rawValue)
        .onChange(of: model.isExpanded) { _, expanded in
            onLayoutChanged()
            revealContent = false
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1).speed(1.2)) { revealContent = true }
                }
            }
        }
        .onChange(of: model.dockMode) { _, _ in
            onLayoutChanged()
        }
    }

    private var header: some View {
        if !model.isExpanded && model.dockMode == .island && model.metrics.hasNotch {
            return AnyView(notchIslandHeader)
        }
        return AnyView(standardHeader)
    }

    private var standardHeader: some View {
        HStack(spacing: 11) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(model.activeCapsule.title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(primaryTextStyle)
                    .lineLimit(1)
                Text(model.lastStatus)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(secondaryTextStyle)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            if model.isExpanded {
                Button {
                    model.toggleExpanded()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(.primary.opacity(0.055), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Text(model.elapsedText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryTextStyle)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(elapsedPillFill, in: Capsule())
            }
        }
        .padding(.horizontal, headerHorizontalPadding)
    }

    private var notchIslandHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                statusDot
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.activeCapsule.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)
                    Text(model.lastStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
            .frame(width: 112, alignment: .leading)

            Spacer(minLength: model.metrics.notchGapWidth)

            Text(model.elapsedText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(width: 112, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }

    private var shelfContent: some View {
        VStack(spacing: 11) {
            statusDot
            Text(model.elapsedText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(-90))
                .frame(width: 82, height: 28)
            Spacer(minLength: 4)
            Image(systemName: model.dockMode == .shelfLeft ? "chevron.right" : "chevron.left")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    private var floatingOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.04),
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 48
                    )
                )
            LiquidGlassView(intensity: 0.92, radius: 24, saturation: 1.3)
                .clipShape(Circle())
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blur(radius: 4)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.98),
                                Color.blue.opacity(0.82),
                                Color.white.opacity(0.22),
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 14
                        )
                    )
                    .frame(width: 18, height: 18)
                    .shadow(color: .cyan.opacity(0.5), radius: 10, y: 2)
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(x: -3.5, y: -3.5)
            }
        }
        .padding(6)
    }

    private var expandedContent: some View {
        VStack(spacing: 14) {
            quickCapture
            HStack(spacing: 8) {
                actionButton("New", systemImage: "plus") { model.createNewCapsule() }
                actionButton(model.activeCapsule.isActive ? "Pause" : "Start", systemImage: model.activeCapsule.isActive ? "pause.fill" : "play.fill") {
                    model.startStopFocus()
                }
                actionButton("Hooks", systemImage: "terminal") {
                    HookInstaller.installSupportedHooks()
                    model.addManualNote("CLI hooks installed for Claude, Codex, and Cursor", system: true)
                }
                Spacer()
            }
            Divider().opacity(0.32)
            timeline
            permissionStrip
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var quickCapture: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Capture a thought...", text: $model.quickText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit { model.addManualNote(model.quickText) }
            Button {
                model.addManualNote(model.quickText)
            } label: {
                Image(systemName: "return")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if model.recentEvents.isEmpty {
                    emptyState
                } else {
                    ForEach(model.recentEvents) { event in
                        EventRow(event: event) {
                            model.jump(event.jumpTarget)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 330)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "record.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
            Text("Your work trail will appear here.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var permissionStrip: some View {
        HStack(spacing: 8) {
            PermissionPill(title: "Accessibility", ok: model.permissions.accessibility)
            PermissionPill(title: "Screen", ok: model.permissions.screenRecording)
            Spacer()
            Button("Open Privacy") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: statusDotColors,
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: 13
                )
            )
            .frame(width: 13, height: 13)
            .shadow(color: .cyan.opacity(0.42), radius: 10, y: 1)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { onDrag($0.translation) }
            .onEnded { _ in onDragEnded() }
    }

    private var panelSize: CGSize {
        CapsuleLayout.size(isExpanded: model.isExpanded, mode: model.dockMode, metrics: model.metrics)
    }

    private var isCollapsedIsland: Bool {
        !model.isExpanded && model.dockMode == .island
    }

    private var primaryTextStyle: Color {
        isCollapsedIsland ? Color.white.opacity(0.96) : Color.primary
    }

    private var secondaryTextStyle: Color {
        isCollapsedIsland ? Color.white.opacity(0.62) : Color.secondary
    }

    private var elapsedPillFill: Color {
        isCollapsedIsland ? Color.white.opacity(0.14) : Color.primary.opacity(0.055)
    }

    private var statusDotColors: [Color] {
        if isCollapsedIsland {
            return [Color.white.opacity(0.96), Color.cyan.opacity(0.76), Color.white.opacity(0.22)]
        }
        return [Color.cyan.opacity(0.95), Color.blue.opacity(0.72), Color.white.opacity(0.15)]
    }

    private var liquidScale: CGSize {
        guard model.isLiquidMorphing else { return CGSize(width: 1, height: 1) }
        switch model.dockMode {
        case .island:
            return CGSize(width: 1.08, height: 0.72)
        case .shelfLeft, .shelfRight:
            return CGSize(width: 0.74, height: 1.08)
        case .floating:
            return CGSize(width: 0.96, height: 0.96)
        }
    }

    private var liquidAnchor: UnitPoint {
        switch model.dockMode {
        case .island:
            return .top
        case .shelfLeft:
            return .leading
        case .shelfRight:
            return .trailing
        case .floating:
            return .center
        }
    }

    private var liquidOffsetY: CGFloat {
        model.isLiquidMorphing && model.dockMode == .island ? -3 : 0
    }

    private var contentPadding: CGFloat {
        model.isExpanded ? 14 : (model.dockMode == .island ? 4 : 6)
    }

    private var headerHorizontalPadding: CGFloat {
        if model.isExpanded { return 8 }
        if model.dockMode == .island { return 13 }
        return 12
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CapsuleShell: View {
    var isExpanded: Bool
    var mode: CapsuleDockMode
    var metrics: CapsuleMetrics

    var body: some View {
        let radius = CapsuleLayout.cornerRadius(isExpanded: isExpanded, mode: mode)
        Group {
            if !isExpanded && mode == .island && metrics.hasNotch {
                notchIslandShell(radius: radius)
            } else if !isExpanded && mode == .floating {
                floatingOrbShell
            } else {
                singleShell(radius: radius)
            }
        }
        .shadow(color: .black.opacity(isExpanded ? 0.16 : 0), radius: isExpanded ? 24 : 0, y: isExpanded ? 16 : 0)
    }

    private var floatingOrbShell: some View {
        Circle()
            .fill(Color.clear)
    }

    private func singleShell(radius: CGFloat) -> some View {
        let shape = shellShape(radius: radius)
        return ZStack(alignment: .topLeading) {
            shellFill(shape)
            if !isCollapsedIsland {
                shellHighlight
            }
        }
        .clipShape(shape)
    }

    private func notchIslandShell(radius: CGFloat) -> some View {
        let wingWidth = max(96, (metrics.topDockWidth - metrics.notchGapWidth) / 2)
        let leftShape = UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: 0
            ),
            style: .continuous
        )
        let rightShape = UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: 0
            ),
            style: .continuous
        )

        return HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                shellFill(leftShape)
                if !isCollapsedIsland {
                    shellHighlight
                }
            }
            .clipShape(leftShape)
            .frame(width: wingWidth)

            Color.clear
                .frame(width: metrics.notchGapWidth)

            ZStack(alignment: .topTrailing) {
                shellFill(rightShape)
                if !isCollapsedIsland {
                    shellHighlight
                        .offset(x: -42)
                }
            }
            .clipShape(rightShape)
            .frame(width: wingWidth)
        }
    }

    private func shellFill<S: InsettableShape>(_ shape: S) -> some View {
        return ZStack {
            if isCollapsedIsland {
                shape
                    .fill(Color.black)
                shape
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            } else {
                shape
                    .background(
                        LiquidGlassView(intensity: 0.88, radius: 18, saturation: 1.15)
                    )
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.14),
                                Color.black.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                shape
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.12),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.35
                    )
            }
        }
    }

    private var isCollapsedIsland: Bool {
        !isExpanded && mode == .island
    }

    private var shellHighlight: some View {
        Circle()
            .fill(Color.white.opacity(0.17))
            .blur(radius: 18)
            .frame(width: 120, height: 68)
            .offset(x: 24, y: -28)
    }

    private func shellShape(radius: CGFloat) -> UnevenRoundedRectangle {
        let radii: RectangleCornerRadii
        if isExpanded || mode == .floating {
            radii = RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            )
        } else if mode == .island {
            radii = RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: 0
            )
        } else if mode == .shelfLeft {
            radii = RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: 0,
                bottomTrailing: radius,
                topTrailing: radius
            )
        } else {
            radii = RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: 0,
                topTrailing: 0
            )
        }
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
    }
}

private struct EventRow: View {
    var event: CapsuleEvent
    var jump: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            sourceIcon
                .frame(width: 26, height: 26)
                .background(.primary.opacity(0.055), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(timeString)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(event.sourceName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            if event.jumpTarget != nil {
                Button(action: jump) {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sourceIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private var iconName: String {
        switch event.sourceKind {
        case .manual: return "text.append"
        case .cli: return "terminal"
        case .browser: return "safari"
        case .terminal: return "apple.terminal"
        case .appWindow: return "macwindow"
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.timestamp)
    }
}

private struct PermissionPill: View {
    var title: String
    var ok: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ok ? Color.green.opacity(0.75) : Color.orange.opacity(0.75))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.primary.opacity(0.045), in: Capsule())
    }
}
