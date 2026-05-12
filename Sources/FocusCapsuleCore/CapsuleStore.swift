import Foundation

public final class CapsuleStore: @unchecked Sendable {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.fileURL = base.appendingPathComponent("Focus Capsule", isDirectory: true)
                .appendingPathComponent("capsules.json")
        }
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> CapsuleStoreSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let capsule = FocusCapsule(title: "Today")
            return CapsuleStoreSnapshot(activeCapsuleId: capsule.id, capsules: [capsule])
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CapsuleStoreSnapshot.self, from: data)
    }

    public func save(_ snapshot: CapsuleStoreSnapshot) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
