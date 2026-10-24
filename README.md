# 🏝️ Dynamic Island Native macOS (Monterey 12+)

Aplikasi Dynamic Island / living notch native untuk macOS yang ringan, hemat baterai (CPU idle ~0.0%), dan dibangun murni dengan Swift, AppKit, dan SwiftUI tanpa memerlukan instalasi Xcode penuh (~15 GB).

---

## ✨ Fitur Utama

1. **Universal Now Playing & Media Controller:**
   - Terhubung langsung dengan `MediaRemote.framework` macOS.
   - Otomatis mendeteksi pemutaran dari **Spotify, Apple Music, YouTube (Chrome, Safari, Arc, Brave, Edge), Netflix, VLC, Podcasts**, dll.
   - Menampilkan thumbnail/cover art asli, status playback, seek bar, dan animasi gelombang suara reaktif.
   - Tombol Play/Pause, Next, dan Previous yang mengontrol media sistem secara global.

2. **Pengganti System HUD (Volume Bar):**
   - Menggantikan kotak volume default macOS dengan animasi kapsul halus persis iOS saat menekan tombol volume keyboard (F11/F12).

3. **🎛️ Control Center:**
   - Akses cepat untuk status & toggle Wi-Fi (menampilkan nama SSID aktif).
   - Akses cepat status & toggle Bluetooth.
   - Heningkan notifikasi (Do Not Disturb / Focus).
   - Slider volume suara interaktif.

4. **📝 Quick Notes & To-Do List:**
   - Input catatan dan to-do instan (cukup ketik dan tekan Enter).
   - Checklist interaktif dengan pencoretan tugas selesai.
   - Penyimpanan otomatis dan permanen via `UserDefaults`.

5. **⏱️ Focus / Pomodoro Timer:**
   - Hitung mundur digital dengan tipografi **SF Pro Rounded**.
   - Preset instan: 25 menit (Pomodoro), 5 menit (Break), 15 menit (Long Break).

6. **📁 File Shelf (Drag & Drop):**
   - Drop zone sementara untuk menampung file dari Desktop/Finder.
   - Menampilkan ikon asli macOS dan mendukung drag-out ke aplikasi lain.

7. **⚡ Smart Velocity Dodge (Solusi 1):**
   - Kapsul melayang empuk (*floating pill*) berwarna *Solid Jet-Black* dengan jam digital di tengah.
   - Saat kursor digerakkan cepat ke atas (kecepatan tinggi), kapsul otomatis **menghindar / menyusut ke atas** dan mengaktifkan mode *click-through*, sehingga tab browser di belakangnya 100% bisa diklik bebas tanpa terhalang.
   - Saat kursor digerakkan santai di atas kapsul (>150ms dwell), kapsul membuka menu penuh.
   - Klik di mana saja di luar pulau untuk menutup kembali.

---

## 🛠️ Persyaratan Sistem & Instalasi

* **Sistem Operasi**: macOS 12 Monterey atau lebih baru.
* **Arsitektur**: Intel (x86_64) & Apple Silicon (ARM64).
* **Ukuran Binary**: Hanya **~1.1 MB** (tanpa dependensi luar / no Electron).
* **Alat Pengembang**: Hanya butuh **Apple Command Line Tools** (~700 MB via Terminal `xcode-select --install`).

---

## 🚀 Cara Menjalankan

1. Clone repositori:
   ```bash
   git clone https://github.com/FerrelHD/Dynamic-Chemicvl.git
   cd Dynamic-Chemicvl
   ```

2. Jalankan skrip build & run:
   ```bash
   chmod +x build.sh
   ./build.sh run
   ```

Atau buka folder ini di **VS Code**, lalu tekan shortcut **`Cmd + Shift + B`** dan pilih **Build & Run Dynamic Island**.

---

## 📄 Lisensi
Dibuat oleh [FerrelHD](https://github.com/FerrelHD) dengan Swift & AppKit/SwiftUI Native.
