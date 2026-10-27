# 🏝️ Dynamic Island Native for macOS (Monterey 12+)

A lightweight, battery-friendly (idle CPU 0.0%, ~20 MB RAM, 1.8 MB binary) native Dynamic Island & living notch application for macOS. Built entirely with Swift, AppKit, and SwiftUI — zero Electron, zero webviews, and zero third-party dependencies.

---

## ✨ Key Features

1. **📱 MacBook Hardware Notch Design (Concave Ears & Camera Dot):**
   - **0-Pixel Flush Gap**: Sits seamlessly flush against the top physical bezel of your display, mirroring Apple's authentic MacBook Pro notch cutout.
   - **Sleek Proportional Dimensions**: Idle mode sits snugly at `150 x 34 pt` (flush with macOS menu bar height), expanding smoothly to `350 x 54 pt` during Charging HUD.
   - **Concave Outward Ears**: Fluid tangent fillets (`earRadius = 6` compact, `earRadius = 8` HUD) connecting the top horizontal screen bezel down into the vertical sides of the notch.
   - **Hardware Camera Dot Cutout**: Subtle dark sensor lens detailing with glass reflection at top center.
   - **Mathematical Dead-Center**: Sub-pixel horizontal centering across all screen resolutions without coordinate drift.

2. **🪄 Automatic Fullscreen Hide & Desktop Standby:**
   - **Auto-Hide in Fullscreen**: Detects when any application enters macOS fullscreen mode (`visibleFrame.maxY >= frame.maxY - 2`) and automatically tucks into a 4px micro-handle so browser tabs (Chrome, Arc, Safari) and fullscreen video controls are 100% unobstructed.
   - **Auto-Standby on Desktop**: Automatically re-appears as an active idle notch as soon as you exit fullscreen or return to your desktop space.
   - **Smart Hover Peek**: In fullscreen, peek at the top 14pt bezel for 200ms to smoothly reveal the island on demand.

2. **⚡ Authentic iOS Charging Live Activity HUD:**
   - Triggers automatically when connecting/disconnecting power via native `IOKit.ps` event notifications.
   - **Circular Battery Gauge**: Vibrant green circular ring progress meter with white lightning bolt (`bolt.fill`).
   - **SF Pro Typography**: Bold "Charging" title + secondary "Charger connected" subtitle.
   - **Large Battery Percentage**: High-contrast, clean 24pt battery percentage (e.g. `70%`).

3. **🎯 Non-Activating Window Overlay (`.nonactivatingPanel`):**
   - Never steals key focus from your active apps (Google Chrome, VS Code, Terminal).
   - Your background apps stay active — clicks on Chrome tabs, close buttons (`x`), and links work immediately on the first click without requiring an activation click.

4. **👀 Smart Hover Peek Mode (Zero Screen Obstruction):**
   - Keeps your screen, window title bars, and browser tabs 100% clean and unobstructed.
   - In idle mode, tucks into a subtle micro-notch lip (4px) attached to the top bezel.
   - Smooth 200ms dwell delay: only reveals when intentionally peeking at the top 14pt ceiling, avoiding false triggers while clicking Chrome tabs.
   - Auto-retracts with spring physics when your cursor moves away.
   - Toggleable anytime via the menu bar icon (**Hover Peek Mode** vs **Always Visible**).

5. **⚡ Zero CPU Idle & Ultra-Low Resource Benchmark:**
   - **~20 MB RAM**: Minimal memory footprint.
   - **0.0% CPU Idle**: Timer pauses completely when idle. Audio equalizer waveform and countdown timers run on-demand only.
   - **1.8 MB Binary**: Pure compiled native Swift binary.

6. **🎵 Universal Now Playing & Media Controller:**
   - Directly interfaces with macOS private `MediaRemote.framework`.
   - Automatically captures playback from **Spotify, Apple Music, YouTube (Chrome, Safari, Arc, Brave, Edge), Netflix, VLC, Podcasts**, and more.
   - Displays real-time album artwork, live playback status, seek bar, and animated reactive equalizer waveform.
   - Global media controls: Play/Pause, Next Track, and Previous Track.

7. **🔋 Battery & MagSafe Status:**
   - Real-time battery status monitoring directly via native `IOKit.ps` (0% CPU impact).
   - Instant animated charging HUD when connecting/disconnecting MagSafe or power adapter.
   - Displays exact battery percentage with color-coded battery health indicator.

