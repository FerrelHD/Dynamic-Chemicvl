# 🏝️ NotchFlow

A lightweight, battery-friendly native Dynamic Island & living notch application for macOS. Built entirely with pure Swift, AppKit, and SwiftUI — zero Electron, zero webviews, and zero dependencies.

---

## ✨ Features

- **MacBook Bezel Integration**: Sits flush against the physical display bezel with smooth Apple G2 concave curves, automatic fullscreen auto-hide, and smart hover peek.
- **Universal Now Playing & Lyrics**: Real-time media playback controls (Spotify, Apple Music, YouTube), audio scrubber, dynamic album art ambient glow, and synchronized lyrics.
- **Unified iOS HUD Notifications**: Clean floating pills for Volume, MagSafe Charging, Wi-Fi, Bluetooth, and Caps Lock.
- **Control Center & Tools**: Quick system toggles, live CPU & RAM meters, Focus Pomodoro timer, persistent Notes/To-do, and File/Clipboard Shelf.
- **Customizable Spring Physics**: Fine-tune bounciness and duration directly from the built-in Settings tab.

---

## ⌨️ Shortcuts & Gestures

| Trigger | Action |
| :--- | :--- |
| **`Option + Space`** | Global shortcut to Expand / Collapse notch |
| **`Click Notch`** | Expand / Collapse notch directly |
| **`2-Finger Swipe`** | Switch between tabs (Control, Music, Notes, Devices, Shelf) |
| **`Click Outside`** | Automatically collapse back into the bezel |
| **`Menu Bar (🏝️)`** | Quick toggle and settings menu |

---

## 🚀 Getting Started

### Download
Download the latest **`NotchFlow-1.0.0.dmg`** installer directly from the repository.

### Build from Source
Requires macOS 12+ and Apple Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/FerrelHD/Dynamic-Chemicvl.git
cd Dynamic-Chemicvl
./build.sh run       # Compile and launch
./build.sh dmg       # Generate universal DMG installer
```

---

## 📄 License
Crafted with ❤️ by [FerrelHD](https://github.com/FerrelHD) using Native Swift, AppKit & SwiftUI.
