import AppKit
import Foundation
import FocusyCore

@MainActor
final class ProcessMonitor {
    private let model: AppModel
    private var timer: Timer?
    private var lastFrontBundleId: String?
    private var lastEventSignature: String = ""
    private var switchStartTime: Date?
    private var activeProcesses: [String: CapsuleProcessInfo] = [:]
    private var isIdle: Bool = false
    private var idleStartTime: Date?
    private let idleThreshold: TimeInterval = 180
    private let switchDebounce: TimeInterval = 5

    private let categoryMappings: [String: ProcessCategory] = [
        "com.tinlokim.KeChat": .communication,
        "com.tencent.xinWeChat": .communication,
        "com.apple.MobileSMS": .communication,
        "us.zoom.xos": .communication,
        "com.microsoft.teams": .communication,
        "com.skype.skype": .communication,
        "com.slack.Slack": .communication,
        "com.hnc.Discord": .communication,
        "com.telegram.desktop": .communication,
        "com.whatsapp.Whats": .communication,
        "com.line.Line": .communication,
        "com.linkedin.LinkedIn": .communication,

        "com.apple.dt.Xcode": .development,
        "com.microsoft.VSCode": .development,
        "com.sublimetext.4": .development,
        "com.jetbrains.intellij": .development,
        "com.jetbrains.AppCode": .development,
        "com.google.AndroidStudio": .development,
        "com.apple.Terminal": .terminal,
        "com.mitchellh.ghostty": .terminal,
        "com.googlecode.iterm2": .terminal,
        "dev.warp.Warp-Stable": .terminal,
        "com.apple.dt.Instruments": .development,

        "com.apple.Pages": .productivity,
        "com.apple.Numbers": .productivity,
        "com.apple.Keynote": .productivity,
        "com.microsoft.Word": .productivity,
        "com.microsoft.Excel": .productivity,
        "com.microsoft.PowerPoint": .productivity,
        "com.apple.Notes": .productivity,
        "com.notion.id": .productivity,
        "com.linear": .productivity,
        "com.figma.Desktop": .productivity,
        "com.sketch.application": .productivity,

        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "org.mozilla.firefox": .browser,
        "com.microsoft.edgemac": .browser,
        "com.brave.Browser": .browser,
        "com.vivaldi.Vivaldi": .browser,

        "com.apple.Music": .entertainment,
        "com.spotify.client": .entertainment,
        "com.netflix.Netflix": .entertainment,
        "com.youtube.YouTube": .entertainment,
        "tv.twitch.TwitchApp": .entertainment,
        "com.reddit.reddit": .entertainment,
        "com.twitter.twitter": .entertainment,
    ]

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanAndUpdate()
            }
        }
        scanAndUpdate()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func scanAndUpdate() {
        refreshPermissions()
        captureIdleState()

        guard !isIdle else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleId = frontApp?.bundleIdentifier
        let appName = frontApp?.localizedName ?? bundleId ?? "Unknown"

        let frontBundleId = bundleId ?? "unknown"

        if frontBundleId == Bundle.main.bundleIdentifier {
            return
        }

        let now = Date()
        if frontBundleId != lastFrontBundleId {
            if let lastBundleId = lastFrontBundleId,
               let startTime = switchStartTime {
                let duration = now.timeIntervalSince(startTime)
                if duration >= switchDebounce {
                    recordAppSwitch(from: lastBundleId, to: frontBundleId, duration: duration)
                }
            }
            switchStartTime = now
        }
        lastFrontBundleId = frontBundleId

        let windowTitle = frontWindowTitle(pid: frontApp?.processIdentifier ?? 0)
        let (cpu, memory) = getResourceUsage(pid: frontApp?.processIdentifier ?? 0)
        let category = categorize(bundleId: frontBundleId, appName: appName)

        if var process = activeProcesses[frontBundleId] {
            process.cpuUsage = cpu
            process.memoryUsageMB = memory
            process.windowTitle = windowTitle
            process.lastSeen = now
            process.totalActiveTime += 3
            activeProcesses[frontBundleId] = process
        } else {
            let process = CapsuleProcessInfo(
                bundleId: frontBundleId,
                name: appName,
                category: category,
                cpuUsage: cpu,
                memoryUsageMB: memory,
                windowTitle: windowTitle,
                pid: frontApp?.processIdentifier ?? 0,
                lastSeen: now,
                firstSeen: now,
                totalActiveTime: 3
            )
            activeProcesses[frontBundleId] = process
        }

        let event = createEvent(
            bundleId: frontBundleId,
            appName: appName,
            windowTitle: windowTitle,
            category: category
        )

        let signature = "\(event.sourceKind.rawValue)|\(event.sourceName)|\(event.title)"
        if signature != lastEventSignature && !isSameAppFocus(event) {
            lastEventSignature = signature
            model.appendEvent(event)
        }

        model.updateActiveProcess(activeProcesses[frontBundleId])
    }

    private func captureIdleState() {
        let now = Date()

        let isMouseIdle = checkMouseIdle()
        let isKeyboardIdle = checkKeyboardIdle()

        if isMouseIdle && isKeyboardIdle {
            if !isIdle {
                idleStartTime = now
                isIdle = true
                model.recordIdle()
            }
        } else {
            if isIdle {
                if let start = idleStartTime {
                    let duration = now.timeIntervalSince(start)
                    if duration >= 60 {
                        model.recordIdleEnd(duration: duration)
                    }
                }
                isIdle = false
                idleStartTime = nil
            }
        }
    }

    private func checkMouseIdle() -> Bool {
        return false
    }

    private func checkKeyboardIdle() -> Bool {
        return false
    }

    private func recordAppSwitch(from: String, to: String, duration: TimeInterval) {
        guard let fromProcess = activeProcesses[from] else { return }
        model.recordAppSwitch(
            fromApp: fromProcess.name,
            toApp: activeProcesses[to]?.name ?? "Unknown",
            duration: duration
        )
    }

    private func isSameAppFocus(_ event: CapsuleEvent) -> Bool {
        if let last = model.lastEvent {
            return last.sourceKind == event.sourceKind &&
                   last.sourceName == event.sourceName &&
                   abs(last.timestamp.timeIntervalSince(event.timestamp)) < 8
        }
        return false
    }

    private func createEvent(bundleId: String, appName: String, windowTitle: String?, category: ProcessCategory) -> CapsuleEvent {
        switch category {
        case .browser:
            if bundleId == "com.google.Chrome" {
                return captureChromeContext(appName: appName, bundleId: bundleId, fallbackTitle: windowTitle)
            } else if bundleId == "com.apple.Safari" {
                return captureSafariContext(appName: appName, bundleId: bundleId, fallbackTitle: windowTitle)
            }
            return EventNormalizer.normalizeBrowserContext(
                browserName: appName,
                title: windowTitle,
                urlString: nil,
                bundleId: bundleId
            )
        case .terminal:
            return EventNormalizer.normalizeTerminalContext(
                appName: appName,
                title: windowTitle,
                cwd: nil,
                bundleId: bundleId
            )
        default:
            return EventNormalizer.normalizeWindowContext(
                appName: appName,
                title: windowTitle,
                bundleId: bundleId
            )
        }
    }

    private func captureChromeContext(appName: String, bundleId: String?, fallbackTitle: String?) -> CapsuleEvent {
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

    private func captureSafariContext(appName: String, bundleId: String?, fallbackTitle: String?) -> CapsuleEvent {
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

    private func categorize(bundleId: String, appName: String) -> ProcessCategory {
        if let category = categoryMappings[bundleId] {
            return category
        }

        let lowerName = appName.lowercased()
        if lowerName.contains("slack") || lowerName.contains("wechat") || lowerName.contains("微信") ||
           lowerName.contains("钉钉") || lowerName.contains("dingtalk") || lowerName.contains("zoom") ||
           lowerName.contains("teams") || lowerName.contains("telegram") {
            return .communication
        }
        if lowerName.contains("xcode") || lowerName.contains("code") || lowerName.contains("terminal") ||
           lowerName.contains("terminal") || lowerName.contains("iterm") || lowerName.contains("warp") {
            return lowerName.contains("terminal") || lowerName.contains("warp") || lowerName.contains("iterm") ? .terminal : .development
        }
        if lowerName.contains("safari") || lowerName.contains("chrome") || lowerName.contains("firefox") ||
           lowerName.contains("browser") || lowerName.contains("浏览器") {
            return .browser
        }
        if lowerName.contains("spotify") || lowerName.contains("music") || lowerName.contains("netflix") ||
           lowerName.contains("youtube") || lowerName.contains("bilibili") || lowerName.contains("twitch") {
            return .entertainment
        }
        if lowerName.contains("pages") || lowerName.contains("numbers") || lowerName.contains("keynote") ||
           lowerName.contains("word") || lowerName.contains("excel") || lowerName.contains("powerpoint") ||
           lowerName.contains("notion") || lowerName.contains("figma") {
            return .productivity
        }

        return .other
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

    private func getResourceUsage(pid: pid_t) -> (cpu: Double, memory: Double) {
        guard pid > 0 else { return (0, 0) }

        var info = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, MemoryLayout<proc_bsdinfo>.size)
        guard size > 0 else { return (0, 0) }

        let memoryMB = Double(info.pbi_darwin_task) / 1_048_576

        return (0, memoryMB)
    }

    private func refreshPermissions() {
        model.refreshPermissions()
    }
}

import Darwin

private var PROC_PIDTBSDINFO: Int32 { return 3 }

private struct proc_bsdinfo {
    var pbi_flags: UInt32 = 0
    var pbi_status: UInt32 = 0
    var pbi_xstatus: UInt32 = 0
    var pbi_pid: UInt32 = 0
    var pbi_ppid: UInt32 = 0
    var pbi_uid: uid_t = 0
    var pbi_gid: gid_t = 0
    var pbi_ruid: uid_t = 0
    var pbi_rgid: gid_t = 0
    var pbi_svuid: uid_t = 0
    var pbi_svgid: gid_t = 0
    var rfu_1: UInt32 = 0
    var pbi_comm: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_nfiles: UInt32 = 0
    var pbi_pgid: UInt32 = 0
    var pbi_pjobc: UInt32 = 0
    var e_tdev: UInt32 = 0
    var e_tpgid: UInt32 = 0
    var pbi_nice: Int32 = 0
    var pbi_darwin_task: UInt64 = 0
    var pbi_start_tvsec: Int64 = 0
    var pbi_start_tvusec: Int64 = 0
}

private func proc_pidinfo(_ pid: pid_t, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int) -> Int32 {
    return -1
}
