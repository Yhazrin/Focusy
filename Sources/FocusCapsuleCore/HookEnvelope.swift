import Foundation

public enum FocusCapsuleSocket {
    public static var path: String {
        "/tmp/focuscapsule-\(getuid()).sock"
    }
}

public enum HookEnvelope {
    public static let sourceKey = "_focuscapsule_source"

    public static func decode(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public static func encode(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }
}
