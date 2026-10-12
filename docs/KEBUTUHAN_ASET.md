# Kebutuhan Aset Cuan Quest

Dokumen ini berisi daftar aset yang dibutuhkan agar game terasa lebih hidup, beserta **format, ukuran, dan nama file** yang langsung cocok dengan kode. Nama file sengaja disamakan dengan `id` di folder `data/`, sehingga nanti aset bisa dimuat otomatis tanpa daftar manual.

> **Status:** game masih memakai tampilan sekarang. Pada milestone redesain UI, saya akan membuat pemuat aset (`GameAssets`) dengan *fallback*: jika file belum ada, tampilan lama tetap dipakai. Jadi aset bisa Anda tambahkan **sedikit demi sedikit**, tidak harus lengkap sekaligus.

---

## 1. Aturan Umum

### Format

| Jenis | Format | Alasan |
|---|---|---|
| Ikon (UI, kelas aset, kategori) | **SVG** (utama) atau PNG | Godot 4 mengimpor SVG menjadi gambar tajam di ukuran berapa pun. Hindari filter/blur, efek bayangan SVG, dan teks di dalam SVG (ubah teks jadi *outline/path*). |
| Ilustrasi (karakter, ruangan, latar) | **PNG 32-bit** (dengan transparansi) | Detail ilustrasi lebih aman di PNG. |
| Panel, kartu, tombol | **PNG 9-slice** | Bisa diregangkan tanpa sudut gepeng. Cantumkan ukuran margin sudut (mis. 24 px) di nama file atau catatan. |
| Animasi pendek (koin, kilau) | **PNG sprite sheet** (frame berjajar dalam grid) | Godot belum mendukung Lottie/GIF secara bawaan. |
| Font | **TTF/OTF**, lisensi **OFL** (Google Fonts) | Wajib mendukung huruf Latin, angka, dan simbol `Rp % + - , . / ( )`. |
| Efek suara | **WAV** 16-bit 44,1 kHz (atau OGG) | Pendek, langsung bunyi. |
| Musik | **OGG Vorbis**, bisa di-*loop* | Ukuran file kecil. Atur loop di Import dock Godot. |

### Ukuran

- Layar dasar game **720 x 1280** (portrait). Di HP, layar ini diperbesar sekitar 1,5x sampai 2x.
- **Buat semua gambar raster (PNG) 2x ukuran tampil.** Contoh: avatar tampil 110 px, jadi buat **220 x 220** (dibulatkan menjadi 256 x 256 juga boleh).
- SVG cukup dibuat di ukuran tampil; ketajamannya diatur saat impor.

### Penamaan & Folder

- Huruf kecil, kata dipisah garis bawah (`snake_case`), tanpa spasi.
- Taruh di folder `assets/` dalam project:

```
assets/
  fonts/          heading.ttf, body.ttf, body_bold.ttf
  ui/             tombol, panel, popup, progress bar (9-slice)
  icons/          ikon UI & tab
  icons/assets/   logo tiap instrumen
  icons/classes/  ikon kelas aset
  illustrations/  avatar, ruangan, tutorial, layar akhir, event
  effects/        koin, kilau, konfeti
  audio/sfx/      efek suara
  audio/music/    musik
  branding/       logo, ikon aplikasi, aset Play Store
```

- **Lisensi:** jika memakai aset CC0 atau font OFL, catat sumbernya di `assets/LICENSES.md`.

### Palet Warna

Sebelum membuat aset, tetapkan dulu palet tema baru (misalnya 6-8 warna dalam kode hex): latar, kartu, teks utama, teks redup, aksen utama, hijau (untung), merah (rugi), dan kuning (peringatan). Kirim paletnya ke saya; semua warna di kode akan saya pindahkan ke satu file Theme agar mengikuti palet Anda.

---

## 2. Prioritas

- **P1 (paling berdampak):** dibutuhkan untuk milestone redesain UI.
- **P2:** memperkaya tampilan; sebagian wajib untuk rilis (aset Play Store).
- **P3:** bonus, bisa menyusul lewat update.

---

## 3. Daftar Aset

### 3.1 Font (P1)

