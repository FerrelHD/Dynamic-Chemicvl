# 🏝️ NotchFlow

A lightweight, battery-friendly native Dynamic Island & living notch application for macOS. Built entirely with pure Swift, AppKit, and SwiftUI — zero Electron, zero webviews, and zero external dependencies.

---

## ✨ Features & Island Tabs

NotchFlow integrates directly with the MacBook display notch with Apple G2 squircle curvature, responsive spring physics, and smart auto-hide.

1. **📊 System Monitor**
   - Clean, minimalist Apple monochrome hardware vitals.
   - Real-time CPU load, memory utilization, live download/upload network bandwidth via Darwin kernel APIs, disk free capacity, and battery power status.
   - Non-intrusive warning colors only when resources are critically loaded.

2. **🎵 Music & Synchronized Lyrics**
   - Universal media playback controls (Spotify, Apple Music, YouTube Music, browsers).
   - Audio scrubber, track telemetry, dynamic album art ambient glow, and real-time synchronized lyrics sheet.

3. **⏱️ Timer & Clock**
   - Quick productivity countdown and Pomodoro focus timers.
   - Fluid circular time progress indicator, haptic notifications, and quick presets.

4. **✅ Reminders & Quick Tasks**
   - Instant single-click checklist with persistent task completion.
   - Add, check off, and delete quick tasks directly from the notch.

5. **📅 Calendar & Agenda**
   - Interactive monthly calendar with a fixed-height 42-cell grid and stable navigation.
   - Click any date to view and add date-specific focus events and milestones.
   - Real-time digital clock and day badge indicators.

6. **🔋 Connected Devices**
   - Live battery levels for connected Bluetooth accessories (AirPods, Magic Mouse, Magic Keyboard, Apple Watch, iPhone).

7. **📦 Shelf & Clipboard**
   - Drag-and-drop staging bucket for files and images with animated trash bin lid.
   - Recent clipboard history manager for quick pasting and clearing.

8. **🐾 Living Mascot**
   - Optional expressive virtual notch companion with smooth eye tracking, natural blink cycles, interactive reactions, and sleep states.

9. **⚙️ Dedicated Settings & Modules Window**
   - Modern inset sidebar interface to customize active island modules, appearance, spring physics duration, and system integration.

---

## 🔔 Native Notification HUDs

Replaces intrusive system HUDs with elegant floating island pills:
- **Audio Volume HUD** with smooth slider level feedback
- **MagSafe & Battery HUD** with power connection indicators
- **Wi-Fi & Bluetooth Status Alerts**
- **Caps Lock Indicator**
- **Incoming Calls & AirDrop Transfers**

---

## ⌨️ Shortcuts & Gestures

| Trigger | Action |
| :--- | :--- |
| **`Option + Space`** | Global shortcut to Expand / Collapse notch |
| **`Click Notch`** | Expand / Collapse notch directly |
| **`2-Finger Swipe`** | Fluid swipe left/right between island tabs |
| **`Page Dots`** | Click bottom indicator dots for instant tab switching |
| **`Click Outside`** | Automatically collapse back into the bezel |
| **`Menu Bar (🏝️)`** | Status bar menu with quick toggles, test alerts, and preferences |

---

## 🚀 Getting Started

### Requirements
- macOS 12.0 (Monterey) or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

### Build from Source
Requires Apple Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/FerrelHD/Dynamic-Chemicvl.git
cd Dynamic-Chemicvl

# Compile and launch immediately
./build.sh run

# Build standalone Universal .app bundle
./build.sh app

# Generate DMG release installer
./build.sh dmg
```

---

## 📄 License
Crafted with ❤️ by [FerrelHD](https://github.com/FerrelHD) using Native Swift, AppKit & SwiftUI.
