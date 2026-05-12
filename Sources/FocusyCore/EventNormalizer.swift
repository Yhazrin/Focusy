import Foundation

public enum EventNormalizer {
    public static func normalizeCLIEvent(_ raw: [String: Any], receivedAt: Date = Date()) -> CapsuleEvent? {
        let eventName = firstString(raw, keys: ["hook_event_name", "hookEventName", "event_name", "eventName"]) ?? "Event"
        let source = firstString(raw, keys: ["source", "_source", "tool_source"]) ?? "CLI"
        let toolName = firstString(raw, keys: ["tool_name", "toolName", "tool", "name"])
            ?? firstString(nested: raw, containers: ["tool", "payload", "data"], keys: ["name", "tool_name", "toolName"])
        let cwd = firstString(raw, keys: ["cwd", "working_directory", "project_dir"])
        let prompt = firstString(raw, keys: ["prompt", "message", "text", "summary", "status"])
        let title = cliTitle(eventName: eventName, source: source, toolName: toolName, prompt: prompt)
        let detail = cliDetail(raw: raw, prompt: prompt)
        let target = cwd.map { JumpTarget(kind: .path, label: "Project", value: $0) }

        return CapsuleEvent(
            sourceKind: .cli,
            sourceName: source.capitalized,
            title: title,
            detail: detail,
            path: cwd,
            timestamp: receivedAt,
            jumpTarget: target
        )
    }

    public static func normalizeBrowserContext(
        browserName: String,
        title: String?,
        urlString: String?,
        selectedText: String? = nil,
        bundleId: String? = nil,
        receivedAt: Date = Date()
    ) -> CapsuleEvent {
        let cleanTitle = trimmed(title) ?? browserName
        let cleanURL = trimmed(urlString).flatMap(URL.init(string:))
        let target = cleanURL.map { JumpTarget(kind: .url, label: browserName, value: $0.absoluteString, appBundleId: bundleId) }
        return CapsuleEvent(
            sourceKind: .browser,
            sourceName: browserName,
            title: cleanTitle,
            detail: trimmed(selectedText) ?? cleanURL?.host,
            url: cleanURL,
            appBundleId: bundleId,
            timestamp: receivedAt,
            jumpTarget: target
        )
    }

    public static func normalizeWindowContext(
        appName: String,
        title: String?,
        bundleId: String?,
        receivedAt: Date = Date()
    ) -> CapsuleEvent {
        let cleanTitle = trimmed(title) ?? appName
        let target = bundleId.map { JumpTarget(kind: .appBundle, label: appName, value: $0, appBundleId: $0) }
        return CapsuleEvent(
            sourceKind: .appWindow,
            sourceName: appName,
            title: cleanTitle,
            appBundleId: bundleId,
            timestamp: receivedAt,
            jumpTarget: target
        )
    }

    public static func normalizeTerminalContext(
        appName: String,
        title: String?,
        cwd: String?,
        bundleId: String?,
        receivedAt: Date = Date()
    ) -> CapsuleEvent {
        let cleanTitle = trimmed(title) ?? appName
        let target: JumpTarget?
        if let cwd = trimmed(cwd) {
            target = JumpTarget(kind: .path, label: "Project", value: cwd, appBundleId: bundleId)
        } else if let bundleId {
            target = JumpTarget(kind: .appBundle, label: appName, value: bundleId, appBundleId: bundleId)
        } else {
            target = nil
        }
        return CapsuleEvent(
            sourceKind: .terminal,
            sourceName: appName,
            title: cleanTitle,
            detail: trimmed(cwd),
            path: trimmed(cwd),
            appBundleId: bundleId,
            timestamp: receivedAt,
            jumpTarget: target
        )
    }

    private static func cliTitle(eventName: String, source: String, toolName: String?, prompt: String?) -> String {
        let normalized = eventName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        if let toolName, !toolName.isEmpty {
            return "\(source.capitalized) \(toolName)"
        }
        if let prompt = trimmed(prompt), !prompt.isEmpty {
            return String(prompt.prefix(64))
        }
        return "\(source.capitalized) \(normalized)"
    }

    private static func cliDetail(raw: [String: Any], prompt: String?) -> String? {
        if let prompt = trimmed(prompt) {
            return String(prompt.prefix(180))
        }
        if let input = firstDictionary(raw, keys: ["tool_input", "toolInput", "input", "arguments", "args", "params"]) {
            if let command = trimmed(input["command"] as? String) {
                return String(command.prefix(180))
            }
            if let filePath = trimmed(input["file_path"] as? String) {
                return (filePath as NSString).lastPathComponent
            }
        }
        return nil
    }

    private static func firstString(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = trimmed(dict[key] as? String) {
                return value
            }
        }
        return nil
    }

    private static func firstString(nested dict: [String: Any], containers: [String], keys: [String]) -> String? {
        for container in containers {
            guard let child = dict[container] as? [String: Any] else { continue }
            if let value = firstString(child, keys: keys) {
                return value
            }
        }
        return nil
    }

    private static func firstDictionary(_ dict: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = dict[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
