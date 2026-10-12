# Panduan Belajar Cuan Quest (Godot 4.7)

## Kamus Godot untuk Fullstack Developer

| Godot | Padanan di web | Keterangan |
|---|---|---|
| **Node** | Elemen DOM | Unit terkecil: `Label`, `Button`, `VBoxContainer`, dll. |
| **Scene** (`.tscn`) | Komponen (React/Vue) | Pohon node yang bisa dipakai ulang dan di-instance |
| **Script** (`.gd`) | Logic komponen | Ditempel ke satu node; `extends Control` = tipe node-nya |
| **Signal** | Event / EventEmitter | `button.pressed.connect(fn)` ≈ `addEventListener("click", fn)` |
| **Autoload** | Global store / singleton | `GameState` bisa diakses dari mana saja |
| `_ready()` | `onMounted` / `useEffect(..., [])` | Dipanggil sekali saat node masuk ke scene tree |
| `_process(delta)` | `requestAnimationFrame` | Dipanggil tiap frame (belum dipakai) |
| `%NamaNode` | `getElementById` | Hanya untuk node yang diberi *Access as Unique Name* |
| **Container** (VBox/HBox/Margin) | Flexbox | `size_flags_horizontal = 3` ≈ `flex: 1` |
| `res://` | Folder source project | Read-only setelah di-export ke Android |
| `user://` | localStorage | Tempat save game (dipakai di Milestone 5) |
| `tr("KEY")` | i18n `t("KEY")` | Teks diambil dari `localization/strings.csv` |
| **Instance scene** | `<MyComponent />` | Di `main.tscn`, setiap tab adalah instance dari scene lain |
| `@export var` | Props | Bisa diisi per-instance dari Inspector (contoh: `message_key` di placeholder) |
| `ScrollContainer` | `overflow-y: auto` | Setiap tab bisa di-scroll jika kontennya panjang |

## Struktur Project

```
data/
  assets.json                 Parameter aset (drift, volatilitas, fee)
  economy.json                Gaji, modal awal, pilihan makan & tempat tinggal (untuk balancing)
  market.json                 Siklus pasar, suku bunga acuan, peluang berita
  news.json                   Template berita pasar & dampaknya ke harga
  events.json                 33 event hidup: syarat muncul, pilihan, efek
  quiz.json                   39 soal kuis (4 topik)
  glossary.json               31 istilah glosarium
  unlocks.json                Syarat membuka tiap tahap instrumen
localization/strings.csv      Semua teks UI (kolom id & en)
theme/main_theme.tres         Font global, warna tombol aktif, panel, progress bar
scripts/
  autoload/game_state.gd      STATE GLOBAL: kas, bulan, kondisi, portofolio, loop bulanan, XP, unlock, event
  autoload/ad_service.gd      Iklan rewarded (STUB, nanti diganti AdMob dengan interface sama)
  autoload/save_manager.gd    Simpan/muat file JSON di user:// + simpan otomatis
  core/                       Logika murni tanpa UI (mudah dites)
    market.gd, market_asset.gd   Simulasi pasar (GBM, RNG ber-seed)
    fmt.gd                    Format Rp1.234.567, +2,35%, tanggal game
    data_loader.gd            Baca JSON
    quiz_manager.gd           Bank soal + jatah mingguan (waktu nyata) + kredit iklan
    event_manager.gd          Pemilihan event berdasarkan syarat & bobot
  ui/
    main.gd                   Shell: top bar, router tab, tombol Lanjut, popup
    price_chart.gd            Grafik garis (dipakai di Pasar & Portofolio)
    month_report.gd           Pembuat baris laporan (dipakai di popup & Portofolio)
    modal_popup.gd            Base class popup (signal closed)
    month_summary_popup.gd    Modal laporan bulanan
    event_popup.gd, quiz_popup.gd, info_popup.gd
    ui_text.gd                Helper teks: perubahan efek, syarat unlock
    screens/                  Satu script per tab
scenes/
  title.tscn                  Layar judul (main scene saat game dibuka)
  new_game.tscn               Buat karakter
  tutorial.tscn               Tutorial 5 layar
  main.tscn                   Shell aplikasi
  screens/                    home, market, portfolio, placeholder
  ui/month_summary_popup.tscn
```

**Alur data (satu arah, seperti Redux):**
`Tombol ditekan → screen memanggil GameState.xxx() → GameState mengubah data → signal "changed" → semua screen menjalankan _refresh()`

**Loop bulanan** (`GameState.advance_month()`):
1. Pasar bergerak (akhir bulan berjalan), lalu perubahan nilai investasi dicatat
2. Bulan bertambah, lalu `_start_month()` dijalankan: gaji masuk, biaya makan & tempat tinggal terpotong, kesehatan & kebahagiaan berubah
3. Net worth dicatat ke riwayat, lalu signal `month_advanced(report)` memunculkan popup laporan