| File | Kegunaan | Saran |
|---|---|---|
| `fonts/heading.ttf` | Judul, angka besar (harga, kas) | Font bulat & ramah, mis. Fredoka, Baloo 2, Nunito ExtraBold |
| `fonts/body.ttf` | Teks biasa | Mudah dibaca di layar kecil, mis. Nunito, Poppins |
| `fonts/body_bold.ttf` | Teks tebal | Versi bold dari font body |

### 3.2 UI Kit (P1)

| File | Ukuran (px, 2x) | Catatan |
|---|---|---|
| `ui/button_primary.png` | 192 x 96 | 9-slice. Tombol utama (Lanjut, Konfirmasi) |
| `ui/button_primary_pressed.png` | 192 x 96 | Saat ditekan |
| `ui/button_secondary.png` | 192 x 96 | Tombol biasa |
| `ui/button_secondary_pressed.png` | 192 x 96 | |
| `ui/button_disabled.png` | 192 x 96 | Tombol nonaktif |
| `ui/toggle_on.png`, `ui/toggle_off.png` | 120 x 64 | Saklar pengaturan |
| `ui/panel_card.png` | 96 x 96 | 9-slice. Kartu (kepemilikan, slot simpan, dll.) |
| `ui/popup_frame.png` | 128 x 128 | 9-slice. Bingkai popup |
| `ui/progress_bg.png`, `ui/progress_fill.png` | 64 x 32 | 9-slice. Bar kesehatan, kebahagiaan, XP |
| `ui/tab_bar_bg.png` | 1440 x 160 | Latar navigasi bawah |
| `ui/top_bar_bg.png` | 1440 x 220 | Latar bar atas (kas, kekayaan) |
| `ui/input_field.png` | 96 x 96 | 9-slice. Kolom isian nominal & nama |

### 3.3 Ikon UI (P1)

SVG, tampil sekitar 40-48 px.

| File | Kegunaan |
|---|---|
| `icons/tab_home.svg`, `tab_market.svg`, `tab_portfolio.svg`, `tab_activity.svg`, `tab_profile.svg` | Navigasi bawah (5 tab). Opsional versi aktif: `tab_home_active.svg`, dst. |
| `icons/cash.svg` | Kas (dompet/koin) |
| `icons/net_worth.svg` | Kekayaan bersih (peti harta/grafik) |
| `icons/calendar.svg` | Tanggal game |
| `icons/level.svg` | Level / XP (bintang) |
| `icons/energy.svg` | Energi (petir) |
| `icons/health.svg` | Kesehatan (hati) |
| `icons/happiness.svg` | Kebahagiaan (wajah senyum) |
| `icons/help.svg` | Tombol glosarium "?" |
| `icons/back.svg`, `icons/close.svg` | Kembali, tutup |
| `icons/lock.svg`, `icons/check.svg`, `icons/warning.svg` | Terkunci, terpenuhi, peringatan |
| `icons/trend_up.svg`, `icons/trend_down.svg` | Naik / turun |
| `icons/news.svg` | Berita pasar |
| `icons/skip.svg` | Lompat waktu (+6 Bln / +1 Thn) |
| `icons/settings.svg`, `sound_on.svg`, `sound_off.svg`, `vibration.svg`, `language.svg` | Pengaturan |
| `icons/save.svg`, `load.svg`, `reset.svg`, `book.svg`, `privacy.svg` | Simpan, muat, reset, glosarium/tutorial, kebijakan |

### 3.4 Ikon Kelas Aset & Logo Instrumen

| File | Prioritas | Kegunaan |
|---|---|---|
| `icons/classes/savings.svg` | P1 | Tabungan (celengan) |
| `icons/classes/deposit.svg` | P1 | Deposito (brankas) |
| `icons/classes/mutual_fund.svg` | P1 | Reksa dana (keranjang) |
| `icons/classes/stock.svg` | P1 | Saham (grafik candle) |
| `icons/classes/crypto.svg` | P1 | Kripto (koin digital) |
| `icons/assets/tab.svg` | P2 | Tabungan Bank Sentosa |
| `icons/assets/dep.svg` | P2 | Deposito 3 Bulan |
| `icons/assets/rdpu.svg` | P2 | RD Pasar Uang Amanah |
| `icons/assets/rds.svg` | P2 | RD Saham Nusantara |
| `icons/assets/bsnt.svg` | P2 | PT Bank Sentosa (bank) |
| `icons/assets/mpgn.svg` | P2 | PT Mitra Pangan (makanan/konsumer) |
| `icons/assets/nusa.svg` | P2 | PT Nusa Karya (konstruksi) |
| `icons/assets/bara.svg` | P2 | PT Bara Jaya (batu bara) |
| `icons/assets/grd.svg` | P2 | Garuda Coin |
| `icons/assets/mrp.svg` | P2 | Merapi Token |

