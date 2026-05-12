import AppKit
import Foundation
import FocusyCore

@MainActor
final class ContextMonitor {
    private let model: AppModel
    private var timer: Timer?
    private var lastSignature = ""

    private let terminalBundles: Set<String> = [
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
    ]

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureFrontContext() }
        }
        captureFrontContext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func captureFrontContext() {
        model.refreshPermissions()
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let bundleId = app.bundleIdentifier
        if bundleId == Bundle.main.bundleIdentifier { return }

        let appName = app.localizedName ?? bundleId ?? "Application"
        let title = frontWindowTitle(pid: app.processIdentifier)
        let event: CapsuleEvent

        switch bundleId {
        case "com.google.Chrome":
            event = captureChrome(appName: appName, bundleId: bundleId, fallbackTitle: title)
        case "com.apple.Safari":
            event = captureSafari(appName: appName, bundleId: bundleId, fallbackTitle: title)
        default:
            if let bundleId, terminalBundles.contains(bundleId) {
                event = EventNormalizer.normalizeTerminalContext(
                    appName: appName,
                    title: title,
                    cwd: nil,
                    bundleId: bundleId
                )
            } else {
                event = EventNormalizer.normalizeWindowContext(
                    appName: appName,
                    title: title,
                    bundleId: bundleId
                )
            }
        }

        let signature = [
            event.sourceKind.rawValue,
            event.sourceName,
            event.title,
            event.url?.absoluteString ?? "",
            event.appBundleId ?? "",
        ].joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature
        model.appendEvent(event)
    }

    private func captureChrome(appName: String, bundleId: String?, fallbackTitle: String?) -> CapsuleEvent {
        let script = """
        tell application "Google Chrome"
            if (count of windows) is 0 then return ""
            set t to title of active tab of front window
            set u to URL of active tab of front window
            return t & "\n" & u
        end tell
        """
        let parts = AppleScriptRunner.run(script)?.components(separatedBy: "\n")
        return EventNormalizer.normalizeBrowserContext(
            browserName: appName,
            title: parts?.first ?? fallbackTitle,
            urlString: parts?.dropFirst().first,
            bundleId: bundleId
        )
    }

    private func captureSafari(appName: String, bundleId: String?, fallbackTitle: String?) -> CapsuleEvent {
        let script = """
        tell application "Safari"
            if (count of windows) is 0 then return ""
            set t to name of current tab of front window
            set u to URL of current tab of front window
            return t & "\n" & u
        end tell
        """
        let parts = AppleScriptRunner.run(script)?.components(separatedBy: "\n")
        return EventNormalizer.normalizeBrowserContext(
            browserName: appName,
            title: parts?.first ?? fallbackTitle,
            urlString: parts?.dropFirst().first,
            bundleId: bundleId
        )
    }

    private func frontWindowTitle(pid: pid_t) -> String? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for item in list {
            guard let ownerPID = item[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = item[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            let name = item[kCGWindowName as String] as? String
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
        }
        return nil
    }
}
