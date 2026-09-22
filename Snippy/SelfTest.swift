import AppKit
import CoreGraphics
import Foundation

/// Prüft Ausschnitt, Koordinaten, Dateinamen und PNG, ohne die Oberfläche zu öffnen.
enum SelfTest {
    static func runUnitTests() -> Bool {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        // Crop: 50x50 pt view, 100x100 px image (2x). Selection at (10,10) 20x20 in bottom-left view coords.
        let image = makeImage(width: 100, height: 100, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let crop = ScreenGeometry.crop(
            NSRect(x: 10, y: 10, width: 20, height: 20),
            viewSize: NSSize(width: 50, height: 50),
            image: image
        )
        expect(crop.origin.x == 20, "crop.x should be 20, got \(crop.origin.x)")
        expect(crop.origin.y == 40, "crop.y should be 40 (flipped), got \(crop.origin.y)")
        expect(crop.width == 40, "crop.width should be 40, got \(crop.width)")
        expect(crop.height == 40, "crop.height should be 40, got \(crop.height)")
        expect(image.cropping(to: crop) != nil, "cropped image should exist")

        let empty = ScreenGeometry.crop(.zero, viewSize: NSSize(width: 50, height: 50), image: image)
        expect(empty.isNull || empty.width < 1, "zero selection should not crop")

        let quartz = CGRect(x: 0, y: 0, width: 100, height: 50)
        let cocoa = ScreenGeometry.cocoaRect(fromQuartz: quartz, primaryHeight: 1080)
        expect(cocoa.origin.x == 0, "cocoa.x should be 0")
        expect(cocoa.origin.y == 1030, "cocoa.y should be 1030, got \(cocoa.origin.y)")
        expect(cocoa.width == 100 && cocoa.height == 50, "cocoa size should be preserved")

        let screenFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let global = CGRect(x: 2000, y: 100, width: 200, height: 150)
        let view = ScreenGeometry.viewRect(forGlobalRect: global, screenFrame: screenFrame)
        expect(view.origin.x == 80, "view.x should be 80, got \(view.origin.x)")
        expect(view.origin.y == 100, "view.y should be 100, got \(view.origin.y)")

        let store = ScreenshotStore()
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 21
        components.hour = 22
        components.minute = 14
        components.second = 3
        let date = calendar.date(from: components)!

        let german = store.filename(for: date, locale: Locale(identifier: "de_DE"))
        expect(
            german == "Bildschirmfoto 2026-09-21 um 22.14.03.png",
            "German filename mismatch: \(german)"
        )
        let english = store.filename(for: date, locale: Locale(identifier: "en_US"))
        expect(
            english == "Screenshot 2026-09-21 at 22.14.03.png",
            "English filename mismatch: \(english)"
        )

        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SnippySelfTest-\(UUID().uuidString)", isDirectory: true)
            let url = try store.save(image, in: folder, updateLast: false)
            expect(FileManager.default.fileExists(atPath: url.path), "saved PNG missing at \(url.path)")
            expect(url.pathExtension == "png", "saved file should be png")
            let data = try Data(contentsOf: url)
            expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]), "file is not a PNG")
            let pasteboardData = NSPasteboard.general.data(forType: .png)
            expect(pasteboardData != nil, "clipboard should contain PNG")
            try? FileManager.default.removeItem(at: folder)
        } catch {
            failures.append("save failed: \(error.localizedDescription)")
        }

        if failures.isEmpty {
            print("Self-test passed")
            return true
        }

        fputs("Self-test failed:\n", stderr)
        for failure in failures {
            fputs(" - \(failure)\n", stderr)
        }
        return false
    }

    static func makeImage(width: Int, height: Int, color: CGColor) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