> Semua perusahaan & koin **fiktif**. Jangan membuat logo yang mirip merek asli (aturan Google Play & hak merek).

### 3.5 Karakter (Avatar)

| File | Ukuran (2x) | Prioritas | Catatan |
|---|---|---|---|
| `illustrations/avatar_0.svg` ... `avatar_9.svg` | 256 x 256 | P1 | **Sudah ada** (gaya anime "Senja Cuan"): 0-4 pria, 5-9 wanita. Nama saran & deskripsi di `AvatarView.NAMES` dan kunci `AVATAR_DESC_<n>`. Versi PNG buatan sendiri boleh menggantikan, asal nama & urutannya sama |
| `illustrations/avatar_0_happy.png`, `_neutral`, `_sad` (per avatar) | 256 x 256 | P3 | Ekspresi mengikuti kebahagiaan (>=60 / 30-59 / <30): 30 gambar |
| `illustrations/background_student.png`, `background_employee.png`, `background_freelancer.png` | 480 x 480 | P2 | Ilustrasi pilihan latar belakang di layar Buat Karakter |

### 3.6 Ilustrasi Ruangan & Beranda

| File | Ukuran (2x) | Prioritas | Catatan |
|---|---|---|---|
| `illustrations/housing_family.png` | 1440 x 720 | P1 | Rumah orang tua (Menumpang). Tampil di atas Beranda, berganti sesuai pilihan |
| `illustrations/housing_kos.png` | 1440 x 720 | P1 | Kamar kos |
| `illustrations/housing_apartment.png` | 1440 x 720 | P1 | Apartemen |
| `icons/food_frugal.svg`, `food_standard.svg`, `food_luxury.svg` | 96 x 96 | P3 | Ikon pilihan makan |

> Ide cozy: buat 3 ruangan ini dengan **lapisan terpisah** (latar, perabot, karakter) agar nanti bisa ditambah detail sesuai kekayaan, mis. tanaman atau rak buku yang muncul saat level naik.

### 3.7 Aktivitas, Kuis, Event

| File | Ukuran | Prioritas | Kegunaan |
|---|---|---|---|
| `icons/activity_side_job.svg`, `activity_course.svg`, `activity_self_study.svg`, `activity_exercise.svg`, `activity_hangout.svg`, `activity_rest.svg` | 64 px | P2 | 6 aktivitas bulanan |
| `icons/topic_basics.svg`, `topic_risk.svg`, `topic_scam.svg`, `topic_instruments.svg` | 64 px | P2 | 4 topik kuis |
| `illustrations/event_finance.png`, `event_work.png`, `event_health.png`, `event_social.png`, `event_market.png`, `event_scam.png` | 1200 x 480 | P2 | Banner kartu event per kategori |
| `illustrations/event_<id>.png` (33 file, mis. `event_motor_broken.png`) | 1200 x 480 | P3 | Ilustrasi khusus per event; jika ada, menggantikan banner kategori. Daftar id ada di `data/events.json` |
| `illustrations/quiz_header.png` | 1200 x 320 | P3 | Hiasan atas popup kuis |

### 3.8 Popup Khusus, Tutorial, Layar Akhir

| File | Ukuran (2x) | Prioritas | Kegunaan |
|---|---|---|---|
| `illustrations/tutorial_1.png` ... `tutorial_5.png` | 1200 x 800 | P2 | Satu ilustrasi per halaman tutorial |
| `illustrations/unlock.png` | 480 x 480 | P2 | Popup "Instrumen Baru Terbuka" |
| `illustrations/goal_millionaire.png`, `goal_freedom.png` | 480 x 480 | P2 | Popup target tercapai |
| `illustrations/hint.png` | 240 x 240 | P3 | Popup petunjuk (bohlam) |
| `illustrations/end_win.png`, `end_lose.png`, `end_retired.png` | 1200 x 720 | P2 | Layar akhir |
| `illustrations/stage_1.png` ... `stage_4.png` | 480 x 320 | P3 | Kartu tahap unlock |
| `illustrations/risk_conservative.png`, `risk_moderate.png`, `risk_aggressive.png` | 240 x 240 | P3 | Hasil kuesioner profil risiko |
| `illustrations/empty_state.png` | 480 x 480 | P3 | Saat portofolio/riwayat masih kosong |

