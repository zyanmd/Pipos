# AnimeVerse — Flutter Anime & Comic App

A modern, iOS-styled Flutter app for streaming anime and reading comics. Built on top of your Flask backend at **api.pipinipon.site** with full light/dark theme support.

![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-2D2D2D)

---

## ✨ Fitur Utama

### 🎬 Anime
- Beranda dengan hero carousel (anime ongoing) + section scrolling
- Pencarian anime dengan genre populer chips
- Detail anime: cover, synopsis, genres, metadata, daftar episode
- Pemutar episode (Chewie / WebView fallback untuk mirror streaming)
- Jadwal rilis harian (Senin–Minggu) dengan tab harian
- Bookmark anime & riwayat tonton

### 📖 Komik
- Beranda dengan komik populer & rilisan terbaru
- Pencarian komik dengan genre chips
- Detail komik: cover, synopsis, chapters list (urutkan baru/lama)
- Pembaca komik dengan PhotoView (pinch zoom, swipe)
- Bookmark komik & riwayat baca

### 👤 Profil & Akun
- Login / Register / Lupa password (OTP flow 3 langkah)
- Profil dengan avatar + cover photo
- Edit profil (upload avatar/cover, ubah bio/email)
- Statistik pengguna (anime ditonton, komik dibaca, total bookmark)
- Riwayat tonton & baca dalam satu layar

