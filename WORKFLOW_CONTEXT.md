# 🏝️ NotchFlow - Master Workflow & Development Context Rules

> **Catatan Penggunaan:** Copy-paste isi dokumen ini ke prompt awal saat membuka sesi/akun baru agar AI asisten langsung memahami seluruh konteks, arsitektur, aturan kerja, dan histori pengerjaan project **NotchFlow**.

---

## 🎯 1. Filosofi & Aturan Utama (Ponytail Lazy Senior Dev Mode)

1. **Pahami Root Cause, Bukan Symptom:**
   * Jangan hanya menambal gejala di permukaan. Telusuri alur kerja end-to-end sampai ke akar masalahnya (seperti memperbaiki shared service sekali daripada menambal setiap caller).
2. **Zero Third-Party Dependencies:**
   * Dilarang menambahkan library/pod/package luar jika bawaan Apple sudah memadai.
   * Gunakan 100% native Apple stack: **Swift, AppKit, SwiftUI, SQLite3, MediaRemote, IOKit, CoreGraphics**.
3. **Deletion Over Addition & Boring Over Clever:**
   * Kode terbaik adalah kode yang tidak perlu ditulis. Hindari abstraksi spekulatif atau boilerplate yang tidak diminta.
   * Diff terpendek dan paling stabil yang menang.
4. **Verifikasi Nyata (Wajib Compile & Test):**
   * Setiap perubahan non-trivial wajib di-compile dan diverifikasi menggunakan `./build.sh app` atau `./build.sh dmg`.
   * Pastikan tidak ada compiler warning/error dan cek proses daemon aktif.
5. **Standar Komunikasi & Git:**
   * Bahasa komunikasi dengan user: **Bahasa Indonesia** yang jelas, to-the-point, dan santai/profesional.
   * Commit message: **Strict Conventional Commits** (e.g. `feat(island): ...`, `fix(music): ...`).

---

## 🏛️ 2. Informasi Project & Repository

* **Nama Project:** **NotchFlow** (Native macOS Dynamic Island & Living Notch).
* **OS Target:** macOS 12 Monterey atau lebih baru (Intel `x86_64` & Apple Silicon `arm64` - Universal Binary).
* **Direktori Lokal:** `/Users/Ferrel/Finesser/Career/DynamicIslandMac`
* **Remote Git:** `https://github.com/FerrelHD/Dynamic-Chemicvl.git` (Branch: `main`).
* **Toolchain:** Apple Command Line Tools (`swiftc`, `lipo`, `hdiutil`).
* **Perintah Build:**
  * `./build.sh app` $\rightarrow$ Compile Universal Binary & generate `NotchFlow.app`.
  * `./build.sh run` $\rightarrow$ Compile dan langsung jalankan aplikasi.
  * `./build.sh dmg` $\rightarrow$ Generate file installer DMG universal (`NotchFlow-1.0.0.dmg`).

---

## 🧩 3. Peta Arsitektur Kode Sumber (`Sources/DynamicIslandMac/`)

| File | Peran & Mekanisme Kunci |
| :--- | :--- |
| **`DynamicIslandPanel.swift`** | Subclass `NSPanel` (`.nonactivatingPanel`). Level di atas menu bar. Mengatur window frame adaptif, deteksi otomatis fullscreen (`CGWindowListCopyWindowInfo`) untuk auto-hide di fullscreen, dan fitur hover peek 14pt di bezel atas. |
| **`DynamicIslandView.swift`** | Tampilan utama SwiftUI. `NotchShape` dengan concave outward ears (G2 curvature). Menangani mode compact, expanded, dan HUD. Berisi tab: **Control, Music, Timer (Ruler Dial), Notes, Devices, Shelf/Clipboard (dengan 2-piece animated trash can)**. Dilengkapi animasi lirik Apple Music (skala 1.04x & defocus blur) dan sinkronisasi ambient light geometry. |
| **`IslandState.swift`** | Single Source of Truth (`ObservableObject`). Menyimpan state tab aktif, timer runner, media playback, hardware HUD (Volume, Battery/MagSafe, Wi-Fi, Bluetooth, Caps Lock), AirDrop HUD, Call HUD, dan Chat Notifications. Memiliki zero-leak token guard untuk artwork cover. |
| **`NotificationListenerService.swift`** | Service background yang membaca database internal Notification Center macOS (`/var/folders/.../com.apple.notificationcenter/db2/db`) via SQLite3 (`import SQLite3` + `PropertyListSerialization`). Menangkap chat asli dari **WhatsApp, Telegram, iMessage, Discord, Slack, Mail, dan semua aplikasi macOS** secara realtime (<0.5s) dengan nama pengirim & isi pesan asli. |
| **`MediaService.swift`** | Integrasi private framework macOS `MediaRemote.framework`. Ditambah parser otomatis URL tab aktif di Chrome/Safari untuk mengambil thumbnail HD resmi YouTube / YouTube Music via Google CDN (`img.youtube.com/vi/{videoId}/hqdefault.jpg`), plus strict fuzzy verification pada fallback pencarian iTunes Store. |
| **`HotKeyService.swift`** | Global keyboard shortcut handler (`Option + Space`) via Carbon Events API. |
| **`ClipboardService.swift`** | Polling ringan `NSPasteboard` untuk menangkap history copy teks terbaru. |
| **`LyricsService.swift`** | Fetcher lirik tersinkronisasi via LRCLIB API dengan time-tag interpolation. |

---

## 🚀 4. Riwayat Fitur & Bug Terakhir yang Sudah Diperbaiki

1. **Real Notification Center Monitor:**
   * Berhasil menggantikan mekanisme Dock badge lama menjadi native SQLite database monitor di `db2/db`.
   * Berhasil diuji langsung pada pesan WhatsApp asli (WhatsApp, Telegram, Messages, Discord, Slack, dsb.) dengan Nama Pengirim dan Isi Chat Asli.
2. **Ambient Light Gap Hitam:**
   * Diperbaiki dengan *synchronous geometry binding* pada `DynamicIslandView.swift`. Saat Notch dibuka dari compact ke expanded, pendaran warna cover art langsung meregang bersama dasar Notch tanpa jeda/gap hitam.
3. **YouTube Music Direct Cover Art:**
   * Ditambahkan deteksi tab Chrome YouTube/YouTube Music untuk langsung mengambil thumbnail HD resmi via Video ID, dilengkapi *anti-stale image leak* (cover lama langsung di-reset seketika lagu berganti).
4. **Animated Trash Can (Shelf & Clipboard):**
   * Icon tempat sampah 2 bagian (body + tutup terpisah) dengan animasi tutup terangkat dan file tersedot masuk saat ditekan.
5. **Horizontal Ruler Dial Timer:**
   * Tab timer dedicated dengan dial horizontal 16pt spacing, label menit terpusat, dan drag bebas loncat.

---

## 💡 5. Cara Melanjutkan di Sesi Baru

Jika kamu melanjutkan di sesi atau akun baru, cukup ketik:
> *"Saya melanjutkan pengerjaan project NotchFlow. Baca aturan kerja dan arsitektur di `WORKFLOW_CONTEXT.md`. Sekarang saya ingin [sebutkan fitur/task yang ingin dikerjakan]."*
