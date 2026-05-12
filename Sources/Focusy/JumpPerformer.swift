import AppKit
import Foundation
import FocusyCore

enum JumpPerformer {
    static func perform(_ target: JumpTarget) {
        switch target.kind {
        case .url:
            if let url = URL(string: target.value) {
                NSWorkspace.shared.open(url)
            }
        case .path:
            NSWorkspace.shared.open(URL(fileURLWithPath: target.value))
        case .appBundle:
            activateBundle(target.appBundleId ?? target.value)
        }
    }

    static func activateBundle(_ bundleId: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            if app.isHidden { app.unhide() }
            app.activate()
            return
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
