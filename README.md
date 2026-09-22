# Snippy

Snippy is a menu-bar screenshot app for macOS, in the spirit of the Windows Snipping Tool.

It stays in the menu bar. Press **Control+Shift+S** to freeze the screen, then choose **Screen**, **Region**, or **Window**. The picture is saved as a PNG in **Pictures → Screenshots** and copied to the clipboard. A normal macOS notification confirms the save and shows a preview of that screenshot.

The menu follows the system language (English or German).

## Download

The current disk image is on the [latest release](https://github.com/B43rli3/snippy/releases/latest). Open it and drag Snippy to Applications.

Install steps, the first-launch prompt, Screen Recording, and notifications are in **[Install and set up](docs/INSTALL.md)**.

## Requirements

- Mac with Apple silicon
- macOS 15.2 or later

## What you can do

- Freeze the screen and pick the whole display, a region, or a window
- Keep the last choice selected for the next shortcut
- Save a PNG and copy it to the clipboard
- See a notification with a preview of the saved screenshot
- Open the last screenshot, start Snippy at login, and quit from the menu

**Control+Shift+S** is the shortcut. The Globe / Fn key belongs to macOS (Siri), so Snippy does not use Fn+S. The shortcut does not need Accessibility access.

## Build from source

You need Xcode installed. From the repository root:

```bash
./scripts/build.sh
```

That compiles Snippy, signs it with your Apple Development identity when one is available, and copies it to `/Applications/Snippy.app`.

To build the downloadable disk image instead, without replacing the installed app:

```bash
./scripts/package-dmg.sh
```

The image is written to `dist/Snippy.dmg`.

The first time the Xcode command-line tools are used, Apple may ask you to accept the Xcode license:

```bash
sudo xcodebuild -license
```

That is Apple’s license, not Snippy’s. `scripts/build.sh` uses the Swift compiler inside Xcode.app.

You can also open `Snippy.xcodeproj` and run it from Xcode. Select your development team if Xcode asks.

## License

MIT. See [LICENSE](LICENSE).
