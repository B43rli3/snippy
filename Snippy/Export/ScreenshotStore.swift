import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Speichert PNG nach Bilder/Screenshots und legt dieselbe Datei in die Zwischenablage.
final class ScreenshotStore {
    private let lastPathKey = "lastScreenshotPath"

    var lastScreenshotURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: lastPathKey) else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func save(_ image: CGImage) throws -> URL {
        try save(image, in: try screenshotsFolder(), updateLast: true)
    }

    @discardableResult
    func save(_ image: CGImage, in folder: URL, updateLast: Bool) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = uniqueFileURL(in: folder)
        let data = try pngData(from: image)
        try data.write(to: url, options: .atomic)
        copyToPasteboard(data: data, image: image)
        if updateLast {
            UserDefaults.standard.set(url.path, forKey: lastPathKey)
        }
        return url
    }

    func openLast() {
        guard let url = lastScreenshotURL else { return }
        NSWorkspace.shared.open(url)
    }

    func screenshotsFolder() throws -> URL {
        guard let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return pictures.appendingPathComponent("Screenshots", isDirectory: true)
    }

    func filename(for date: Date, locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? ""
        let isGerman = language == "de" || language.hasPrefix("de-")
        let prefix = isGerman ? "Bildschirmfoto" : "Screenshot"
        let separator = isGerman ? "um" : "at"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let day = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "HH.mm.ss"
        let time = dateFormatter.string(from: date)
        return "\(prefix) \(day) \(separator) \(time).png"
    }

    private func uniqueFileURL(in folder: URL) -> URL {
        let locale = L10n.usesGerman ? Locale(identifier: "de_DE") : Locale.current
        let base = filename(for: Date(), locale: locale)
        let stem = URL(fileURLWithPath: base).deletingPathExtension().lastPathComponent
        var url = folder.appendingPathComponent(base)
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(stem) \(suffix).png")
            suffix += 1
        }
        return url
    }

    private func copyToPasteboard(data: Data, image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pasteboard.writeObjects([nsImage])
        pasteboard.setData(data, forType: .png)
    }

    private func pngData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data as Data
    }
}
