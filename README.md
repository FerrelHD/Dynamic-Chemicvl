# 🏝️ Dynamic Island Native for macOS (Monterey 12+)

A lightweight, battery-friendly (idle CPU ~0.0%) native Dynamic Island & living notch application for macOS. Built entirely with Swift, AppKit, and SwiftUI — no bloated Xcode installation required (~700 MB Command Line Tools is all you need).

---

## ✨ Key Features

1. **🎵 Universal Now Playing & Media Controller:**
   - Directly interfaces with macOS private `MediaRemote.framework`.
   - Automatically captures playback from **Spotify, Apple Music, YouTube (Chrome, Safari, Arc, Brave, Edge), Netflix, VLC, Podcasts**, and more.
   - Displays real-time album artwork, live playback status, seek bar, and animated reactive equalizer waveform.
   - Global media controls: Play/Pause, Next Track, and Previous Track.

2. **🔋 Battery & MagSafe Charging HUD:**
   - Real-time battery status monitoring directly via native `IOKit.ps` (0% CPU impact).
   - Instant animated charging HUD when connecting/disconnecting MagSafe or power adapter.
   - Displays exact battery percentage with color-coded battery health indicator.

3. **⌨️ Global Keyboard Shortcut (`Option + Space`):**
   - Toggle expand/collapse of the Dynamic Island instantly from anywhere across macOS using Carbon `RegisterEventHotKey`.
   - Works system-wide across all apps, full-screen windows, and spaces without requiring invasive accessibility permissions.

4. **📊 Real-Time Mini System Stats (CPU & RAM Monitor):**
   - Real-time Mach kernel hardware telemetry (`host_statistics64`) integrated into the Controls tab.
   - Live CPU load percentage and physical RAM usage meter (e.g. `5.2 GB / 8.0 GB (65%)`).

5. **☕ Caffeinate / Anti-Sleep Toggle (Keep Mac Awake):**
   - One-click native power management assertion (`IOPMAssertionCreateWithName`) in the Controls tab.
   - Prevents your Mac from sleeping during long downloads, builds, or presentations without needing third-party apps like Amphetamine or terminal commands.

6. **⇪ Floating Caps Lock HUD Indicator:**
   - Clean, unobtrusive floating pill notification whenever Caps Lock is turned On or Off.
   - Auto-dismisses after 1.4 seconds with fluid spring animation.

7. **📋 Quick Clipboard History (Shelf Tab):**
   - Built-in clipboard manager seamlessly integrated into the Shelf tab (`Files Shelf` | `Clipboard`).
   - Automatically records copied text snippets without polling overhead.
   - Single-click to re-copy any previous snippet back to your pasteboard with instant visual checkmark feedback.

8. **🔊 Modern System Volume HUD:**
   - Replaces the legacy macOS volume bezel with a sleek, iOS-style animated volume capsule triggered by keyboard media keys (F11/F12).

9. **🎛️ iOS-Style Control Center:**
   - Quick toggles and status for **Wi-Fi** (with connected SSID detection).
   - Quick toggles for **Bluetooth**.
   - **Focus / Do Not Disturb** mode toggle.
   - Authentic iOS Control Center capsule volume slider with embedded speaker glyph and interactive drag scrubbing.

10. **📝 Quick Notes & Reminders:**
    - Instant task entry with a dedicated **"Add"** button or pressing `Enter`.
    - Full keyboard focus support inside floating panels.
    - Interactive iOS Reminders-style circular checkboxes with strikethrough animations.
    - Persistent local storage using `UserDefaults`.

11. **⏱️ Focus / Pomodoro Timer:**
    - Digital countdown with **SF Pro Rounded** typography.
    - Instant presets: 25 minutes (Pomodoro), 5 minutes (Short Break), 15 minutes (Long Break).

12. **📁 File Shelf (Drag & Drop):**
    - Temporary staging area for files from Desktop/Finder.
    - Native macOS file preview icons and drag-out support to any application or message.

13. **🏝️ Authentic iOS Design & User Experience:**
    - **OLED Jet-Black Pill**: Centered clock (`HH:mm`) and clock glyph symmetrically aligned in idle mode.
    - **Click to Expand / Click Outside to Dismiss**: Zero intrusive auto-hover popups that interfere with web browsing.
    - **Smart Pass-Through**: All transparent areas surrounding the pill let mouse clicks pass straight through to underlying browser tabs and desktop windows.
    - **Menu Bar Tray Icon (🏝️)**:
      - **Left-Click**: Instant toggle to expand/collapse Dynamic Island.
      - **Right-Click**: Quick menu for Expand/Collapse, Hide/Show Island, and **Quit Dynamic Island**.

---

## 🛠️ System Requirements & Build Specs

* **Operating System**: macOS 12 Monterey or later.
* **Architecture**: Intel (`x86_64`) & Apple Silicon (`arm64`).
* **Binary Footprint**: Standalone **~1.6 MB** (Zero third-party dependencies / No Electron).
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

## ⌨️ Shortcuts Reference

| Shortcut / Trigger | Action |
| :--- | :--- |
| **`Option + Space`** | Global Toggle Expand / Minimize Dynamic Island |
| **`Click Island Pill`** | Expand / Collapse Island |
| **`Click Outside`** | Automatically collapse back to compact pill |
| **`F11 / F12`** | Trigger sleek iOS Volume HUD |
| **`Caps Lock`** | Trigger Floating Caps Lock HUD indicator |
| **`Plug / Unplug MagSafe`** | Trigger Battery & MagSafe Charging HUD |
| **`Shelf Tab > Clipboard`** | View & 1-click re-copy recent clipboard history |
| **`Shelf Tab > Files`** | Drag & drop file shelf |

---

## 📄 License
Crafted by [FerrelHD](https://github.com/FerrelHD) with Native Swift, AppKit & SwiftUI.
