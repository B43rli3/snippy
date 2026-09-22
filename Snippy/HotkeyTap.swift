import AppKit
import CoreGraphics

/// Global Fn+S listener. Carbon hotkeys cannot see the Fn/Globe modifier.
final class HotkeyTap: @unchecked Sendable {
    private static let sKeyCode: Int64 = 1
    private static let escapeKeyCode: Int64 = 53

    var onTrigger: (() -> Void)?
    var onEscape: (() -> Bool)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { eventTap != nil }

    func start() {
        if eventTap != nil {
            return
        }

        guard PermissionOnboarding.ensureAccessibility(prompt: false) else {
            return
        }

        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let tap = Unmanaged<HotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    func restart() {
        stop()
        start()
    }

    private func handle(
        proxy _: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if keyCode == Self.escapeKeyCode, type == .keyDown {
            let consumed = onEscape?() ?? false
            return consumed ? nil : Unmanaged.passUnretained(event)
        }

        let fnDown = flags.contains(.maskSecondaryFn)
        let hasOtherModifier =
            flags.contains(.maskCommand)
            || flags.contains(.maskControl)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskShift)

        // Only consume S when the event itself has Fn. A sticky fnHeld must never eat normal typing.
        if fnDown, !hasOtherModifier, keyCode == Self.sKeyCode {
            if type == .keyDown {
                onTrigger?()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
