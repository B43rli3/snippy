import AppKit
import ImageIO
import UserNotifications

/// Normale macOS-Mitteilung. Das Vorschaubild ist der ganze gespeicherte Screenshot, nicht ein Ausschnitt in voller Pixelgröße.
enum CaptureConfirmation {
    static func install() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    static func show(image: CGImage, url: URL) {
        install()
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert]) { granted, _ in
                    guard granted else { return }
                    deliver(image: image, url: url)
                }
            case .authorized, .provisional, .ephemeral:
                deliver(image: image, url: url)
            default:
                break
            }
        }
    }

    private static func deliver(image: CGImage, url: URL) {
        let content = UNMutableNotificationContent()
        content.title = L10n.savedTitle
        content.body = L10n.savedDetail
        content.userInfo = ["path": url.path]
        if let attachment = attachment(for: image, named: url.lastPathComponent) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Kleine Vorschau des ganzen Bildes. Ein Bitmap in voller Größe zeigte in der Mitteilung nur ein Stück des Bildschirms.
    private static func attachment(for image: CGImage, named name: String) -> UNNotificationAttachment? {
        let maxSide = 360
        let pixelWidth = image.width
        let pixelHeight = image.height
        let scale = min(1, Double(maxSide) / Double(max(pixelWidth, pixelHeight)))
        let width = max(1, Int((Double(pixelWidth) * scale).rounded()))
        let height = max(1, Int((Double(pixelHeight) * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let preview = context.makeImage() else { return nil }

        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Snippy-\(UUID().uuidString).png")
        guard let data = pngData(preview) else { return nil }
        do {
            try data.write(to: destination, options: .atomic)
            return try UNNotificationAttachment(
                identifier: name,
                url: destination,
                options: [
                    UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation,
                ]
            )
        } catch {
            return nil
        }
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

private final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let path = response.notification.request.content.userInfo["path"] as? String {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        completionHandler()
    }
}
