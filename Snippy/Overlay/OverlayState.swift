import Combine
import Foundation

/// Gewählter Aufnahmemodus. Die Zeichenfläche und die SwiftUI-Leiste lesen denselben Wert.
/// Der letzte Modus bleibt für den nächsten Shortcut erhalten.
final class OverlayState: ObservableObject, @unchecked Sendable {
    private static let modeKey = "snippy.captureMode"

    @Published var mode: CaptureMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.modeKey)
        mode = CaptureMode(rawValue: stored ?? "") ?? .region
    }
}
