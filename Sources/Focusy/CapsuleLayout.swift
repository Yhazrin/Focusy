import CoreGraphics

struct CapsuleMetrics: Equatable {
    var topDockHeight: CGFloat = 36
    var topDockWidth: CGFloat = 286
    var notchGapWidth: CGFloat = 0
    var hasNotch: Bool = false
    var shelfWidth: CGFloat = 44
    var shelfHeight: CGFloat = 184
    var floatingDiameter: CGFloat = 58
}

enum CapsuleDockMode: String {
    case floating
    case island
    case shelfLeft
    case shelfRight

    var isShelf: Bool {
        self == .shelfLeft || self == .shelfRight
    }
}

enum CapsuleLayout {
    static func size(isExpanded: Bool, mode: CapsuleDockMode, metrics: CapsuleMetrics) -> CGSize {
        if isExpanded {
            return CGSize(width: 430, height: 560)
        }
        switch mode {
        case .floating:
            return CGSize(width: metrics.floatingDiameter, height: metrics.floatingDiameter)
        case .island:
            return CGSize(width: metrics.topDockWidth, height: metrics.topDockHeight)
        case .shelfLeft, .shelfRight:
            return CGSize(width: metrics.shelfWidth, height: metrics.shelfHeight)
        }
    }

    static func cornerRadius(isExpanded: Bool, mode: CapsuleDockMode) -> CGFloat {
        if isExpanded { return 28 }
        switch mode {
        case .floating:
            return 999
        case .island:
            return 22
        case .shelfLeft, .shelfRight:
            return 24
        }
    }
}
