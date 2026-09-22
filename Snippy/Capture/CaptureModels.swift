import AppKit

enum CaptureMode: String, CaseIterable, Identifiable {
    case screen
    case region
    case window

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screen:
            L10n.toolbarScreen
        case .region:
            L10n.toolbarRegion
        case .window:
            L10n.toolbarWindow
        }
    }

    var symbolName: String {
        switch self {
        case .screen:
            "display"
        case .region:
            "rectangle.dashed"
        case .window:
            "macwindow"
        }
    }
}

enum OverlayOutcome {
    case cancel
    case image(CGImage)
}

struct FrozenDisplay {
    let screen: NSScreen
    let displayID: CGDirectDisplayID
    let image: CGImage
}

struct CapturableWindow {
    let windowID: CGWindowID
    let frameCocoa: CGRect
    let title: String
}

struct FrozenSession {
    let displays: [FrozenDisplay]
    let windows: [CapturableWindow]
}

enum CaptureError: LocalizedError {
    case noDisplays
    case captureFailed
    case windowUnavailable

    var errorDescription: String? {
        switch self {
        case .noDisplays:
            L10n.errorNoDisplays
        case .captureFailed:
            L10n.errorCaptureFailed
        case .windowUnavailable:
            L10n.errorWindowUnavailable
        }
    }
}