### 3.9 Layar Judul & Branding

| File | Ukuran | Prioritas | Catatan |
|---|---|---|---|
| `branding/logo.png` (atau `.svg`) | 1200 x 400 | P1 | Logo "Cuan Quest" di layar judul |
| `branding/title_background.png` | 1440 x 2560 | P2 | Latar layar judul |
| `branding/app_icon.png` | 1024 x 1024 | P1 | Ikon aplikasi (sumber untuk semua ukuran) |
| `branding/icon_foreground.png` | 432 x 432 | P2 (wajib rilis) | Adaptive icon Android (lapisan depan, objek di tengah ~66% area) |
| `branding/icon_background.png` | 432 x 432 | P2 (wajib rilis) | Adaptive icon Android (lapisan belakang, polos/pola) |
| `branding/icon_monochrome.png` | 432 x 432 | P3 | Ikon tema Android 13+ (satu warna) |
| `branding/boot_splash.png` | 1080 x 1920 | P2 | Layar saat game dibuka |
| `branding/play_icon_512.png` | 512 x 512 | P2 (wajib rilis) | Ikon Play Store |
| `branding/feature_graphic.png` | 1024 x 500 | P2 (wajib rilis) | Banner Play Store |

> Screenshot Play Store akan saya ambil dari game setelah redesain selesai.

### 3.10 Efek Visual (P2)

| File | Ukuran | Kegunaan |
|---|---|---|
| `effects/coin_sheet.png` | 8 frame x 128 px (1024 x 128) | Animasi koin berputar saat gaji masuk/untung |
| `effects/sparkle_sheet.png` | 6 frame x 128 px | Kilau saat unlock/level naik |
| `effects/confetti.png` | 64 x 64 (beberapa warna) | Partikel konfeti saat menang |

### 3.11 Audio

| File | Prioritas | Kegunaan |
|---|---|---|
| `audio/sfx/click.wav` | P2 | Semua tombol |
| `audio/sfx/coin.wav` | P2 | Lanjut bulan, uang masuk |
| `audio/sfx/success.wav` | P2 | Kuis benar, unlock, aktivitas |
| `audio/sfx/fail.wav` | P2 | Kuis salah, kalah |
| `audio/sfx/alert.wav` | P2 | Event muncul |
| `audio/sfx/buy.wav`, `audio/sfx/sell.wav` | P3 | Transaksi |
| `audio/sfx/level_up.wav`, `audio/sfx/page.wav` | P3 | Naik level, halaman tutorial |
| `audio/music/title.ogg` | P3 | Musik layar judul (loop) |
| `audio/music/gameplay.ogg` | P3 | Musik santai saat bermain (loop, tidak mengganggu) |
| `audio/music/end_win.ogg`, `audio/music/end_lose.ogg` | P3 | Potongan pendek layar akhir |

> Efek suara saat ini dibuat dengan kode (`scripts/autoload/sfx.gd`). Jika file WAV dengan nama di atas tersedia, nanti file itulah yang dipakai.

---

## 4. Ringkasan Jumlah

| Prioritas | Kira-kira jumlah file |
|---|---|
| P1 | ~45 (3 font, ~12 UI kit, ~30 ikon, 5 ikon kelas, 6 avatar, 3 ruangan, logo, ikon aplikasi) |
| P2 | ~60 |
| P3 | ~90 (sebagian besar ilustrasi per event & ekspresi avatar) |

**Saran urutan:** palet warna → font → UI kit → ikon tab & bar atas → avatar → 3 ruangan → logo & ikon aplikasi. Setelah P1 ada, kirim ke saya untuk dipasang di milestone redesain UI, sambil Anda melanjutkan P2.
