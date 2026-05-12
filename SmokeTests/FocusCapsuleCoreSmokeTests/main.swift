import Foundation
import FocusCapsuleCore

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func requireValue<T>(_ value: T?, _ message: String) -> T {
    guard let value else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return value
}

let cliEvent = requireValue(EventNormalizer.normalizeCLIEvent([
    "hook_event_name": "PreToolUse",
    "_source": "codex",
    "tool_name": "Bash",
    "cwd": "/tmp/project",
    "tool_input": ["command": "swift test"],
]), "CLI event should normalize")

require(cliEvent.sourceKind == .cli, "CLI source kind")
require(cliEvent.sourceName == "Codex", "CLI source name")
require(cliEvent.title == "Codex Bash", "CLI title")
require(cliEvent.path == "/tmp/project", "CLI path")
require(cliEvent.jumpTarget?.kind == .path, "CLI jump target")

let browserEvent = EventNormalizer.normalizeBrowserContext(
    browserName: "Safari",
    title: "Apple",
    urlString: "https://developer.apple.com",
    bundleId: "com.apple.Safari"
)
require(browserEvent.sourceKind == .browser, "browser source kind")
require(browserEvent.url?.host == "developer.apple.com", "browser URL")
require(browserEvent.jumpTarget?.kind == .url, "browser jump")

let windowEvent = EventNormalizer.normalizeWindowContext(
    appName: "Lark",
    title: nil,
    bundleId: "com.bytedance.macos.feishu"
)
require(windowEvent.sourceKind == .appWindow, "window source kind")
require(windowEvent.title == "Lark", "window title fallback")
require(windowEvent.jumpTarget?.kind == .appBundle, "window jump")

let url = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("capsules.json")
let store = CapsuleStore(fileURL: url)
let target = JumpTarget(kind: .url, label: "Docs", value: "https://example.com")
let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
let event = CapsuleEvent(
    sourceKind: .manual,
    sourceName: "Quick Note",
    title: "Ship the capsule",
    timestamp: fixedDate,
    jumpTarget: target
)
let capsule = FocusCapsule(title: "Build", startedAt: fixedDate, pinnedTargets: [target], events: [event])
let snapshot = CapsuleStoreSnapshot(activeCapsuleId: capsule.id, capsules: [capsule])
try store.save(snapshot)
let loaded = try store.load()
require(loaded == snapshot, "store round trip")

print("FocusCapsuleCore smoke tests passed")
