# NotchFlow

A native macOS status bar and notch companion built with Swift, AppKit, and SwiftUI. It runs without Electron, web views, or external dependencies.

---

## Features

The interface rests against the MacBook display notch and expands on click or hover.

### System Monitor
Monitors CPU load, memory usage, disk space, battery status, and live network throughput (upload and download rates) queried directly through Darwin kernel APIs. Uses a monochrome display that flags high loads in amber or red.

### Music and Lyrics
Controls playback for media players including Spotify, Apple Music, and web browsers. Displays the track title, artist, playback scrubber, album artwork with background glow, and time-synchronized lyrics.

### Timer and Clock
Provides countdown timers and Pomodoro focus intervals with circular progress tracking and haptic feedback.

### Reminders
A quick-entry checklist stored locally. Tasks can be added, marked complete, or deleted in one click.

### Calendar and Agenda
A monthly calendar with a fixed 42-cell grid to prevent layout shifting between months. Clicking any date filters the agenda to that day, displays scheduled items, and allows adding new events directly to that date.

### Connected Devices
Displays battery levels for connected Bluetooth accessories, including AirPods, keyboards, mice, trackpads, and paired iOS devices.

### Shelf and Clipboard
A temporary drag-and-drop staging area for files and images, paired with a local clipboard history manager for copying and clearing recent snippets.

### Living Mascot
An optional virtual companion that rests in the notch with interactive gaze tracking, blink cycles, and sleep states.

### Settings Window
A dedicated preferences window to toggle modules, configure keyboard shortcuts, adjust spring animation durations, and manage system permissions.

---

## Heads-Up Notifications

Presents system status changes as compact pill banners anchored to the notch:
- Volume adjustments
- Power adapter connection and battery level changes
- Wi-Fi and Bluetooth state toggles
- Caps Lock indicator
- Incoming calls and AirDrop transfers

---

## Navigation and Shortcuts

| Action | Shortcut or Gesture |
| :--- | :--- |
| Toggle expanded notch | `Option + Space` or click the notch |
| Switch tabs | Two-finger horizontal swipe on trackpad, or click the bottom page dots |
| Collapse notch | Click anywhere outside the panel |
| Open settings | Click the gear icon in the page dots bar or choose Settings from the menu bar item |

---

## Building from Source

### Requirements
- macOS 12.0 or later
- Xcode Command Line Tools (`xcode-select --install`)
- Apple Silicon or Intel processor

### Build Commands

```bash
git clone https://github.com/FerrelHD/Dynamic-Chemicvl.git
cd Dynamic-Chemicvl

# Build and run
./build.sh run

# Build the application bundle (.app)
./build.sh app

# Create a DMG installer
./build.sh dmg
```

---

## Author
Developed by [FerrelHD](https://github.com/FerrelHD) in Swift, AppKit, and SwiftUI.
