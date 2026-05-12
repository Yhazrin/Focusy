import AppKit
import Combine
import Foundation
import FocusyCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: CapsuleStoreSnapshot
    @Published var isExpanded = false
    @Published var dockMode: CapsuleDockMode = .floating
    @Published var metrics = CapsuleMetrics()
    @Published var isLiquidMorphing = false
    @Published var quickText = ""
    @Published var lastStatus = "Ready"
    @Published var permissions = PermissionState()
    @Published var activeProcess: CapsuleProcessInfo?
    @Published var lastEvent: CapsuleEvent?
    @Published var isIdle: Bool = false

    private let store: CapsuleStore
    private var saveTask: Task<Void, Never>?

    init(store: CapsuleStore = CapsuleStore()) {
        self.store = store
        do {
            snapshot = try store.load()
        } catch {
            let capsule = FocusCapsule(title: "Today")
            snapshot = CapsuleStoreSnapshot(activeCapsuleId: capsule.id, capsules: [capsule])
            lastStatus = "Storage recovered"
        }
        ensureActiveCapsule()
    }

    var activeCapsule: FocusCapsule {
        get {
            ensureActiveCapsule()
            let id = snapshot.activeCapsuleId
            return snapshot.capsules.first { $0.id == id } ?? snapshot.capsules[0]
        }
        set {
            if let index = snapshot.capsules.firstIndex(where: { $0.id == newValue.id }) {
                snapshot.capsules[index] = newValue
            }
        }
    }

    var elapsedText: String {
        guard let startedAt = activeCapsule.startedAt, activeCapsule.isActive else { return "Paused" }
        let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    var recentEvents: [CapsuleEvent] {
        Array(activeCapsule.events.suffix(18).reversed())
    }

    func updateActiveProcess(_ process: CapsuleProcessInfo?) {
        activeProcess = process
        if let process {
            lastStatus = process.name
        }
    }

    func recordIdle() {
        isIdle = true
        addManualNote("用户进入空闲状态", system: true)
    }

    func recordIdleEnd(duration: TimeInterval) {
        isIdle = false
        let minutes = Int(duration / 60)
        addManualNote("用户恢复活动，空闲 \(minutes) 分钟", system: true)
    }

    func recordAppSwitch(fromApp: String, toApp: String, duration: TimeInterval) {
        let minutes = Int(duration / 60)
        let second = Int(duration.truncatingRemainder(dividingBy: 60))
        let timeStr = minutes > 0 ? "\(minutes)m \(second)s" : "\(second)s"
        addManualNote("切换: \(fromApp) → \(toApp) (\(timeStr))", system: true)
    }

    func toggleExpanded() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.08)) {
            isExpanded.toggle()
        }
    }

    func expandFromDock() {
        playLiquidMorph()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.08)) {
            isExpanded = true
        }
    }

    func playLiquidMorph() {
        isLiquidMorphing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.spring(response: 0.44, dampingFraction: 0.72, blendDuration: 0.06)) {
                isLiquidMorphing = false
            }
        }
    }

    func startStopFocus() {
        var capsule = activeCapsule
        capsule.isActive.toggle()
        capsule.startedAt = capsule.isActive ? Date() : capsule.startedAt
        activeCapsule = capsule
        addManualNote(capsule.isActive ? "Focus resumed" : "Focus paused", system: true)
    }

    func addManualNote(_ text: String, system: Bool = false) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let event = CapsuleEvent(
            sourceKind: .manual,
            sourceName: system ? "Focus Capsule" : "Quick Note",
            title: clean,
            timestamp: Date()
        )
        appendEvent(event)
        quickText = ""
    }

    func appendEvent(_ event: CapsuleEvent) {
        var capsule = activeCapsule
        if shouldCoalesce(event, into: capsule.events.last) {
            capsule.events[capsule.events.count - 1] = event
        } else {
            capsule.events.append(event)
        }
        if capsule.events.count > 300 {
            capsule.events.removeFirst(capsule.events.count - 300)
        }
        activeCapsule = capsule
        lastEvent = event
        lastStatus = event.sourceName
        scheduleSave()
    }

    func jump(_ target: JumpTarget?) {
        guard let target else { return }
        JumpPerformer.perform(target)
    }

    func createNewCapsule() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        let capsule = FocusCapsule(title: "Focus \(formatter.string(from: Date()))")
        snapshot.capsules.append(capsule)
        snapshot.activeCapsuleId = capsule.id
        scheduleSave()
    }

    func refreshPermissions() {
        permissions = PermissionState.current()
    }

    private func shouldCoalesce(_ event: CapsuleEvent, into last: CapsuleEvent?) -> Bool {
        guard let last else { return false }
        guard event.sourceKind != .manual else { return false }
        guard last.sourceKind == event.sourceKind,
              last.sourceName == event.sourceName,
              last.title == event.title else { return false }
        return event.timestamp.timeIntervalSince(last.timestamp) < 25
    }

    private func ensureActiveCapsule() {
        if snapshot.capsules.isEmpty {
            let capsule = FocusCapsule(title: "Today")
            snapshot = CapsuleStoreSnapshot(activeCapsuleId: capsule.id, capsules: [capsule])
        }
        if snapshot.activeCapsuleId == nil || !snapshot.capsules.contains(where: { $0.id == snapshot.activeCapsuleId }) {
            snapshot.activeCapsuleId = snapshot.capsules.first?.id
        }
    }

    private func scheduleSave() {
        let snapshot = snapshot
        saveTask?.cancel()
        saveTask = Task { [store] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            try? store.save(snapshot)
        }
    }
}

struct PermissionState {
    var accessibility = false
    var screenRecording = false

    static func current() -> PermissionState {
        PermissionState(
            accessibility: AXIsProcessTrusted(),
            screenRecording: PermissionState.canReadWindowList()
        )
    }

    private static func canReadWindowList() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return list.contains { window in
            (window[kCGWindowName as String] as? String)?.isEmpty == false
        }
    }
}
