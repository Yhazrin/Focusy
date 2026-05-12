import AppKit
import SwiftUI

@main
struct FocusCapsuleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices.shared

    var body: some Scene {
        MenuBarExtra {
            Button(services.model.isExpanded ? "Collapse Capsule" : "Expand Capsule") {
                services.panelController.toggleExpanded()
            }
            Button("Quick Capture") {
                services.panelController.toggleExpanded()
            }
            Button(services.model.activeCapsule.isActive ? "Pause Focus" : "Start Focus") {
                services.model.startStopFocus()
            }
            Divider()
            Button("Install CLI Hooks") {
                HookInstaller.installSupportedHooks()
                services.model.addManualNote("CLI hooks installed for Claude, Codex, and Cursor", system: true)
            }
            Button("Refresh Context") {
                services.processMonitor.scanAndUpdate()
            }
            Divider()
            Button("Quit Focus Capsule") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "capsule.portrait")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: services.model)
                .frame(width: 430, height: 320)
        }
    }
}

@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()

    let model = AppModel()
    lazy var panelController = PanelController(model: model)
    lazy var processMonitor = ProcessMonitor(model: model)
    lazy var hookServer = HookServer(model: model)

    private var tickTimer: Timer?

    func start() {
        NSApplication.shared.setActivationPolicy(.accessory)
        model.refreshPermissions()
        panelController.show()
        hookServer.start()
        processMonitor.start()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
    }

    func stop() {
        tickTimer?.invalidate()
        hookServer.stop()
        processMonitor.stop()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.stop()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "capsule.portrait")
                    .font(.system(size: 24, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus Capsule")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Liquid context island for macOS")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                SettingsRow(title: "Accessibility", ok: model.permissions.accessibility)
                SettingsRow(title: "Screen Recording", ok: model.permissions.screenRecording)
                SettingsRow(title: "Hook Socket", ok: FileManager.default.fileExists(atPath: "/tmp/focuscapsule-\(getuid()).sock"))
            }

            HStack {
                Button("Refresh Permissions") { model.refreshPermissions() }
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                Spacer()
            }
        }
        .padding(24)
    }
}

private struct SettingsRow: View {
    var title: String
    var ok: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(ok ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text(ok ? "Ready" : "Needs permission")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13, weight: .medium))
    }
}
