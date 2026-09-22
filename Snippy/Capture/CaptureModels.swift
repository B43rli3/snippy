import AppKit

/// Bildschirm, Bereich oder Fenster. Die Leiste schaltet nur den Modus; die Aufnahme kommt aus dem eingefrorenen Bild.
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

/// Ergebnis des Overlays: abgebrochen oder das fertige Bild.
enum OverlayOutcome {
    case cancel
    case image(CGImage)
}

/// Ein Bildschirm samt seiner Aufnahme in echten Pixeln.
struct FrozenDisplay {
    let screen: NSScreen
    let displayID: CGDirectDisplayID
    let image: CGImage
}

/// Ein fremdes Fenster, das im Fenstermodus gewählt werden kann.
struct CapturableWindow {
    let windowID: CGWindowID
    let frameCocoa: CGRect
}

/// Alle Bildschirme und Fenster zum Zeitpunkt des Einfrierens.
struct FrozenSession {
    let displays: [FrozenDisplay]
    let windows: [CapturableWindow]
}

enum CaptureError: LocalizedError {
    case noDisplays
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .noDisplays:
            L10n.errorNoDisplays
        case .captureFailed:
            L10n.errorCaptureFailed
        }
    }
}