## Cara Menjalankan

1. Buka Godot, lalu pilih project `cuan-quest`.
2. Tekan **F5** (Run Project). Jendela akan tampil berukuran 405×720 (simulasi HP portrait).
3. Untuk melihat struktur layar, buka `scenes/main.tscn` dan lihat panel **Scene** di kiri atas.

## Daftar Periksa MVP (GDD bagian 11)

| # | Item | Milestone | Status |
|---|---|---|---|
| 1 | Profil karakter dan pilihan kesulitan | M5 | ✅ |
| 2 | Tutorial singkat dan glosarium | M5 | ✅ 5 layar tutorial, 31 istilah, petunjuk per tab |
| 3 | Loop bulanan dengan tombol Lanjut | M2 | ✅ |
| 4 | Gaji dan biaya hidup (makan, sewa) | M2 | ✅ |
| 5 | Tabungan, deposito, reksa dana, saham, kripto | M3 | ✅ |
| 6 | Dashboard dengan grafik harga dan tombol beli/jual | M1 + M3 | ✅ |
| 7 | Portofolio dasar dan ringkasan bulanan | M2 | ✅ |
| 8 | Simulasi harga dengan siklus pasar sederhana | M3 | ✅ |
| 9 | Event hidup (minimal 30 event) | M4 | ✅ 33 event |
| 10 | Kuis 3 per minggu + iklan rewarded (minimal 30 soal) | M4 | ✅ 39 soal; iklan masih stub (AdMob di M7) |
| 11 | Sistem unlock instrumen | M4 | ✅ |
| 12 | Kondisi menang dan kalah serta layar akhir | M6 | ⬜ |
| 13 | Save/load otomatis dan manual | M5 | ✅ |
| 14 | Pengaturan dan halaman profil | M5 + M6 | 🟨 halaman profil ada; pengaturan di M6 |
| 15 | Disclaimer simulasi dan kebijakan privasi | M6 | 🟨 disclaimer ada; kebijakan privasi di M6 |

## Milestone

- [x] **M1: Prototipe.** 1 aset, grafik, beli/jual + fee, saldo, tombol Lanjut
- [x] **M2: Loop bulanan.** Gaji, biaya hidup, kesehatan/kebahagiaan, laporan bulanan, tab Portofolio, navigasi bawah
- [x] **M3: Pasar lengkap.** 10 aset di 5 kelas, siklus bull/sideways/bear, korelasi, suku bunga acuan, 16 berita pasar, bunga & penalti deposito
- [x] **M4: Event hidup, kuis, unlock.** 33 event (termasuk efek tertunda & PHK), 39 soal kuis (3/minggu nyata + iklan stub), XP & level, 4 tahap unlock, antrean popup
- [x] **M5: Save/load, layar judul, buat karakter, tutorial & glosarium.** 3 latar belakang, 3 tingkat kesulitan, simpan otomatis + 3 slot manual, petunjuk saat tab pertama dibuka, tab Profil
- [ ] **M6: Menang/kalah + layar akhir, profil & pengaturan, kebijakan privasi**
- [ ] **M7: Export Android, playtest, balancing**

## Cara Kerja Simulasi Pasar (M3)

Setiap bulan `Market.step()` menjalankan:
1. **Siklus pasar.** Saham dan kripto masing-masing berada di fase *bull*, *sideways*, atau *bear* selama beberapa bulan acak. Saat fase berganti, muncul berita "Analis: ...".
2. **Berita** (peluang 50%). Satu template dipilih dari `news.json` berdasarkan bobot, lalu memberi guncangan harga ke satu aset, satu kelas aset, atau suku bunga.
3. **Harga baru:** `harga × exp(drift_bulanan − ½σ² + σ·z) × (1 + guncangan)`, dengan `z = rho·z_pasar + √(1−rho²)·z_acak`. Bagian `z_pasar` yang sama untuk semua aset membuat saham cenderung naik-turun bersamaan (korelasi).
4. **Tabungan & deposito** tidak bergerak harganya. Bunganya (`suku bunga acuan + spread`, dipotong pajak) dibayar di `GameState._pay_interest()`.

**Hasil kalibrasi** (300 simulasi × 10 tahun, median imbal hasil per tahun): RD Pasar Uang +4,6% · RD Saham +8,7% · Saham +4,5% s.d. +8,6% · Kripto +7,5% s.d. +12% (peluang rugi kripto sekitar 38%).

## Event, Kuis & Unlock (M4)

