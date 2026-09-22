# Snippy

Menu-bar screenshot tool for macOS, modeled after Windows Snipping Tool (`Win + S`).

Snippy lives in the menu bar. Press **Fn+S** to freeze the screen, then choose **Screen**, **Region**, or **Window**. The PNG is saved to **Pictures → Screenshots** and copied to the clipboard.

The interface follows the system language (German and English).

## Requirements

- macOS 15.2 or later
- Xcode 16+ (or the bundled `scripts/build.sh` using the Xcode toolchain)

## Build

```bash
./scripts/build.sh
open build/Snippy.app
```

Or open `Snippy.xcodeproj` in Xcode, select your signing team, and run.

The first time you use Xcode’s command-line tools on a Mac, Apple asks you to accept the **Xcode license**:

```bash
sudo xcodebuild -license
```

That is a one-time Apple agreement. It is not a Snippy license. You only need it to compile with `xcodebuild` / Xcode. `scripts/build.sh` can build without it as long as Xcode.app is installed.

## Permissions

- **Accessibility** — so Fn+S works globally
- **Screen Recording** — so Snippy can capture the display

If the Globe key opens emoji, set it to **Do Nothing** in Keyboard settings.

## Usage

- **Fn+S** or menu **New Screenshot**
- Toolbar: Screen / Region / Window
- Escape cancels
- Menu: open last screenshot, start at login, quit

## License

MIT. See [LICENSE](LICENSE).
