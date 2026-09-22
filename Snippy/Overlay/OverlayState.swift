import Combine
import Foundation

final class OverlayState: ObservableObject, @unchecked Sendable {
    @Published var mode: CaptureMode = .region
}