- **Antrean popup** (`main.gd`): setelah Lanjut bisa muncul beberapa popup berurutan, yaitu laporan, lalu instrumen baru, lalu event. Popup berikutnya tampil setelah yang sebelumnya ditutup. Tombol Lanjut nonaktif selama ada event yang belum diputuskan.
- **Teks event & kuis** ditulis langsung dalam bahasa Indonesia di JSON dan ditampilkan lewat `tr(teks)`. Untuk bahasa Inggris nanti, tambahkan file terjemahan dengan teks Indonesia sebagai key, tanpa perlu mengubah JSON atau kode.
- **Jatah kuis memakai jam perangkat** (`QuizManager.current_week_id()`), sehingga menekan Lanjut tidak menambah jatah. Catatan: jatah ini akan hilang saat game ditutup, sampai fitur save/load selesai di M5.
- **Tips testing unlock:** turunkan angka `min` di `data/unlocks.json` (misalnya `50000000` menjadi `5000000`) agar tahap saham dan kripto cepat terbuka. Jangan lupa kembalikan angkanya.

## Simpan & Muat (M5)

- **Alur layar:** `title.tscn` -> `new_game.tscn` -> `tutorial.tscn` (hanya jika belum pernah) -> `main.tscn`. Perpindahan memakai `get_tree().change_scene_to_file()`, sedangkan autoload (`GameState` dkk.) tetap hidup.
- **Dua jenis data:**
  - *Slot save* (`user://saves/auto.json`, `slot_1..3.json`): state satu permainan, hasil `GameState.to_dict()`.
  - *Data pemain* (`user://player.json`): jatah kuis, status tutorial, dan petunjuk yang sudah dilihat. Dipisah agar membuat save baru tidak mereset jatah kuis mingguan.
- **Kapan tersimpan otomatis:** setiap akhir bulan, setiap event diputuskan, serta saat aplikasi di-pause (Android) atau ditutup.
- **Lokasi file di PC:** `%APPDATA%\Godot\app_userdata\Cuan Quest\`. Hapus folder `saves` untuk mulai dari nol.
- **Pelajaran dari bug:** urutan key `Dictionary` bisa berubah setelah melewati JSON. Loop yang mengambil angka acak harus memakai urutan tetap (lihat `Market._factor_order()`), kalau tidak hasil simulasi setelah load akan berbeda. Hal yang sama berlaku untuk RNG state 64-bit, yang disimpan sebagai string karena angka JSON hanya presisi 53-bit.
- **Menjalankan scene utama langsung (F6)** tetap bisa: `main.gd` otomatis membuat game baru dengan profil default.

## Latihan M5 (opsional)

1. Tambah latar belakang baru, misalnya `"pns"` (gaji stabil, volatilitas 0) di `data/economy.json`. Tombolnya otomatis muncul di layar Buat Karakter.
2. Buka file `auto.json` di folder save dengan VS Code, lihat strukturnya, lalu bandingkan dengan `GameState.to_dict()`.
3. Tambah istilah baru di `data/glossary.json` dan coba cari di popup glosarium.

## Latihan M4 (opsional)

1. Tulis event baru di `data/events.json`: salin event `found_money`, ganti `id`, judul, dan efeknya. Coba pakai `outcomes` agar hasilnya acak.
2. Tambah soal baru di `data/quiz.json` (ingat: `answer` dimulai dari 0).
3. Ubah `event_chance` di `data/economy.json` menjadi `1.0`, lalu rasakan bedanya jika setiap bulan ada event.

## Latihan M3 (opsional)

1. Tambah saham baru: salin blok `NUSA` di `data/assets.json`, ganti `id`, `name_key`, dan harganya, lalu tambahkan `ASSET_xxx` di CSV. Saham itu otomatis muncul di daftar Pasar.
2. Tambah berita baru di `data/news.json` dengan target `asset:ID_SAHAM_ANDA`.
3. Ubah `news_chance` di `data/market.json` menjadi `1.0` untuk melihat pasar yang penuh berita.

## Latihan M2 (opsional)

1. **Balancing:** ubah `salary` di `data/economy.json` menjadi `4000000`, lalu lihat bagaimana sisa uang bulanan menjadi minus jika memilih Mewah + Apartemen.
2. **Tambah pilihan:** tambahkan opsi makan `"homecook"` (masak sendiri) di `economy.json` beserta key terjemahannya di CSV. Tombolnya akan muncul otomatis karena dibuat dari data.
3. **Eksplorasi editor:** buka `scenes/main.tscn` dan klik node `MarketScreen`. Ikon "film" menandakan node itu instance dari scene lain. Klik ikon tersebut untuk membuka scene aslinya.