### 🎨 Tema & UI
- **Sakura Pink** palette (#FF4D6D → #C9184A)
- **Tema terang & gelap** — toggle di profil atau settings
- Floating iOS-style bottom navigation dengan blur
- Large title app bars (Apple-like shrink-on-scroll)
- Glass cards, gradient buttons, shimmer skeletons
- Hero transitions, smooth animations

---

## 📂 Struktur Proyek

```
lib/
├── main.dart                    # Entry point + theme/auth providers
├── core/
│   ├── config/
│   │   └── api_config.dart      # baseUrl: api.pipinipon.site + endpoints
│   ├── constants/
│   │   ├── app_colors.dart      # Sakura Pink palette
│   │   └── app_text_styles.dart # iOS typography
│   ├── theme/
│   │   └── app_theme.dart       # Light & dark ThemeData
│   └── network/
│       └── api_client.dart       # Dio + JWT interceptor + token store
├── features/
│   ├── auth/                    # Login, Register, Forgot Password
│   ├── anime/                   # Home, Search, Detail, Player, Schedule
│   ├── comic/                   # Home, Search, Detail, Reader
│   ├── profile/                 # Profile, Edit, Settings, History
│   ├── bookmarks/               # Unified bookmark library
│   └── main/
│       └── presentation/
│           └── root_shell.dart  # Bottom nav + tab navigator
└── shared/
    ├── providers/                # ThemeProvider, AuthProvider
    └── widgets/                  # GlassCard, PosterCard, IOSBottomNavBar, ...
```

---

## 🚀 Cara Menjalankan

### 1. Prasyarat
- Flutter SDK 3.13+ (`flutter --version`)
- Dart SDK 3.0+
- Backend API: `https://api.pipinipon.site` (sudah aktif)

### 2. Install dependencies
```bash
cd animeverse
flutter pub get
```

### 3. Jalankan aplikasi

#### Android Emulator
```bash
flutter run
```

#### iOS Simulator
```bash
flutter run -d ios
```

#### Web (untuk testing cepat)
```bash
flutter run -d chrome
```

#### Device fisik
```bash
# Android (aktifkan USB debugging di HP)
flutter run -d <device-id>

# iOS (butuh Xcode + signing)
flutter run -d <ios-device-id>
```

---

## ⚙️ Konfigurasi API

Base URL ada di `lib/core/config/api_config.dart`:

```dart
static const String baseUrl = 'https://api.pipinipon.site';
```

Untuk mengganti ke backend lokal:
```dart
// Android emulator
static const String baseUrl = 'http://10.0.2.2:5000';

// iOS simulator
static const String baseUrl = 'http://127.0.0.1:5000';

// Device fisik (ganti IP)
static const String baseUrl = 'http://192.168.1.100:5000';
```

Pastikan backend mengizinkan CORS (Allow-Origin `*`) kalau jalan di Web.

---

## 🔌 Endpoint yang Digunakan

### Auth (`/api/auth`)
- `POST /register` — daftar akun baru
- `POST /login` — login (email atau username)
- `GET /me` — ambil data user dari JWT
- `POST /logout` — logout (invalidate token)
- `POST /forgot-password` — kirim OTP reset
- `POST /verify-otp` — verifikasi OTP
- `POST /reset-password` — set password baru
- `POST /refresh` — refresh access token (otomatis di interceptor)

### User/Profile (`/api/users`)
- `GET /profile/me` — profil sendiri
- `PUT /profile/me` — update profil (display_name, bio, email)
- `POST /<username>/avatar` — upload avatar (multipart)
- `POST /<username>/cover` — upload cover (multipart)
- `DELETE /<username>/avatar` — hapus avatar
- `GET /<username>/stats` — statistik pengguna

### Anime (`/api/anime`)
- `GET /home` — beranda (ongoing + completed)
- `GET /ongoing` — anime ongoing
- `GET /completed` — anime tamat
- `GET /schedule` — jadwal rilis harian
- `GET /detail/<anime_id>` — detail + daftar episode
- `GET /episode/<episode_id>` — stream sources & mirror links
- `GET /search?q=...` — pencarian
- `GET /genres` — daftar genre
- `GET /genre/<slug>` — anime per genre
- `GET/POST/DELETE /bookmarks` — bookmark CRUD
- `GET/POST/DELETE /watch-history` — riwayat tonton

### Comic (`/api/comic`)
- `GET /populer` — komik populer
- `GET /terbaru` — rilisan terbaru
- `GET /pustaka` — perpustakaan
- `GET /ranking/<period>` — ranking
- `GET /detail/<slug>` — detail + daftar chapter
- `GET /chapter?id=...` — gambar chapter
- `GET /search?q=...` — pencarian
- `GET/POST/DELETE /bookmarks` — bookmark CRUD
- `GET/POST/DELETE /read-history` — riwayat baca

---

## 🎨 Sistem Tema

### Palet warna
| Token | Light | Dark |
|---|---|---|
| Background | `#F9F5F7` | `#0A0610` |
| Surface | `#FFFFFF` | `#140A1A` |
| Card | `#FFFFFF` | `#1A0E22` |
| Text Primary | `#1A0B14` | `#F7EFF3` |
| Accent (Sakura) | `#FF4D6D` | `#FF4D6D` |
| Accent Dark | `#C9184A` | `#C9184A` |

### Mengubah tema
1. Buka tab **Profil**
2. Ketuk **Tema** (atau ikon settings di kanan atas)
3. Pilih: **Terang** / **Gelap** / **Sistem**

Tema tersimpan di `SharedPreferences` dan langsung diterapkan.

---

## 🧱 State Management

Menggunakan **Provider** (sederhana, cukup untuk kebutuhan ini):
- `ThemeProvider` — mode tema (light/dark/system)
- `AuthProvider` — user aktif + state loading/error

Setiap screen menggunakan `FutureBuilder` + repository langsung untuk fetch data.

---

## 📦 Dependencies Utama

| Package | Penggunaan |
|---|---|
| `dio` | HTTP client + interceptors |
| `provider` | State management |
| `cached_network_image` | Image caching |
| `shimmer` | Loading skeleton |
| `photo_view` | Comic reader (pinch zoom) |
| `chewie` + `video_player` | Anime player |
| `webview_flutter` | Mirror stream fallback |
| `google_fonts` | Poppins + Inter fonts |
| `flutter_staggered_grid_view` | Masonry grid |
| `image_picker` | Upload avatar/cover |
| `shared_preferences` | Persist theme mode |

---

## 🛠️ Troubleshooting

### Error: `SocketException` / connection refused
- Pastikan backend `api.pipinipon.site` aktif
- Coba `curl https://api.pipinipon.site/api/anime/health`
- Kalau jalan di emulator Android untuk local backend, gunakan `http://10.0.2.2:5000`

### Video player tidak muncul
- Beberapa mirror streaming butuh WebView (bukan native player)
- Otomatis fallback ke WebView kalau URL bukan .mp4/.m3u8

### Login gagal: "Network error"
- Cek koneksi internet
- Cek apakah email/username sudah benar
- Pastikan backend mengizinkan field `email` menerima username (cek auth_routes.py)

### Gambar tidak muncul
- Gambar anime dari otakudesu.blog, komik dari img.komiku.org
- Kadang butuh User-Agent khusus — sudah dihandle di backend

---

## 📝 Catatan Pengembangan

- Animasi mengikuti panduan iOS Human Interface: large title, blur, smooth transitions
- Bottom nav bar menggunakan `BackdropFilter` untuk efek frosted glass
- Skeleton loading pakai `Shimmer` untuk pengalaman lebih premium
- Semua layar support pull-to-refresh

---

## 📄 Lisensi

Aplikasi ini hanya untuk tujuan edukasi. Hak cipta konten anime/komik tetap milik pemiliknya masing-masing. Backend yang dipakai adalah milik pengguna (`api.pipinipon.site`).
