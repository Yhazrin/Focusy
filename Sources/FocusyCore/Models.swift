import Foundation

public enum CapsuleSourceKind: String, Codable, CaseIterable, Sendable {
    case manual
    case cli
    case browser
    case terminal
    case appWindow
}

public enum JumpTargetKind: String, Codable, Sendable {
    case url
    case path
    case appBundle
}

public struct JumpTarget: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: JumpTargetKind
    public var label: String
    public var value: String
    public var appBundleId: String?

    public init(
        id: UUID = UUID(),
        kind: JumpTargetKind,
        label: String,
        value: String,
        appBundleId: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.value = value
        self.appBundleId = appBundleId
    }
}

public struct CapsuleEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sourceKind: CapsuleSourceKind
    public var sourceName: String
    public var title: String
    public var detail: String?
    public var url: URL?
    public var path: String?
    public var appBundleId: String?
    public var timestamp: Date
    public var jumpTarget: JumpTarget?

    public init(
        id: UUID = UUID(),
        sourceKind: CapsuleSourceKind,
        sourceName: String,
        title: String,
        detail: String? = nil,
        url: URL? = nil,
        path: String? = nil,
        appBundleId: String? = nil,
        timestamp: Date = Date(),
        jumpTarget: JumpTarget? = nil
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.sourceName = sourceName
        self.title = title
        self.detail = detail
        self.url = url
        self.path = path
        self.appBundleId = appBundleId
        self.timestamp = timestamp
        self.jumpTarget = jumpTarget
    }
}

public struct FocusCapsule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var startedAt: Date?
    public var isActive: Bool
    public var pinnedTargets: [JumpTarget]
    public var events: [CapsuleEvent]

    public init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date? = Date(),
        isActive: Bool = true,
        pinnedTargets: [JumpTarget] = [],
        events: [CapsuleEvent] = []
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.isActive = isActive
        self.pinnedTargets = pinnedTargets
        self.events = events
    }
}

public struct CapsuleStoreSnapshot: Codable, Equatable, Sendable {
    public var activeCapsuleId: UUID?
    public var capsules: [FocusCapsule]

    public init(activeCapsuleId: UUID? = nil, capsules: [FocusCapsule] = []) {
        self.activeCapsuleId = activeCapsuleId
        self.capsules = capsules
    }
}

public struct CapsuleProcessInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bundleId: String
    public var name: String
    public var category: ProcessCategory
    public var cpuUsage: Double
    public var memoryUsageMB: Double
    public var windowTitle: String?
    public var pid: Int32
    public var lastSeen: Date
    public var firstSeen: Date
    public var totalActiveTime: TimeInterval

    public init(
        id: UUID = UUID(),
        bundleId: String,
        name: String,
        category: ProcessCategory = .other,
        cpuUsage: Double = 0,
        memoryUsageMB: Double = 0,
        windowTitle: String? = nil,
        pid: Int32 = 0,
        lastSeen: Date = Date(),
        firstSeen: Date = Date(),
        totalActiveTime: TimeInterval = 0
    ) {
        self.id = id
        self.bundleId = bundleId
        self.name = name
        self.category = category
        self.cpuUsage = cpuUsage
        self.memoryUsageMB = memoryUsageMB
        self.windowTitle = windowTitle
        self.pid = pid
        self.lastSeen = lastSeen
        self.firstSeen = firstSeen
        self.totalActiveTime = totalActiveTime
    }
}

public enum ProcessCategory: String, Codable, CaseIterable, Sendable {
    case communication
    case development
    case productivity
    case entertainment
    case browser
    case terminal
    case system
    case other

    public var icon: String {
        switch self {
        case .communication: return "bubble.left.and.bubble.right"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .productivity: return "doc.text"
        case .entertainment: return "play.circle"
        case .browser: return "globe"
        case .terminal: return "apple.terminal"
        case .system: return "gearshape"
        case .other: return "app"
        }
    }

    public var displayName: String {
        switch self {
        case .communication: return "通讯"
        case .development: return "开发"
        case .productivity: return "效率"
        case .entertainment: return "娱乐"
        case .browser: return "浏览器"
        case .terminal: return "终端"
        case .system: return "系统"
        case .other: return "其他"
        }
    }
}
