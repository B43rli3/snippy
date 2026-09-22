import AppKit
import ApplicationServices

enum PermissionOnboarding {
    static var suppressUI = false

    private static let didOnboardKey = "didShowOnboarding"
    private static let didAskScreenKey = "didAskScreenRecording"

    static func promptIfNeeded() {
        if suppressUI { return }
        guard !UserDefaults.standard.bool(forKey: didOnboardKey) else {
            return
        }

        _ = runAlert { alert in
            alert.messageText = L10n.onboardingTitle
            alert.informativeText = L10n.onboardingBody
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.onboardingContinue)
        }

        UserDefaults.standard.set(true, forKey: didOnboardKey)
        _ = ensureAccessibility(prompt: true)
    }

    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        if prompt, !suppressUI {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
            return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
        return false
    }

    static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        if suppressUI {
            return false
        }

        let alreadyAsked = UserDefaults.standard.bool(forKey: didAskScreenKey)
        CGRequestScreenCaptureAccess()
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        UserDefaults.standard.set(true, forKey: didAskScreenKey)

        // First attempt only shows the system prompt. Don't stack a second alert on top.
        if !alreadyAsked {
            return false
        }

        let response = runAlert { alert in
            alert.messageText = L10n.permissionScreenTitle
            alert.informativeText = L10n.permissionScreenBody
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.permissionOpenSettings)
            alert.addButton(withTitle: L10n.toolbarCancel)
        }
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
        return false
    }

    static func explainMissingAccessibility() {
        if suppressUI { return }
        let response = runAlert { alert in
            alert.messageText = L10n.permissionAccessibilityTitle
            alert.informativeText = L10n.permissionAccessibilityBody
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.permissionOpenSettings)
            alert.addButton(withTitle: L10n.toolbarCancel)
        }
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    static func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        openFirstAvailable(urls)
    }

    static func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        openFirstAvailable(urls)
    }

    static func showError(_ error: Error) {
        if suppressUI {
            fputs("Snippy error: \(error.localizedDescription)\n", stderr)
            return
        }
        _ = runAlert { alert in
            alert.messageText = L10n.errorTitle
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.errorOK)
        }
    }

    @discardableResult
    static func runAlert(_ configure: (NSAlert) -> Void) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        configure(alert)
        return alert.runModal()
    }

    private static func openFirstAvailable(_ rawURLs: [String]) {
        for raw in rawURLs {
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
