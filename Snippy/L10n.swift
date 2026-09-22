import Foundation

enum L10n {
    static var usesGerman: Bool {
        if let first = Locale.preferredLanguages.first?.lowercased(), first.hasPrefix("de") {
            return true
        }
        if let langs = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String],
           let first = langs.first?.lowercased(),
           first.hasPrefix("de") {
            return true
        }
        return Locale.current.language.languageCode?.identifier == "de"
    }

    static func text(en: String, de: String) -> String {
        usesGerman ? de : en
    }

    static let appName = "Snippy"

    static var menuShortcut: String { text(en: "Shortcut: Fn+S", de: "Tastenkürzel: Fn+S") }
    static var menuNewCapture: String { text(en: "New Screenshot", de: "Neuer Screenshot") }
    static var menuOpenLast: String { text(en: "Open Last Screenshot", de: "Letzten Screenshot öffnen") }
    static var menuLogin: String { text(en: "Open at Login", de: "Beim Anmelden starten") }
    static var menuAccessibility: String { text(en: "Allow Accessibility…", de: "Bedienungshilfen erlauben…") }
    static var menuScreenRecording: String { text(en: "Allow Screen Recording…", de: "Bildschirmaufnahme erlauben…") }
    static var menuQuit: String { text(en: "Quit Snippy", de: "Snippy beenden") }

    static var toolbarScreen: String { text(en: "Screen", de: "Bildschirm") }
    static var toolbarRegion: String { text(en: "Region", de: "Bereich") }
    static var toolbarWindow: String { text(en: "Window", de: "Fenster") }
    static var toolbarCancel: String { text(en: "Cancel", de: "Abbrechen") }

    static var onboardingTitle: String { text(en: "Welcome to Snippy", de: "Willkommen bei Snippy") }
    static var onboardingContinue: String { text(en: "Continue", de: "Weiter") }
    static var onboardingBody: String {
        text(
            en: "Snippy stays in the menu bar. Press Fn+S to freeze the screen, then choose Screen, Region, or Window. Screenshots are saved to Pictures → Screenshots and copied to the clipboard.\n\nSnippy needs Accessibility (for Fn+S) and Screen Recording. If the Globe key opens emoji, set it to “Do Nothing” in Keyboard settings.",
            de: "Snippy bleibt in der Menüleiste. Mit Fn+S wird der Bildschirm eingefroren. Anschließend Bildschirm, Bereich oder Fenster wählen. Screenshots landen in Bilder → Screenshots und in der Zwischenablage.\n\nDafür braucht Snippy Bedienungshilfen (für Fn+S) und Bildschirmaufnahme. Wenn die Globus-Taste Emoji öffnet, stelle sie unter Tastatur auf „Keine Aktion“."
        )
    }

    static var permissionScreenTitle: String { text(en: "Screen Recording Needed", de: "Bildschirmaufnahme benötigt") }
    static var permissionScreenBody: String {
        text(
            en: "Snippy needs Screen Recording permission to freeze and save your screen.",
            de: "Snippy braucht die Bildschirmaufnahme, um den Bildschirm einzufrieren und zu speichern."
        )
    }
    static var permissionAccessibilityTitle: String { text(en: "Keyboard Access Needed", de: "Tastaturzugriff benötigt") }
    static var permissionAccessibilityBody: String {
        text(
            en: "Fn+S only works after you allow Snippy in Accessibility.",
            de: "Fn+S funktioniert nur, wenn Snippy unter Bedienungshilfen erlaubt ist."
        )
    }
    static var permissionOpenSettings: String { text(en: "Open Settings", de: "Einstellungen öffnen") }

    static var errorTitle: String { appName }
    static var errorOK: String { "OK" }
    static var errorNoDisplays: String { text(en: "No display was found.", de: "Es wurde kein Bildschirm gefunden.") }
    static var errorCaptureFailed: String { text(en: "The screenshot could not be captured.", de: "Der Screenshot konnte nicht aufgenommen werden.") }
    static var errorWindowUnavailable: String { text(en: "That window is no longer available.", de: "Dieses Fenster ist nicht mehr verfügbar.") }
}