8. **⌨️ Global Keyboard Shortcut (`Option + Space`):**
   - Toggle expand/collapse of the Dynamic Island instantly from anywhere across macOS using Carbon `RegisterEventHotKey`.
   - Works system-wide across all apps, full-screen windows, and spaces without requiring invasive accessibility permissions.

9. **📊 Real-Time Mini System Stats (CPU & RAM Monitor):**
   - Real-time Mach kernel hardware telemetry (`host_statistics64`) integrated into the Controls tab.
   - Live CPU load percentage and physical RAM usage meter (e.g. `5.2 GB / 8.0 GB (65%)`).

10. **☕ Caffeinate / Anti-Sleep Toggle (Keep Mac Awake):**
    - One-click native power management assertion (`IOPMAssertionCreateWithName`) in the Controls tab.
    - Prevents your Mac from sleeping during long downloads, builds, or presentations without needing third-party apps like Amphetamine or terminal commands.

11. **⇪ Floating Caps Lock HUD Indicator:**
    - Clean, unobtrusive floating pill notification whenever Caps Lock is turned On or Off.
    - Auto-dismisses after 1.4 seconds with fluid spring animation.

12. **📋 Quick Clipboard History (Shelf Tab):**
    - Built-in clipboard manager seamlessly integrated into the Shelf tab (`Files Shelf` | `Clipboard`).
    - Automatically records copied text snippets without polling overhead.
    - Single-click to re-copy any previous snippet back to your pasteboard with instant visual checkmark feedback.

13. **🔊 Modern System Volume HUD:**
    - Replaces the legacy macOS volume bezel with a sleek, iOS-style animated volume capsule triggered by keyboard media keys (F11/F12).

14. **🎛️ iOS-Style Control Center:**
    - Quick toggles and status for **Wi-Fi** (with connected SSID detection).
    - Quick toggles for **Bluetooth**.
    - **Focus / Do Not Disturb** mode toggle.
    - Authentic iOS Control Center capsule volume slider with embedded speaker glyph and interactive drag scrubbing.

15. **📝 Quick Notes & Reminders:**
    - Instant task entry with a dedicated **"Add"** button or pressing `Enter`.
    - Interactive iOS Reminders-style circular checkboxes with strikethrough animations.
    - Persistent local storage using `UserDefaults`.

16. **⏱️ Focus / Pomodoro Timer:**
    - Digital countdown with **SF Pro Rounded** typography.
    - Instant presets: 25 minutes (Pomodoro), 5 minutes (Short Break), 15 minutes (Long Break).

17. **📁 File Shelf (Drag & Drop):**
    - Temporary staging area for files from Desktop/Finder.
    - Native macOS file preview icons and drag-out support to any application or message.

18. **🏝️ Authentic iOS & macOS Experience:**
    - **Dead-Center Balanced Clock**: Both the time icon and digits are mathematically and optically aligned to dead-center.
    - **Click to Expand / Click Outside to Dismiss**: Zero intrusive popups while interacting with your applications.
    - **Smart Pass-Through**: All transparent areas surrounding the notch let mouse clicks pass straight through to underlying browser tabs and desktop windows.
    - **Menu Bar Tray Icon (🏝️)**:
      - **Left-Click**: Instant toggle to expand/collapse Dynamic Island.
      - **Right-Click**: Quick menu for Expand/Collapse, Hide/Show Island, **Toggle Hover Peek Mode**, and **Quit Dynamic Island**.
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
| **`Option + Space`** | Primary Global Toggle to Expand / Collapse Dynamic Island |
| **`Click Top Notch Lip`** | Expand / Collapse Island directly from screen bezel |
| **`Click Outside`** | Automatically collapse back into tucked bezel lip & click app |
| **`F11 / F12`** | Trigger sleek iOS Volume HUD |
| **`Caps Lock`** | Trigger Floating Caps Lock HUD indicator |
| **`Plug / Unplug MagSafe`** | Trigger Battery & MagSafe Charging HUD |
| **`Shelf Tab > Clipboard`** | View & 1-click re-copy recent clipboard history |
| **`Shelf Tab > Files`** | Drag & drop temporary file shelf |
| **`Menu Bar (🏝️) Left-Click`** | Instant toggle Expand / Collapse Dynamic Island |
| **`Menu Bar (🏝️) Right-Click`** | Context menu: Show/Hide Island, Quit Dynamic Island |

---

## 📄 License
Crafted by [FerrelHD](https://github.com/FerrelHD) with Native Swift, AppKit & SwiftUI.
