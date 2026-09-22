import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
enum ScreenCaptureService {
    static func freeze() async throws -> FrozenSession {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displays = try await captureDisplays(from: content)
        if displays.isEmpty {
            throw CaptureError.noDisplays
        }
        let allowedIDs = Set(content.windows.compactMap { window -> CGWindowID? in
            if window.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
                return nil
            }
            if window.frame.width < 40 || window.frame.height < 40 {
                return nil
            }
            return window.windowID
        })
        return FrozenSession(displays: displays, windows: windowsFromWindowList(allowedIDs: allowedIDs))
    }

    static func syntheticSession() -> FrozenSession {
        let displays: [FrozenDisplay] = NSScreen.screens.map { screen in
            let scale = max(screen.backingScaleFactor, 1)
            let width = max(1, Int((screen.frame.width * scale).rounded()))
            let height = max(1, Int((screen.frame.height * scale).rounded()))
            let image = SelfTest.makeImage(
                width: width,
                height: height,
                color: CGColor(red: 0.15, green: 0.35, blue: 0.8, alpha: 1)
            )
            return FrozenDisplay(screen: screen, displayID: ScreenGeometry.displayID(for: screen), image: image)
        }
        return FrozenSession(displays: displays, windows: windowsFromWindowList(allowedIDs: nil))
    }

    private static func captureDisplays(from content: SCShareableContent) async throws -> [FrozenDisplay] {
        var frozen: [FrozenDisplay] = []
        for screen in NSScreen.screens {
            let displayID = ScreenGeometry.displayID(for: screen)
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                continue
            }

            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = scDisplay.width
            configuration.height = scDisplay.height
            configuration.showsCursor = false
            configuration.colorSpaceName = CGColorSpace.sRGB

            let image: CGImage
            do {
                image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
            } catch {
                throw CaptureError.captureFailed
            }

            frozen.append(FrozenDisplay(screen: screen, displayID: displayID, image: image))
        }
        return frozen
    }

    private static func windowsFromWindowList(allowedIDs: Set<CGWindowID>?) -> [CapturableWindow] {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else {
            return []
        }

        var windows: [CapturableWindow] = []
        for info in infoList {
            guard let number = info[kCGWindowNumber as String] as? NSNumber else {
                continue
            }
            let rawID = CGWindowID(truncatingIfNeeded: number.intValue)
            if let allowedIDs, !allowedIDs.contains(rawID) {
                continue
            }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 {
                continue
            }
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            if alpha <= 0.05 {
                continue
            }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else {
                continue
            }
            if rect.width < 40 || rect.height < 40 {
                continue
            }
            let title = info[kCGWindowName as String] as? String ?? ""
            if title == "Snippy Overlay" || title == "Snippy Toolbar" {
                continue
            }
            windows.append(
                CapturableWindow(
                    windowID: rawID,
                    frameCocoa: ScreenGeometry.cocoaRect(fromQuartz: rect),
                    title: title
                )
            )
        }
        return windows
    }
}
