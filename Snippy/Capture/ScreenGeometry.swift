import AppKit
import CoreGraphics

enum ScreenGeometry {
    static func primaryScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID ?? 0
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// Converts a Quartz window rectangle (origin top-left of the main display) to Cocoa coordinates.
    static func cocoaRect(fromQuartz rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        var converted = rect
        converted.origin.y = primaryHeight - rect.origin.y - rect.height
        return converted
    }

    static func cocoaRect(fromQuartz rect: CGRect) -> CGRect {
        guard let primary = primaryScreen() else { return rect }
        return cocoaRect(fromQuartz: rect, primaryHeight: primary.frame.height)
    }

    static func viewRect(forGlobalRect globalRect: CGRect, screenFrame: CGRect) -> NSRect {
        globalRect.intersection(screenFrame).offsetBy(dx: -screenFrame.origin.x, dy: -screenFrame.origin.y)
    }

    static func crop(
        _ selectionInView: NSRect,
        viewSize: NSSize,
        image: CGImage
    ) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0, image.width > 0, image.height > 0 else {
            return .null
        }
        let scaleX = CGFloat(image.width) / viewSize.width
        let scaleY = CGFloat(image.height) / viewSize.height
        let rect = selectionInView.intersection(NSRect(origin: .zero, size: viewSize)).integral
        guard rect.width >= 1, rect.height >= 1 else {
            return .null
        }
        return CGRect(
            x: (rect.origin.x * scaleX).rounded(.down),
            y: ((viewSize.height - rect.origin.y - rect.height) * scaleY).rounded(.down),
            width: max(1, (rect.width * scaleX).rounded(.up)),
            height: max(1, (rect.height * scaleY).rounded(.up))
        )
    }
}
