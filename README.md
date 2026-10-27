# 🏝️ Dynamic Island Native for macOS (Monterey 12+)

A lightweight, battery-friendly (idle CPU ~0.0%) native Dynamic Island & living notch application for macOS. Built entirely with Swift, AppKit, and SwiftUI — no bloated Xcode installation required (~700 MB Command Line Tools is all you need).

---

## ✨ Key Features

1. **📱 MacBook Hardware Notch Design (Flush to Bezel):**
   - **0-Pixel Gap**: Sits seamlessly flush against the top physical bezel of your display, mirroring Apple's authentic MacBook Pro notch cutout.
   - Custom `NotchShape` geometry with flat top edge and fluid continuous squircle curvature at the bottom corners.
   - Specular bottom and side rim outline while merging natively into the black screen bezel at the top.

2. **👀 Smart Hover Peek Mode (Zero Screen Obstruction):**
   - Keeps your screen, window title bars, and browser tabs (Google Chrome, Safari, Arc) 100% clean and unobstructed.
   - In idle mode, tucks into a subtle micro-notch lip (4px) attached to the top bezel.
   - Moves down smoothly with iOS spring physics when you peek at the top ceiling of the screen, and auto-retracts when your cursor moves away.
   - Toggleable anytime via the menu bar icon (**Hover Peek Mode** vs **Always Visible**).

3. **🎵 Universal Now Playing & Media Controller:**
   - Directly interfaces with macOS private `MediaRemote.framework`.
   - Automatically captures playback from **Spotify, Apple Music, YouTube (Chrome, Safari, Arc, Brave, Edge), Netflix, VLC, Podcasts**, and more.
   - Displays real-time album artwork, live playback status, seek bar, and animated reactive equalizer waveform.
   - Global media controls: Play/Pause, Next Track, and Previous Track.

4. **🔋 Battery & MagSafe Charging HUD:**
   - Real-time battery status monitoring directly via native `IOKit.ps` (0% CPU impact).
   - Instant animated charging HUD when connecting/disconnecting MagSafe or power adapter.
   - Displays exact battery percentage with color-coded battery health indicator.

5. **⌨️ Global Keyboard Shortcut (`Option + Space`):**
   - Toggle expand/collapse of the Dynamic Island instantly from anywhere across macOS using Carbon `RegisterEventHotKey`.
   - Works system-wide across all apps, full-screen windows, and spaces without requiring invasive accessibility permissions.

6. **📊 Real-Time Mini System Stats (CPU & RAM Monitor):**
   - Real-time Mach kernel hardware telemetry (`host_statistics64`) integrated into the Controls tab.
   - Live CPU load percentage and physical RAM usage meter (e.g. `5.2 GB / 8.0 GB (65%)`).

7. **☕ Caffeinate / Anti-Sleep Toggle (Keep Mac Awake):**
   - One-click native power management assertion (`IOPMAssertionCreateWithName`) in the Controls tab.
   - Prevents your Mac from sleeping during long downloads, builds, or presentations without needing third-party apps like Amphetamine or terminal commands.

8. **⇪ Floating Caps Lock HUD Indicator:**
   - Clean, unobtrusive floating pill notification whenever Caps Lock is turned On or Off.
   - Auto-dismisses after 1.4 seconds with fluid spring animation.

9. **📋 Quick Clipboard History (Shelf Tab):**
   - Built-in clipboard manager seamlessly integrated into the Shelf tab (`Files Shelf` | `Clipboard`).
   - Automatically records copied text snippets without polling overhead.
   - Single-click to re-copy any previous snippet back to your pasteboard with instant visual checkmark feedback.

10. **🔊 Modern System Volume HUD:**
    - Replaces the legacy macOS volume bezel with a sleek, iOS-style animated volume capsule triggered by keyboard media keys (F11/F12).

11. **🎛️ iOS-Style Control Center:**
    - Quick toggles and status for **Wi-Fi** (with connected SSID detection).
    - Quick toggles for **Bluetooth**.
    - **Focus / Do Not Disturb** mode toggle.
    - Authentic iOS Control Center capsule volume slider with embedded speaker glyph and interactive drag scrubbing.

12. **📝 Quick Notes & Reminders:**
    - Instant task entry with a dedicated **"Add"** button or pressing `Enter`.
    - Full keyboard focus support inside floating panels.
    - Interactive iOS Reminders-style circular checkboxes with strikethrough animations.
    - Persistent local storage using `UserDefaults`.

13. **⏱️ Focus / Pomodoro Timer:**
    - Digital countdown with **SF Pro Rounded** typography.
    - Instant presets: 25 minutes (Pomodoro), 5 minutes (Short Break), 15 minutes (Long Break).

14. **📁 File Shelf (Drag & Drop):**
    - Temporary staging area for files from Desktop/Finder.
    - Native macOS file preview icons and drag-out support to any application or message.

15. **🏝️ Authentic iOS & macOS Experience:**
    - **Dead-Center Balanced Clock**: Both the time icon and digits are mathematically and optically aligned to dead-center.
    - **Click to Expand / Click Outside to Dismiss**: Zero intrusive popups while interacting with your applications.
    - **Smart Pass-Through**: All transparent areas surrounding the notch let mouse clicks pass straight through to underlying browser tabs and desktop windows.
    - **Menu Bar Tray Icon (🏝️)**:
      - **Left-Click**: Instant toggle to expand/collapse Dynamic Island.
      - **Right-Click**: Quick menu for Expand/Collapse, Hide/Show Island, **Toggle Hover Peek Mode**, and **Quit Dynamic Island**.

---

## 🛠️ System Requirements & Build Specs

* **Operating System**: macOS 12 Monterey or later.
* **Architecture**: Intel (`x86_64`) & Apple Silicon (`arm64`).
* **Binary Footprint**: Standalone **~1.8 MB** (Zero third-party dependencies / No Electron).
* **Toolchain**: Apple Command Line Tools (`xcode-select --install`).

---

## 🚀 Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/FerrelHD/Dynamic-Chemicvl.git
   cd Dynamic-Chemicvl
   ```

2. Build and run:
   ```bash
   chmod +x build.sh
   ./build.sh run
   ```

Or open the repository in **VS Code**, press **`Cmd + Shift + B`**, and select **Build & Run Dynamic Island**.

---

## ⌨️ Shortcuts & Gestures Reference

| Shortcut / Trigger | Action |
| :--- | :--- |
| **`Option + Space`** | Global Toggle Expand / Minimize Dynamic Island |
| **`Hover Top Screen Edge`** | Smoothly reveal / peek Dynamic Island (in Hover Peek mode) |
| **`Click Island Notch`** | Expand / Collapse Island |
| **`Click Outside`** | Automatically collapse back to compact notch |
| **`F11 / F12`** | Trigger sleek iOS Volume HUD |
| **`Caps Lock`** | Trigger Floating Caps Lock HUD indicator |
| **`Plug / Unplug MagSafe`** | Trigger Battery & MagSafe Charging HUD |
| **`Shelf Tab > Clipboard`** | View & 1-click re-copy recent clipboard history |
| **`Shelf Tab > Files`** | Drag & drop temporary file shelf |
| **`Menu Bar (🏝️) Right-Click`** | Toggle **Hover Peek Mode** on/off, Hide Island, Quit |

---

## 📄 License
Crafted by [FerrelHD](https://github.com/FerrelHD) with Native Swift, AppKit & SwiftUI.
