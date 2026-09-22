# Install and set up Snippy

Snippy is a menu-bar screenshot app for Mac. This guide is for the downloadable disk image. You do not need Xcode.

## What you need

- A Mac with Apple silicon
- macOS 15.2 or later

## 1. Download

Open the latest release and download **Snippy.dmg**:

[https://github.com/B43rli3/snippy/releases/latest](https://github.com/B43rli3/snippy/releases/latest)

## 2. Install

1. Open `Snippy.dmg`.
2. Drag **Snippy** onto the **Applications** folder.
3. Eject the disk image.
4. Open the Applications folder. Do not double-click Snippy yet.

macOS blocks the first launch because this download is not notarized by Apple. That is expected.

1. In Applications, **right-click Snippy** and choose **Open**.
2. Confirm **Open** in the dialog.
3. If macOS still blocks it, open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.

Snippy then sits in the menu bar. There is no Dock icon. Look for the scissors at the top right of the screen.

## 3. Allow screen recording

Snippy cannot freeze the screen until macOS allows it.

1. Press **Control+Shift+S**, or open the scissors menu and choose **New Screenshot**.
2. When macOS asks, open **System Settings**.
3. Go to **Privacy & Security → Screen & System Audio Recording**.
4. Turn **Snippy** on.

If Snippy is already listed and the switch is on, but a capture still does nothing, the switch belongs to an older copy. Turn Snippy **off**, then **on** again.

After the switch is on for this copy, press **Control+Shift+S** once more. Snippy restarts itself and opens the frozen screen. You do not need to click again after that.

## 4. Allow notifications

The first time a screenshot is saved, macOS asks for permission to show notifications. Choose **Allow**.

Snippy then shows a normal banner: **Screenshot saved**, with a small preview of that screenshot. Click the banner to open the file. The banner is the only confirmation. There is no sound.

If you dismissed the prompt, turn notifications on later under **System Settings → Notifications → Snippy**.

## 5. Take a screenshot

Press **Control+Shift+S** (⌃⇧S). The screen freezes and a small bar appears at the top.

| Button | What it does |
| --- | --- |
| **Screen** | Saves the whole display under the pointer |
| **Region** | Drag a rectangle |
| **Window** | Click a window |

**Escape** or the **X** cancels.

The last choice stays selected for the next shortcut. **Screen** is highlighted in the bar; click it to capture. **Region** and **Window** are ready to use immediately.

Each screenshot is:

- saved as a PNG in **Pictures → Screenshots**
- copied to the clipboard, so you can paste it

The scissors menu also has **New Screenshot**, **Open Last Screenshot**, **Open at Login**, and **Quit Snippy**.

## 6. Remove Snippy

1. Choose **Quit Snippy** in the scissors menu. If **Open at Login** is on, turn it off first.
2. Drag `Snippy.app` from Applications to the Trash.

Screenshots already saved in Pictures stay where they are.
