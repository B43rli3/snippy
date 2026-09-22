import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    var onQuit: (() -> Void)?
    var onOpenLast: (() -> Void)?
    var onNewCapture: (() -> Void)?
    var lastScreenshotExists: (() -> Bool)?
    var onRetryHotkey: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var loginItem: NSMenuItem?
    private var lastItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var screenItem: NSMenuItem?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: L10n.appName
            )
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self

        let shortcut = NSMenuItem(
            title: L10n.menuShortcut,
            action: nil,
            keyEquivalent: ""
        )
        shortcut.isEnabled = false
        menu.addItem(shortcut)

        let capture = NSMenuItem(
            title: L10n.menuNewCapture,
            action: #selector(newCapture),
            keyEquivalent: ""
        )
        capture.target = self
        menu.addItem(capture)
        menu.addItem(.separator())

        let last = NSMenuItem(
            title: L10n.menuOpenLast,
            action: #selector(openLast),
            keyEquivalent: ""
        )
        last.target = self
        menu.addItem(last)
        lastItem = last

        menu.addItem(.separator())

        let login = NSMenuItem(
            title: L10n.menuLogin,
            action: #selector(toggleLogin),
            keyEquivalent: ""
        )
        login.target = self
        menu.addItem(login)
        loginItem = login

        menu.addItem(.separator())

        let accessibility = NSMenuItem(
            title: L10n.menuAccessibility,
            action: #selector(openAccessibility),
            keyEquivalent: ""
        )
        accessibility.target = self
        menu.addItem(accessibility)
        accessibilityItem = accessibility

        let screen = NSMenuItem(
            title: L10n.menuScreenRecording,
            action: #selector(openScreenRecording),
            keyEquivalent: ""
        )
        screen.target = self
        menu.addItem(screen)
        screenItem = screen

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: L10n.menuQuit,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        lastItem?.isEnabled = lastScreenshotExists?() ?? false
        loginItem?.state = LoginItemManager.isEnabled ? .on : .off
        let trusted = PermissionOnboarding.ensureAccessibility(prompt: false)
        accessibilityItem?.isHidden = trusted
        screenItem?.isHidden = CGPreflightScreenCaptureAccess()
        if trusted {
            onRetryHotkey?()
        }
    }

    @objc private func newCapture() {
        onNewCapture?()
    }

    @objc private func openLast() {
        onOpenLast?()
    }

    @objc private func toggleLogin() {
        do {
            try LoginItemManager.setEnabled(!LoginItemManager.isEnabled)
        } catch {
            PermissionOnboarding.showError(error)
        }
    }

    @objc private func openAccessibility() {
        PermissionOnboarding.openAccessibilitySettings()
    }

    @objc private func openScreenRecording() {
        PermissionOnboarding.openScreenRecordingSettings()
    }

    @objc private func quitApp() {
        onQuit?()
    }
}
