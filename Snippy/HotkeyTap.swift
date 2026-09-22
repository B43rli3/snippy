import AppKit
import Carbon

/// Globales Steuerung+Umschalt+S. Die Globus-Taste gehört macOS (Siri) und lässt sich nicht überschreiben.
/// Carbon braucht dafür keine Bedienungshilfen.
final class HotkeyTap: @unchecked Sendable {
    var onTrigger: (() -> Void)?

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func start() {
        if hotKey != nil {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<HotkeyTap>.fromOpaque(userData).takeUnretainedValue()
                owner.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            context,
            &handler
        )

        let hotKeyID = EventHotKeyID(signature: fourCharCode("SNPY"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(controlKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status != noErr {
            hotKey = nil
            fputs("Snippy: could not register Control+Shift+S (\(status))\n", stderr)
        }
    }

    func stop() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let handler {
            RemoveEventHandler(handler)
        }
        hotKey = nil
        handler = nil
    }

    private func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}
