import Foundation

enum HookInstaller {
    static let supportDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".focusy", isDirectory: true)
    static let bridgePath = supportDir.appendingPathComponent("focusy-bridge").path
    static let marker = "focusy"

    static func installSupportedHooks() {
        installBridgeIfAvailable()
        installCodex()
        installClaude()
        installCursor()
    }

    private static func installBridgeIfAvailable() {
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let local: URL
        if Bundle.main.bundleURL.pathExtension == "app" {
            local = Bundle.main.bundleURL
                .appendingPathComponent("Contents/MacOS/focusy-bridge")
        } else {
            local = Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("focusy-bridge")
        }
        if FileManager.default.fileExists(atPath: local.path) {
            try? FileManager.default.removeItem(atPath: bridgePath)
            try? FileManager.default.copyItem(atPath: local.path, toPath: bridgePath)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgePath)
        }
    }

    private static func installCodex() {
        let path = NSHomeDirectory() + "/.codex/hooks.json"
        addNestedHook(path: path, source: "codex", events: ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SessionEnd"])
    }

    private static func installClaude() {
        let path = NSHomeDirectory() + "/.claude/settings.json"
        addClaudeHook(path: path, source: "claude", events: ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SessionStart", "SessionEnd"])
    }

    private static func installCursor() {
        let path = NSHomeDirectory() + "/.cursor/hooks.json"
        addFlatHook(path: path, source: "cursor", events: ["beforeSubmitPrompt", "beforeShellExecution", "afterShellExecution", "afterFileEdit", "afterAgentResponse", "stop"])
    }

    private static func addNestedHook(path: String, source: String, events: [String]) {
        var root = readJSON(path) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var entries = hooks[event] as? [[String: Any]] ?? []
            let command = "\(bridgePath) --source \(source)"
            if !containsFocusCapsule(entries) {
                entries.append(["hooks": [hookCommand(command, event: event)]])
            }
            hooks[event] = entries
        }
        root["hooks"] = hooks
        writeJSON(root, path: path)
    }

    private static func addClaudeHook(path: String, source: String, events: [String]) {
        var root = readJSON(path) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var entries = hooks[event] as? [[String: Any]] ?? []
            let command = "\(bridgePath) --source \(source)"
            if !containsFocusCapsule(entries) {
                entries.append([
                    "matcher": "",
                    "hooks": [hookCommand(command, event: event)],
                ])
            }
            hooks[event] = entries
        }
        root["hooks"] = hooks
        writeJSON(root, path: path)
    }

    private static func addFlatHook(path: String, source: String, events: [String]) {
        var root = readJSON(path) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var entries = hooks[event] as? [[String: Any]] ?? []
            let command = "\(bridgePath) --source \(source)"
            if !containsFocusCapsule(entries) {
                entries.append(["command": command])
            }
            hooks[event] = entries
        }
        root["hooks"] = hooks
        writeJSON(root, path: path)
    }

    private static func containsFocusCapsule(_ entries: [[String: Any]]) -> Bool {
        entries.contains { entry in
            if let command = entry["command"] as? String, command.contains(marker) { return true }
            if let hooks = entry["hooks"] as? [[String: Any]] {
                return containsFocusCapsule(hooks)
            }
            return false
        }
    }

    private static func hookCommand(_ command: String, event: String) -> [String: Any] {
        [
            "type": "command",
            "command": command,
            "timeout": event == "PermissionRequest" ? 86_400 : 5,
        ]
    }

    private static func readJSON(_ path: String) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func writeJSON(_ object: [String: Any], path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
