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
| `user://` | localStorage | Tempat database simpanan `cuan_quest.db` (SQLite) & pengaturan |
| `tr("KEY")` | i18n `t("KEY")` | Teks diambil dari `localization/strings.csv` |
| **Instance scene** | `<MyComponent />` | Di `main.tscn`, setiap tab adalah instance dari scene lain |
| `@export var` | Props | Bisa diisi per-instance dari Inspector (contoh: `message_key` di placeholder) |
| `ScrollContainer` | `overflow-y: auto` | Setiap tab bisa di-scroll jika kontennya panjang |

## Struktur Project

```
data/
  assets.json                 Parameter aset (drift, volatilitas, fee, satuan, pola musiman, aliran acak)
  economy.json                Gaji, modal awal, pilihan makan & tempat tinggal (untuk balancing)
  market.json                 Siklus pasar, faktor (saham, kripto, komoditas, emas, valas), suku bunga, peluang berita
  news.json                   Template berita pasar & dampaknya ke harga (+ dampak ikutan "cross", berita komoditas)
  rumors.json                 Rumor pasar (v1.5d): peluang, gerak harga benar/jebakan, riset dasar & mendalam
  contracts.json              Proyek sampingan (v1.5d): 17 proyek, tier & reputasi, 3 strategi, peluang, bayaran
  achievements.json           Pencapaian (v1.5d): 21 pencapaian (syarat sebagai data), gelar, 7 bingkai avatar
  events/<kategori>.json      111 event hidup per kategori (finance, work, education, health, social,
                              market, scam, property, debt): syarat, pilihan, efek, tokoh. Cara menambah:
                              docs/PANDUAN_EVENT.md
  characters.json             Tokoh berulang (v1.5d): Bima, Ibu, Kak Wulan, Bu Ratna, atasan, rekan kerja
  insurance.json              Produk asuransi: premi, tanggungan, masa tunggu
  loans.json                  Pinjaman (v1.5c): KTA, kredit motor/mobil, KPR & KPR subsidi, denda, skor kredit
  vehicles.json               Kendaraan (v1.5c): harga, penyusutan, biaya rutin, kebahagiaan, produk kredit
  properties.json             Properti (v1.5c): harga, sewa, kenaikan harga, biaya beli/jual/rutin, KPR
  jobs.json                   Pekerjaan (bidang, jenjang, syarat, gaji, beban kerja) & aturan lowongan
  education.json              Program kuliah (syarat, lama, biaya, hasil) & beban kuliah
  quiz.json                   170 soal kuis (9 topik, urutan topik di "topics")
  glossary.json               100 istilah glosarium
  legal.json                  Kebijakan privasi, syarat penggunaan & lisensi pihak ketiga (tampil di game)
  activities.json             6 aktivitas bulanan & aturan energi
  leverage.json               Leverage (v2a): kelas & pilihan leverage, fee, biaya inap, batas margin call & likuidasi
  risk_profile.json           Kuesioner & 3 profil risiko
  unlocks.json                Syarat membuka tiap tahap instrumen
localization/strings.csv      Semua teks UI (kolom id & en)
addons/godot-sqlite/          Plugin SQLite (GDExtension, MIT): pustaka Windows + Android arm64
theme/main_theme.tres         Font global, warna tombol aktif, panel, progress bar
scripts/
  autoload/game_state.gd      ROOT STORE (class GameStore): profil, bulan, kas, kondisi, statistik, alur
                              bulanan, efek event, simpan/muat, akhir permainan. Domain lain di game/
  autoload/ad_service.gd      Iklan rewarded (STUB, nanti diganti AdMob dengan interface sama)
  autoload/settings.gd        Pengaturan perangkat (user://settings.cfg), mode hemat prosesor, batas FPS
  autoload/save_manager.gd    Simpan/muat ke database SQLite (user://cuan_quest.db) + simpan otomatis
  autoload/sfx.gd             Efek suara buatan kode + getar
  game/                       Modul GameState per domain (lihat "Arsitektur GameState")
    game_module.gd            Kelas dasar modul: reset, save_to/load_from, apply_effects, event_vars
    career.gd                 Lowongan, lamaran, gaji, kinerja, promosi, PHK, perjalanan karier
    education.gd              Tingkat pendidikan, kuliah, beasiswa, sertifikasi
    portfolio.gd              Kepemilikan aset, beli/jual, stop loss/take profit, bunga, profil risiko
    budget.gd                 Rencana gaji, autodebet, dana darurat
    debt.gd                   Utang & kredit: pinjaman, cicilan anuitas, tunggakan, macet, skor kredit
    vehicles.gd               Kendaraan: nilai menyusut, biaya rutin, beli tunai/kredit, jual, ditarik
    properties.gd             Properti: harga, beli tunai/KPR, dihuni/disewakan, jual, dilelang
    characters.gd             Tokoh berulang: kedekatan, nama atasan/rekan per perusahaan, saran Kak Wulan
    research.gd               Rumor pasar & riset: rumor benar/jebakan, penilaian riset, rekam jejak
    leverage.gd               Posisi leverage & margin: buka/tutup, tambah margin, cek harian, likuidasi
    contracts.gd              Proyek sampingan: papan tawaran, strategi, energi bulanan, hasil, reputasi
    annual.gd                 Laporan tahunan: catatan tahun berjalan, ditutup setiap Januari
    achievements.gd           Pencapaian & kosmetik (data pemain lintas permainan, bukan modul slot save)
    insurance.gd, dreams.gd, targets.gd, activities.gd, progress.gd
    life_events.gd            Event Director: jadwal event, antrean, keputusan, efek tertunda
  core/                       Logika murni tanpa UI (mudah dites)
    market.gd, market_asset.gd   Simulasi pasar (GBM, RNG ber-seed; aliran acak kedua untuk aset v2a)
    fmt.gd                    Format Rp1.234.567, +2,35%, tanggal game
    data_loader.gd            Baca JSON
    quiz_manager.gd           Bank soal + jatah mingguan (waktu nyata) + kredit iklan
    event_manager.gd          Pemilihan event berdasarkan syarat & bobot
    save_db.gd                Pembungkus tipis SQLite: query, insert banyak baris, transaksi, skema
    play_sessions.gd          Statistik sesi bermain (mulai, lama, jumlah bulan) untuk playtest
  ui/
    main.gd                   Shell: top bar, router tab, tombol Lanjut, popup
    price_chart.gd            Grafik garis (dipakai di Pasar & Portofolio)
    month_report.gd           Pembuat baris laporan (dipakai di popup & Portofolio)
    modal_popup.gd            Base class popup (signal closed)
    month_summary_popup.gd    Modal laporan bulanan
    event_popup.gd, quiz_popup.gd, info_popup.gd
    ui_text.gd                Helper teks: perubahan efek, syarat unlock, cache tampilan (changed_key)
    perf_overlay.gd           Info performa (FPS, waktu proses, memori, node) untuk uji di HP
    leverage_popup.gd         Popup buka posisi leverage & tambah margin (v2a)
    leverage_view.gd          Teks ringkasan posisi leverage (detail aset & Portofolio)
    home_scene.gd             Ilustrasi Hunian & Kendaraan di Beranda (3 lapis gambar, v1.5c)
    balance_sheet.gd          Kartu Neraca (aset - utang) di Portofolio & layar akhir (v1.5c)
    character_portrait.gd     Potret tokoh (SVG atau lingkaran + inisial) di popup event & Profil (v1.5d)
    screens/                  Satu script per tab
scenes/
  title.tscn                  Layar judul (main scene saat game dibuka)
  new_game.tscn               Buat karakter
  tutorial.tscn               Tutorial 5 layar
  end_screen.tscn             Layar akhir (hasil, statistik, analisis)
  main.tscn                   Shell aplikasi
  screens/                    home, market, portfolio, placeholder
  ui/month_summary_popup.tscn
```

**Alur data (satu arah, seperti Redux):**
`Tombol ditekan → screen memanggil GameState.xxx() atau GameState.<modul>.xxx() → data berubah → signal "changed" → semua screen menjalankan _refresh()`

## Arsitektur GameState (refactor 14 Oktober 2026)

`GameState` (autoload, skrip `scripts/autoload/game_state.gd`, tipe `GameStore`) dulu berisi 3.000+ baris. Sekarang ia hanya **root store** dan logika tiap domain ada di modul `scripts/game/`. Analogi web: root store + satu *slice*/store per fitur (Redux Toolkit / Pinia).

| Modul (`GameState.<nama>`) | Kelas | Isi |
|:--|:--|:--|
| `career` | `Career` | Lowongan, lamaran, tawaran, gaji, kinerja, kenaikan prestasi, promosi, PHK, keahlian, perjalanan karier |
| `education` | `Education` | Tingkat pendidikan (`level`), kuliah, uang kuliah, beasiswa, kelulusan, sertifikasi |
| `insurance` | `Insurance` | Polis, premi, klaim |
| `events` | `LifeEvents` | Event Director: jadwal event per bulan, antrean, keputusan (`resolve`), efek tertunda; katalog di `events.catalog` (EventManager) |
| `portfolio` | `Portfolio` | Kepemilikan, beli/jual (`trade_quote`), pesanan otomatis, bunga, riwayat transaksi, profil risiko |
| `budget` | `Budget` | Rencana gaji (`plan`, `preview_for`), autodebet, dana darurat |
| `dreams` | `Dreams` | Impian & kendaraan |
| `targets` | `Targets` | Target bulanan |
| `activities` | `Activities` | Energi & aktivitas bulanan |
| `progress` | `Progress` | XP, level, tahap unlock, hadiah kuis |
| `debt` | `Debt` | Pinjaman, cicilan, tunggakan, macet, skor kredit (v1.5c) |
| `vehicles` | `Vehicles` | Kendaraan: nilai menyusut, biaya rutin, kredit, ditarik (v1.5c) |
| `properties` | `Properties` | Properti, KPR, sewa, jual, lelang (v1.5c) |
| `characters` | `Characters` | Tokoh berulang & kedekatan (v1.5d) |
| `research` | `Research` | Rumor pasar, riset dasar & mendalam, rekam jejak riset (v1.5d) |
| `contracts` | `Contracts` | Proyek sampingan: papan tawaran, strategi, hasil, reputasi (v1.5d) |
| `annual` | `Annual` | Laporan tahunan: catatan tahun berjalan & laporan tahun-tahun lalu (v1.5d) |

**Yang tetap di GameState:** profil, `month`, `cash`, `health`, `happiness`, `stats`, `market`, `rng`, signal, `new_game()`, `advance_month()` (orkestrasi bulanan), `apply_effects()`, `to_dict()`/`load_from_dict()`, harga & pajak (`nominal()`, `income_tax()`), dan kondisi menang/kalah.

**Kontrak modul** (`scripts/game/game_module.gd`): tiap modul punya `gs` (rujukan ke GameState) dan boleh mengisi `load_data()`, `reset()`, `save_to(d)` / `load_from(d)`, `apply_effects(e)`, `event_vars(id)`. GameState memanggilnya berurutan lewat daftar `modules`. Format save tetap datar (SAVE_VERSION 3), jadi save lama tetap bisa dimuat.

**Contoh pemakaian dari UI:** `GameState.career.apply_job(i)`, `GameState.education.enroll("d3")`, `GameState.portfolio.buy("RDPU", 1_000_000)`, `GameState.events.resolve(index)`, `GameState.budget.preview_for(plan, income)`.

**Menambah fitur baru:**
- Fitur di domain yang sudah ada → tambahkan di modulnya (mis. utang kendaraan di `portfolio` atau modul baru `debt`).
- Domain baru → buat `scripts/game/<nama>.gd` (`class_name X extends GameModule`), isi `reset/save_to/load_from`, lalu daftarkan di `GameState` (`var x := X.new(self)` + masukkan ke `modules`).
- Event baru → cukup data, lihat [docs/PANDUAN_EVENT.md](docs/PANDUAN_EVENT.md).

**Cara refactor ini diuji:** "golden runner" memainkan 6 permainan × 96 bulan dengan seed tetap dan menulis seluruh state akhir; hasil sebelum dan sesudah refactor identik byte demi byte, ditambah 197 uji otomatis dan output simulator yang identik.

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
| 10 | Kuis mingguan (minimal 30 soal) | M4 | ✅ 39 soal; sejak v1.5-0: 6 soal/minggu, tanpa iklan |
| 11 | Sistem unlock instrumen | M4 | ✅ |
| 12 | Kondisi menang dan kalah serta layar akhir | M6 | ✅ |
| 13 | Save/load otomatis dan manual | M5 | ✅ |
| 14 | Pengaturan dan halaman profil | M5 + M6 | ✅ |
| 15 | Disclaimer simulasi dan kebijakan privasi | M6 | ✅ (isi [EMAIL KONTAK] sebelum rilis) |

## Milestone

- [x] **M1: Prototipe.** 1 aset, grafik, beli/jual + fee, saldo, tombol Lanjut
- [x] **M2: Loop bulanan.** Gaji, biaya hidup, kesehatan/kebahagiaan, laporan bulanan, tab Portofolio, navigasi bawah
- [x] **M3: Pasar lengkap.** 10 aset di 5 kelas, siklus bull/sideways/bear, korelasi, suku bunga acuan, 16 berita pasar, bunga & penalti deposito
- [x] **M4: Event hidup, kuis, unlock.** 33 event (termasuk efek tertunda & PHK), 39 soal kuis (3/minggu nyata + iklan stub), XP & level, 4 tahap unlock, antrean popup
- [x] **M5: Save/load, layar judul, buat karakter, tutorial & glosarium.** 3 latar belakang, 3 tingkat kesulitan, simpan otomatis + 3 slot manual, petunjuk saat tab pertama dibuka, tab Profil
- [x] **M6: Menang/kalah + layar akhir, pengaturan, kebijakan privasi.** 2 cara menang + pensiun, 3 cara kalah, penjualan paksa, layar akhir dengan analisis, statistik & riwayat, efek suara buatan kode, getar, bahasa, format angka ringkas, reset data
- [x] **M6.5: Melengkapi isi draft.** Energi & 6 aktivitas bulanan, lompat waktu (+6 Bln / +1 Thn), riwayat transaksi, periode grafik 1B/6B/1T/Semua, grafik alokasi aset + peringatan konsentrasi, profil risiko (kuesioner + peringatan di Pasar)
- [x] **Redesain UI "Senja Cuan"** (dikerjakan sendiri oleh pengembang)
- [x] **APK debug v1** untuk dicoba di HP (`build/cuan-quest-debug.apk`, preset "Android")
- [x] **Prototipe waktu A/B/C** (diarsipkan di cabang `archive/prototipe-waktu`; arah diganti, lihat `MVP_Cuan_Quest_Revisi3.md`)
- [ ] **v1.5-0 "Giliran Bulanan yang Hidup"**:
  - [x] (1) Pasar harian + animasi pergantian bulan (lihat bagian di bawah)
  - [x] (2) Pembagian gaji + autodebet; tombol +6 Bln / +1 Thn dihapus
  - [x] (3) Impian + target bulanan + perayaan
  - [x] (4) Event Director + kuis 6/minggu tanpa iklan
  - [x] (5) SQLite (semua langkah selesai; tinggal playtest)
- [x] **v1.5a "Realisme Ekonomi"**:
  - [x] (1) Inflasi, suku bunga BI & daya beli
  - [x] (2) Pajak + layar konfirmasi transaksi
  - [x] (3) Asuransi
  - [x] (4) Stop loss & take profit
  - [x] (5) Penyeimbangan ekonomi + simulator `tools/balance`
- [x] **v1.5b "Pekerjaan & Karier"**:
  - [x] (1) Fondasi: latar SMA/D3/S1 tanpa kerja, lowongan & melamar, tab Karier
  - [x] (2) Karier: kinerja, promosi, kenaikan prestasi, PHK, event kerja
  - [x] (3) Pendidikan & keahlian
  - [x] (4) Tampilan & cerita
  - [x] (5) Penyeimbangan
- [x] **v1.5c "Utang, Properti, Hunian"**:
  - [x] (1) Utang & skor kredit (KTA, cicilan, tunggakan, macet, pelunasan)
  - [x] (2) Kendaraan (aset menyusut, kredit motor/mobil)
  - [x] (3) Properti & KPR
  - [x] (4) Tampilan & cerita (ilustrasi hunian & kendaraan, neraca, event utang & properti)
  - [x] (5) Penyeimbangan (tawaran KTA, rumah subsidi, skor setelah macet)
- [x] **v1.5d "Tokoh, Riset, Kontrak, Konten"**:
  - [x] (1) Tokoh berulang & 10 rantai event
  - [x] (2) Riset pasar & rumor
  - [x] (3) Kontrak & proyek sampingan
  - [x] (4) Pencapaian, kosmetik & laporan tahunan
  - [x] (5) Perluasan konten & penyeimbangan
- [x] **Penutup v1.5**: legal & lisensi, performa & baterai, alat playtest (APK dicoba di HP; panduan `docs/UJI_AKHIR_V15.md`)
- [x] **v2a "Instrumen Lanjut"**:
  - [x] (1) Komoditas & emas
  - [x] (2) Valas
  - [x] (3) Leverage & margin
  - [x] (4) Peringatan & cerita
  - [x] (5) Penyeimbangan & uji celah
- [ ] **v2b/c/d** (lihat `MVP_Cuan_Quest_Revisi3.md`)

Rangkuman semua checklist MVP (v1, v1.5, v2, M7) ada di [docs/CHECKLIST_MVP.md](docs/CHECKLIST_MVP.md).
- [ ] **M7: Export rilis & Play Store** (setelah v2 selesai; tanpa monetisasi)

## Prototipe Waktu (diarsipkan)

Tiga prototipe sistem waktu (A: per jam, B: hari cepat, C: sesi pasar) sudah dicoba dan **tidak dipakai**: waktu yang berjalan sendiri terasa membosankan atau lag. Kodenya disimpan di cabang git `archive/prototipe-waktu` (`git switch archive/prototipe-waktu` untuk melihatnya). Kesimpulan dan arah baru ada di dokumen `MVP_Cuan_Quest_Revisi3.md`: giliran tetap bulanan, tetapi setiap bulan dibuat lebih hidup.

## Cara Kerja Simulasi Pasar (M3)

Setiap bulan `Market.step()` menjalankan (sejak v1.5-0 harga bergerak **harian**, lihat bagian berikutnya):
1. **Siklus pasar.** Saham dan kripto masing-masing berada di fase *bull*, *sideways*, atau *bear* selama beberapa bulan acak. Saat fase berganti, muncul berita "Analis: ...".
2. **Berita** (peluang 50%). Satu template dipilih dari `news.json` berdasarkan bobot, lalu memberi guncangan harga ke satu aset, satu kelas aset, atau suku bunga.
3. **Harga baru:** `harga × exp(drift_bulanan − ½σ² + σ·z) × (1 + guncangan)`, dengan `z = rho·z_pasar + √(1−rho²)·z_acak`. Bagian `z_pasar` yang sama untuk semua aset membuat saham cenderung naik-turun bersamaan (korelasi).
4. **Tabungan & deposito** tidak bergerak harganya. Bunganya (`suku bunga acuan + spread`, dipotong pajak) dibayar di `GameState.portfolio.pay_interest()`.

**Hasil kalibrasi** (300 simulasi × 10 tahun, median imbal hasil per tahun): RD Pasar Uang +4,6% · RD Saham +8,7% · Saham +4,5% s.d. +8,6% · Kripto +7,5% s.d. +12% (peluang rugi kripto sekitar 38%).

## Pasar Harian & Animasi Pergantian Bulan (v1.5-0 langkah 1)

- **Harga bergerak hari demi hari.** Saat Lanjut ditekan, `MarketAsset.step_month()` menjalankan 21 langkah (hari bursa: saham, reksa dana) atau 30 langkah (kripto) dengan `dt = 1/(12 x langkah)`. Total satu bulan tetap sama dengan simulasi bulanan v1, sehingga kalibrasi tidak berubah (dicek dengan 1.500 simulasi x 10 tahun, mesin lama vs baru).
- **Korelasi harian:** `Market.step()` membuat 30 angka acak bersama per faktor ("stock", "crypto"), satu per hari.
- **Berita bertanggal:** berita jatuh pada satu tanggal acak (`news["day"]`), sehingga terlihat sebagai lonjakan di grafik harian.
- **Riwayat bertingkat:** `history` berisi harga harian 24 bulan terakhir; `month_closes` berisi penutupan setiap bulan sepanjang permainan (dipakai periode "Semua" dan persentase perubahan bulanan). Ukuran save tetap terkendali.
- **Grafik:** `PriceChart.points_per_period` menentukan berapa titik membentuk satu bulan (1 untuk data bulanan, 21/30 untuk harian). `set_long_data()` mengisi data periode "Semua". Tab Pasar memakai periode 1B / 3B / 1T / Semua.
- **Animasi laporan:** `GameState` menyimpan `daily_worth` (kekayaan per tanggal) dan `movers` (aset yang paling bergerak) di laporan. Popup laporan menggambar grafik dari kiri ke kanan (`PriceChart.play_reveal()`, tween properti `reveal`), memutar angka kekayaan (`tween_method`), lalu memunculkan kartu sorotan. Ketuk grafik untuk melewati.
- **Save versi 2:** `SAVE_VERSION` naik ke 2; save lama ditolak dengan pesan `SAVE_OUTDATED`. Data pemain (`player.json`: kuis, tutorial, riwayat) memakai `PLAYER_VERSION` terpisah sehingga tidak ikut hilang.

## Rencana Gaji & Autodebet (v1.5-0 langkah 2)

- **Rencana dalam persen gaji** (`GameState.budget.plan`): gaya hidup, dana darurat, dan investasi otomatis per aset. Karena berupa persen, rencana otomatis menyesuaikan saat gaji naik, turun, atau saat menganggur (gaji 0 berarti tidak ada yang dibagi).
- **Satu sumber hitungan:** `GameState.budget.preview_for(plan, penghasilan)` dipakai popup Rencana Gaji, kartu Beranda, dan eksekusi di awal bulan, sehingga angka yang dilihat pemain selalu sama dengan yang dijalankan.
- **Urutan di awal bulan** (`_apply_budget`, dipanggil dari `_start_month`): gaji masuk → makan & tempat tinggal → gaya hidup (memengaruhi kebahagiaan) → setor dana darurat ke Tabungan sampai target 6 bulan pengeluaran pokok → autodebet per aset. Pos yang kasnya tidak cukup dilewati dan dicatat di laporan.
- **Kapan popup muncul:** di bulan pertama (rencana belum pernah disimpan), setelah laporan bila gaji pokok berubah, atau saat pemain menekan "Atur rencana gaji" di Beranda. Rencana pertama langsung dijalankan untuk bulan itu karena gajinya sudah masuk.
- **Konfigurasi** ada di `data/economy.json` bagian `budget` (langkah 5%, batas porsi, aset dana darurat, efek kebahagiaan gaya hidup).
- **Transaksi autodebet** tercatat dengan jenis `auto` di riwayat transaksi.
- **Tombol +6 Bln / +1 Thn dihapus** karena satu bulan kini cepat dan berisi keputusan. Fungsi `GameState.fast_forward()` tetap disimpan untuk masa pensiun (v2b).

## Impian, Target Bulanan & Perayaan (v1.5-0 langkah 3)

- **Impian** (`data/dreams.json`, 12 impian): pemain memilih maksimal 2 di awal permainan (popup "Pilih Impian"), dan bisa menambah sampai 3 impian aktif dari Beranda. Setiap impian punya **pos tabungan sendiri** (`GameState.dreams[i].saved`) yang diisi lewat porsi di Rencana Gaji atau setoran manual, dan berbunga seperti Tabungan.
- **Porsi saran** saat impian dipilih = setoran per bulan yang dibutuhkan agar tepat waktu, dibulatkan ke atas per 5% gaji, tetapi dibatasi sisa gaji di rencana agar rencana tidak melebihi gaji.
- **Terwujud** otomatis saat dana mencukupi (setelah setoran bulanan atau manual): dana dipakai, kelebihannya kembali ke kas, lalu kebahagiaan & XP naik dan muncul perayaan (confetti).
- **Tenggat terlewat:** popup wajib memilih perpanjang 12 bulan (kebahagiaan -3) atau lepaskan (dana kembali ke kas, kebahagiaan -5).
- **Kas minus:** setelah investasi dijual paksa, dana pos impian ikut dipakai sebelum dihitung bangkrut.
- **Target bulanan** (`GameState.targets.items`): 2 target acak per bulan dari daftar yang masuk akal (investasi manual, aktivitas tertentu, kas akhir bulan, naikkan kesehatan/kebahagiaan, kuis benar, setor ke impian, tidak menjual rugi). Hadiah kecil, gagal tidak dihukum. Target "akhir bulan" dinilai di `targets.finalize()` saat Lanjut ditekan.
- **Pembanding "kalau tidak bertransaksi":** portofolio dicatat di awal giliran (`_snapshot_turn`); saat Lanjut, selisihnya = (perubahan unit x pergerakan harga bulan itu) - fee. Autodebet tidak dihitung sebagai transaksi manual.
- **Perayaan & umpan balik:** `Confetti.burst()` (digambar lewat kode) untuk impian terwujud, tahap baru, dan target kemenangan; notifikasi singkat (toast) untuk target selesai dan naik level; kartu progres impian di sorotan laporan bulanan.
- **Urutan popup:** sinyal impian dikirim setelah laporan (`_flush_dream_signals`), sehingga urutannya laporan → perayaan/tenggat → tahap baru → event.

## Event Director & Kuis Tanpa Iklan (v1.5-0 langkah 4)

- **Jumlah event per bulan** diambil dari `difficulties[].event_counts` di `economy.json` (bobot untuk 0/1/2/3 event; Normal 15/40/30/15). Setelah 2 bulan tanpa event acak, bulan berikutnya memakai `quiet_counts` sehingga pasti ada kejadian.
- **Urutan per bulan** (`GameState.events.roll`): event kalender (mis. THR, `guaranteed`) → event lanjutan yang jatuh tempo (`chain_events`) → event acak. Event kalender & lanjutan tidak mengurangi jatah acak.
- **Diputuskan satu per satu:** event pertama jadi `pending_event`, sisanya di `event_queue`. Setelah satu diputuskan, `events._next_queued()` memunculkan berikutnya. Tombol Lanjut terkunci sampai semua selesai.
- **Konteks:** `events.context_flags()` menghitung kondisi pemain (kas berlebih/tipis, kesehatan/kebahagiaan rendah, memegang saham/kripto). Event dengan tag `"context"` di data event (`data/events/*.json`) bobotnya dikali saat kondisinya aktif, mis. investasi bodong ×3 saat kas berlebih, pinjol ×4 saat kas tipis.
- **Anti-sial beruntun:** setelah event buruk, bobot event buruk berikutnya dikali `bad_after_bad` (0,5).
- **Rantai event:** efek `"chain": {"event": id, "months": [min, max]}` menjadwalkan event lanjutan (`chain_only: true`, tidak pernah muncul acak). Contoh: pinjaman teman → Janji Temanmu; investasi bodong → Pengelola Kabur; pinjol → Penagih Pinjol.
- **Hasil simulasi** (20 permainan x 10 tahun, pilihan acak): sebaran 15/41/30/13%, rata-rata 1,42 event/bulan (sebelumnya 0,61). Karena event positif seperti kenaikan gaji ikut lebih sering, median gaji akhir naik dari Rp9,4 jt ke Rp13,4 jt dan median kekayaan dari Rp402 jt ke Rp558 jt. Perlu ditinjau saat penyeimbangan (inflasi v1.5a akan menekannya).
- **Kuis:** 6 soal per minggu nyata, tanpa iklan. Setiap soal yang dibuka memakai jatah; soal yang sudah muncul minggu ini tidak diulang di minggu yang sama (`QuizManager.shown_this_week`).
- **Iklan dilepas dari UI:** tombol "Tonton iklan" dihapus. `AdService` masih terdaftar sebagai autoload tetapi tidak dipanggil (disimpan untuk v3). Kebijakan privasi kini menyatakan game tanpa iklan.

## Inflasi, Suku Bunga & Daya Beli (v1.5a langkah 1)

- **Model** (`data/market.json` bagian `macro`, dijalankan `Market._step_macro()` tiap bulan): inflasi tahunan bergerak pelan di sekitar 3,5% (rumus AR(1): bulan ini = rata-rata + 0,96 x selisih bulan lalu + acak kecil). Indeks harga `price_level` naik inflasi/12 tiap bulan; riwayatnya di `price_levels` (satu angka per bulan).
- **Bank Indonesia:** target suku bunga = 2,25% + inflasi + 0,5 x (inflasi - 3,5%). Setiap bulan, jika selisih dengan suku bunga sekarang >= 0,4%, ada peluang 40% BI bergerak 0,25% dan mengumumkannya lewat berita (`NEWS_BI_RATE_UP/DOWN`, angka suku bunga baru ada di `value` berita). Hasil simulasi: ±2 kali per tahun, kisaran 3,5-8,5%.
- **Dampak suku bunga:** bunga tabungan & deposito (`rate_for`), imbal hasil RD pasar uang (`rate_linked` di `assets.json`), dan guncangan saham pada tanggal pengumuman. Berita bisa punya beberapa guncangan di tanggal berbeda dalam sebulan (`MarketAsset.step_month(..., day_shocks)`).
- **Harga hari ini:** semua harga di file data adalah harga AWAL permainan. `GameState.nominal(harga)` mengalikannya dengan indeks harga. Dipakai oleh `option_cost` (makan & sewa), `choice_cost` (event), `activity_cost`, `dream_cost`, hadiah kuis, dan nominal target bulanan.
- **Token di teks:** angka uang di data event & `dreams.json` ditulis `{rp:3000000}`. `UiText.money(teks)` menggantinya dengan nominal hari ini (`Fmt.rupiah_words`: "Rp3,1 juta"). Analogi web: seperti placeholder i18n `{{amount}}` yang diisi saat render. **Teks event baru yang menyebut uang wajib memakai token ini.**
- **Gaji:** setiap Januari gaji naik sebesar inflasi 12 bulan terakhir (`_index_salary`). Rencana gaji dalam persen, jadi tidak perlu popup tinjau ulang.
- **Laporan & UI:** bagian Ekonomi di laporan bulanan (inflasi, daya beli kas + tabungan + pos impian yang tergerus), kartu Daya Beli di Profil, chip inflasi di Pasar.
- **Simulasi 40 permainan x 10 tahun** (pilihan acak): indeks harga median 1,43; kekayaan nominal median Rp775 jt, kekayaan riil Rp536 jt (tanpa inflasi Rp587 jt); gaji akhir median Rp20,1 jt nominal. Semua permainan bertahan, jadi game masih tergolong mudah. Penyeimbangan dijadwalkan di langkah 5 setelah pajak & asuransi.
- **Save lama:** slot tanpa data inflasi tetap bisa dimuat; indeks harga dianggap mulai dari 1,0 saat dimuat.

## Tokoh Berulang & Rantai Event (v1.5d langkah 1)

- **Data:** `data/characters.json`: 6 tokoh (Bima sahabat, Ibu, Kak Wulan mentor keuangan, Bu Ratna tetangga, atasan & rekan kerja yang namanya dipilih dari daftar sesuai perusahaan), kedekatan awal, tingkat kedekatan (Renggang < 30, Biasa, Akrab ≥ 60, Sangat dekat ≥ 80), dan dampak kerja (`work_effects`).
- **Modul** `GameState.characters` (`scripts/game/characters.gd`, kelas `Characters`). State: `rel` (id → kedekatan 0-100), `met` (sudah dikenal), `work_company` (perusahaan atasan & rekan kerja sekarang). Analogi web: tabel *relationships* milik user yang dibaca & ditulis event.
- **Tokoh kantor:** namanya = `names[hash(perusahaan + id)]`, jadi selalu sama selama di perusahaan itu tanpa memakai undian. Pindah ke perusahaan baru (`_sync_work()`, dipanggil saat dibaca) = kedekatan kembali 50; setelah berhenti kerja, nama mantan atasan/rekan tetap dipakai di cerita lanjutan.
- **Dampak karier** (kecil, `work_effects`): atasan ≥ 70 → peluang promosi ×1,25; atasan ≤ 30 → peluang PHK ×1,5; rekan kerja ≥ 70 → target kinerja +3 (tampil di kartu kinerja tab Karier).
- **Event:** field `character`, `known`, `min_rel`/`max_rel`; efek `rel`; syarat `high_performance`/`low_performance`; isian `{boss}`, `{coworker}`, `{advice}` (saran Kak Wulan dari kondisi pemain: dana darurat, asuransi, rasio cicilan, gaya hidup, investasi, konsentrasi). `EventManager.requires_met()` kini juga memeriksa tokoh; event lanjutan (rantai) dicek ulang saat jatuh tempo (`LifeEvents.roll()`).
- **10 rantai event bertokoh** (32 event baru, total 90): Bima pinjam uang (event lama), koin viral → rug pull → Bima bangkit, kedai kopi (perjanjian tertulis vs saling percaya); Ibu sakit & BPJS, arisan online bodong; Kak Wulan: cek kesehatan keuangan, kelas keuangan, rekomendasi kerja (kedekatan ≥ 65); Bu Ratna: kerja bakti, tanah murah bersurat girik; atasan: presentasi klien, evaluasi kinerja & negosiasi gaji; rekan kerja: robot trading ilegal. Event lama lembur, proyek besar, konflik dengan atasan, dan bantuan untuk Ibu kini bertokoh.
- **UI:** baris tokoh (potret, nama, peran & kedekatan) di popup event, "Kedekatan Bima +5" di hasil event, kartu **Orang Terdekat** di Profil. Potret sementara: lingkaran berwarna + inisial (`CharacterPortrait`), otomatis memakai `assets/illustrations/characters/<id>.svg` jika ada.
- **Save:** kunci baru `relationships`, `people_met`, `work_company` (save lama: kedekatan awal).
- **Golden runner:** dengan 32 event baru dibuang, permainan identik dengan v1.5c.
- **Simulator:** pilihan event kini juga menilai kedekatan (`rel` x 0,15). Event Evaluasi Kinerja diperkecil (kenaikan 3%, peluang 60%, jeda 36 bulan, maksimal 4 kali) setelah simulator menemukan gaji riil S1 hemat x5,6 dalam 30 tahun; kini x4,7 (target x4-5). Tahun bebas finansial praktis tidak berubah: S1 hemat 12,5, S1 pelajar 10,6, SMA hemat 18,4.

## Rumor Pasar & Riset (v1.5d langkah 2)

- **Data:** `data/rumors.json`: peluang rumor per bulan (`chance` 0,5), jeda setelah rumor terjawab (`cooldown_months`), gerak harga per arah (`directions.up/down`: peluang benar, `pump` saat beredar, `true_move` jika benar, `trap_move` jika jebakan), pengali kripto (`class_scale`), biaya & akurasi riset (`research.basic/deep`), dan 10 jenis rumor (`target`: `asset:ID`, `random_stock`, `random_crypto`). Teks: `RUMOR_<ID>`, `RUMOR_<ID>_TRUE`, `RUMOR_<ID>_FALSE` di CSV.
- **Modul** `GameState.research` (`scripts/game/research.gd`, kelas `Research`), RNG sendiri. Setiap `advance_month()`: `market_input(bulan)` menjawab rumor yang beredar (guncangan `outcome` + berita Terbukti/Hoaks) atau mungkin memunculkan rumor baru (guncangan `pump` + berita), lalu hasilnya diteruskan ke `Market.step(bulan, extra)`. `after_market()` mencatat posisi awal pemain dan hasil rumor untuk laporan (`report.rumors`). Analogi web: layanan terpisah yang menyuntikkan data ke pipeline harga tanpa mengubah pipeline-nya.
- **Riset:** `research("basic" | "deep")` memakai energi bulanan (dan biaya untuk riset mendalam). Penilaian "kemungkinan benar / hoaks" sudah diundi saat rumor muncul (`verdicts`), tepat dengan peluang 55% / 75%, sehingga tidak bisa diundi ulang. Rekam jejak (`record`) dihitung saat rumor terjawab.
- **UI:** kartu **Kabar Burung** di atas berita tab Pasar dan di detail aset yang dirumorkan (teks rumor, gerak harga, tombol riset, hasil riset), bagian **Rumor & Riset** di laporan bulanan, kartu **Rekam Jejak Riset** di Profil (muncul setelah rumor pertama), petunjuk `HINT_RUMOR` saat rumor pertama muncul.
- **Save:** kunci baru `rumor`, `research_record`, `rumor_last`, `research_rng` (save lama: tanpa rumor).
- **Golden runner:** dengan `chance` 0 permainan identik dengan langkah 1, karena pasar tidak memakai RNG riset.
- **Simulator:** tipe pemain `pemburu_rumor` (hemat + membeli setiap rumor naik tanpa riset) dan `periset` (hemat + riset mendalam, membeli jika hasilnya mendukung); ringkasan mencetak jumlah rumor, transaksi rumor, imbal hasil rata-rata, dan akurasi riset.
- **Hasil simulator** (S1, 40 permainan × 30 tahun): ±114 rumor per permainan. Pemburu rumor rata-rata -2,0% per transaksi (43% untung); periset +6,3% (62% untung, akurasi nyata 75%, biaya riset Rp155 jt); pemain hemat tidak terpengaruh (bebas finansial tahun 12,6). Riset membantu, tetapi tidak mengubah tempo permainan.
- **Menambah rumor:** salin satu baris di `rumors` (`id`, `target`, `direction`, `weight`), lalu tambahkan tiga teksnya di CSV.

## Proyek Sampingan (v1.5d langkah 3)

- **Data:** `data/contracts.json`: jumlah tawaran per bulan (`offers`), proyek aktif maksimal (`max_active`), reputasi (`reputation`: perubahan per hasil & tambahan bayaran per poin), rumus peluang (`chance`), 3 tier (syarat reputasi & keahlian, bayaran per bulan, tambahan keahlian & XP), 3 strategi (`strategies`: energi, bonus peluang, bagian bayaran, peluang memuaskan, efek kondisi), kelelahan (`overload`), penalti kinerja, daftar klien per tier, dan 17 proyek (`track`, `tier`, `months`, opsional `regime` & `pay_asset`). Teks: `CONTRACT_<ID>` & `CONTRACT_<ID>_DESC` di CSV.
- **Modul** `GameState.contracts` (`scripts/game/contracts.gd`, kelas `Contracts`), RNG sendiri. `accept(index, strategi)` memakai energi bulan ini; `month_step()` (dipanggil `_start_month()` setelah energi diisi ulang) menerapkan kelelahan, menilai proyek yang tenggatnya tiba (`_resolve`), memakai energi untuk proyek yang berlanjut, lalu membuat papan tawaran baru (`refresh_board`). Hasil masuk laporan (`report.contracts_done`). `performance_penalty()` dipakai `Career.performance_factors()` (faktor `side`). Analogi web: marketplace freelance kecil dengan antrean job milik user.
- **UI:** bagian **Proyek Sampingan** di tab Karier (reputasi & aturan, kartu proyek aktif, kartu tawaran dengan tombol per strategi berisi energi & peluang), baris proyek di kartu Karier Beranda, bagian **Proyek Sampingan** di laporan bulanan, statistik proyek di Profil, energi "untuk proyek" di kartu energi, petunjuk `HINT_CONTRACT` saat proyek pertama diterima.
- **Save:** kunci baru `contract_board`, `contracts`, `contract_reputation`, `contract_energy`, `contract_seq`, `contract_rng`; statistik `projects_*` & `project_income` (save lama: tanpa proyek, papan terisi bulan berikutnya).
- **Hasil simulator** (40 × 30 tahun): tahun bebas finansial S1 hemat 12,6 → selalu 1 proyek 10,5 → selalu 2 proyek 9,6; SMA 18,4 → 14,7 → 13,4. Dua proyek sekaligus menguras kesehatan (±75) & kebahagiaan (±81) dan menurunkan kinerja kantor. Versi awal (bayaran 2× lebih besar dan keahlian lebih banyak) membuat S1 bebas finansial di tahun 7,6, jadi angka di data sudah diturunkan.
- **Menambah proyek:** salin satu baris di `projects` (`id`, `track` = id bidang di `jobs.json` atau `general`, `tier`, `months` [min, max], `weight`), lalu tambahkan nama & deskripsinya di CSV.

## Penyeimbangan Instrumen Lanjut (v2a langkah 5)

- **Tipe pemain baru di simulator** (`tools/balance/balance_sim.gd`): `penabung_emas` (20% porsi autodebet ke emas), `pedagang_musiman` (memegang sawit & kopi hanya saat drift musiman > 0,05), `pemegang_dolar` (15% kekayaan dalam dolar, diseimbangkan tiap Januari), dan tiga tipe leverage yang tahap 6-nya dibuka paksa di tahun 5 (`unlock_from`) agar strateginya bisa diukur: `penjudi_leverage` (acak, leverage maksimal), `leverage_disiplin` (long 2x saham & emas, tambah margin saat margin call), `musiman_leverage` (long sawit 10x selama musim naik). Ringkasan baru: nilai emas/komoditas & valas, transaksi musiman, dan leverage (posisi, likuidasi, untung/rugi termasuk posisi terbuka, biaya inap, kekurangan ditagih ke kas).
- **Hasil** (S1, 40 x 30 tahun): hemat bebas finansial tahun 12,6 (sama seperti sebelum v2a); emas 12,9; dolar 12,6 dengan kekayaan akhir lebih rendah (pelindung, bukan pertumbuhan); musiman +6% kekayaan akhir (rata-rata +8,1% per musim, 60% untung); leverage disiplin +4% dengan risiko likuidasi; musiman + 10x hampir impas dengan sebaran sangat lebar; penjudi leverage −11% (rugi leverage median −Rp1,5 M). Kesimpulan: tidak ada celah; angka tidak perlu diubah.
- **Uji celah** (`test_v2a_story._test_hedges`): long dolar AS 20x + short dolar Singapura 20x, dan emas fisik + short emas 10x, rugi rata-rata ±Rp3,6 jt per bulan karena biaya inap & fee dibayar dua kali.
- **Cara menjalankan:** `--persona=pedagang_musiman` (atau tipe lain) seperti biasa; tipe leverage memakai opsi data `unlock_from` di `PERSONAS`.

## Peringatan & Cerita Leverage (v2a langkah 4)

- **Peringatan risiko wajib** sebelum transaksi leverage pertama di tiap permainan: `main._request_leverage()` menampilkan `InfoPopup.open_warning()` (Batal sebagai tombol utama, "Saya Paham Risikonya" sebagai tombol kedua). Persetujuan disimpan di `GameState.leverage.risk_ack` (kunci save `leverage_ack`), dan `Leverage.quote()` menolak (`LEV_ERR_WARNING`) selama belum disetujui, jadi aturan ini tidak bisa dilewati dari kode lain (mis. simulator). Analogi web: centang "Saya setuju" yang juga dicek di server, bukan hanya di form.
- **Margin call & likuidasi** setelah laporan bulanan: `main._enqueue_leverage_alert(report)` membaca `report["leverage"]` (berisi `asset_id`), menampilkan popup peringatan dengan tombol **Lihat Posisi** (`_show_asset()` → `MarketScreen.show_asset()` membuka detail dan menggulir ke kartu leverage). Beranda menampilkan spanduk merah selama `Leverage.calls()` tidak kosong.
- **`InfoPopup.open_warning()`**: varian popup informasi dengan lencana "!" merah, judul merah, dan bunyi `alert`; `open()` biasa tetap bergaya perayaan.
- **Event baru** (7, total 111): `forex_broker_bonus` → `forex_broker_locked` (broker valas ilegal: bonus 100%, lalu dana ditahan dengan alasan "pajak penarikan"), `binary_option_flex` (influencer opsi biner), `vip_signal_group` (grup sinyal berbayar), `bima_leverage` (Bima & leverage 100x), `ibu_gold_lebaran` (perhiasan vs emas batangan, bulan Maret), `leverage_sleepless` (syarat baru `has_margin_call`). Menolak penipuan baru ikut dihitung untuk pencapaian Kebal Tipu.
- **Lain-lain:** 8 istilah glosarium (leverage, margin, margin call, likuidasi, long, short, biaya inap, ekuitas), analisis layar akhir (`EndAnalysis`: likuidasi, rugi melebihi margin, biaya inap, atau untung tanpa likuidasi), statistik Profil (posisi dibuka/dilikuidasi, untung/rugi leverage), dan konteks event `holds_risky` kini juga aktif saat ada posisi leverage.

## Leverage & Margin (v2a langkah 3)

- **Posisi** (`GameState.leverage`, kelas `Leverage`, `data/leverage.json`): margin (uang sendiri) x leverage = besar posisi; untung/rugi = arah x unit x (harga sekarang - harga buka). Saham hanya long 2x (seperti transaksi margin bursa), emas & komoditas 2/5/10x, valas 5/10/20x, long atau short; kripto & reksa dana tidak bisa. **Margin terpisah per posisi** dan **satu posisi per aset** (maks. 5 posisi).
- **Ekuitas** = margin + untung/rugi berjalan - biaya inap. **Biaya inap** = (suku bunga acuan + 4%) per tahun atas dana pinjaman (besar posisi - margin), terkumpul setiap hari dan dipotong dari ekuitas. Menambah margin menjauhkan harga likuidasi sekaligus mengurangi pinjaman.
- **Cek harian** (`check_month()`, dipanggil `advance_month` setelah pasar & pesanan otomatis): untuk setiap hari bursa, biaya inap ditambah lalu ekuitas dihitung dengan harga hari itu. Ekuitas ≤ 40% margin → **likuidasi** di harga hari itu (`close(uid, "lev_liquidated", harga)`). Selamat sampai akhir bulan tetapi ekuitas < 70% → **margin call** (`call = true`). Harga likuidasi & margin call = `price_at_ratio()`.
- **Rugi melebihi margin ditagih ke kas** (tanpa perlindungan saldo negatif): jika harga melompat melewati batas karena berita, uang yang kembali bisa minus. Kas minus ditangani seperti biasa (aset dijual paksa, lalu posisi leverage ditutup paksa lewat `cover_cash()`, lalu dana impian; tetap minus 3 bulan = bangkrut). Inilah yang menutup celah "pasang long & short lalu berharap satu dilikuidasi".
- **Tahap 6** (`unlocks.json`, tipe syarat baru `stage`, `research_correct`, `credit_score`): Tahap 5 terbuka, riset rumor tepat ≥ 5, kuis Valas & Leverage 8 benar, skor kredit ≥ 60. Tahap tanpa aset baru memakai `desc_key` untuk teksnya.
- **Tampilan:** kartu **Leverage** di detail aset (syarat, tombol buka, atau ringkasan posisi + Tambah Margin / Tutup Posisi), `LeveragePopup` (dibuat lewat kode di `main.gd`, seperti laporan tahunan) dengan pratinjau dari `quote()` (besar posisi, fee, biaya inap, harga margin call & likuidasi, rugi jika harga bergerak 5%/10%), daftar **Posisi Leverage** di Portofolio, bagian **LEVERAGE** di laporan bulanan, jenis transaksi `lev_open/lev_close/lev_liquidated/lev_forced`, baris neraca.
- **Kekayaan bersih** & grafik harian laporan memuat ekuitas posisi (`total_equity()`, `daily_value(hari)`); tanpa posisi nilainya tepat 0, jadi golden runner tetap identik. Kunci save baru: `positions`, `position_seq`, `leverage_record`.
- **Uji celah:** strategi acak (arah & aset acak, leverage maksimal, ditahan sebulan) rugi rata-rata ±12% margin per posisi-bulan karena fee & biaya inap; long + short aset yang sama ditolak; lompatan harga -20% pada long 10x menagih ±Rp10 jt ke kas.

## Valas (v2a langkah 2)

- **4 kurs kelas `forex`** (`data/assets.json`, tahap 5): Dolar AS (USD/IDR), Euro, Dolar Singapura, Yen Jepang (harga per 100 yen). Harga = rupiah per 1 unit; **kurs naik = rupiah melemah**. Fee beli & jual 0,25% (selisih kurs 0,5%), tanpa bunga.
- **Faktor `fx`** = pelemahan rupiah, terikat ke faktor saham dengan `rho -0,4` (saham turun → rupiah melemah). Tiap kurs ikut faktor ini dengan `rho` berbeda (USD 0,9, SGD 0,8, EUR 0,6, JPY 0,5).
- **Suku bunga** (`rate_drift` di aset, `MarketAsset.extra_drift`): drift tahunan berubah sebesar `rate_drift x (suku bunga BI sekarang - suku bunga awal)`. `-0,8` = BI 1% lebih tinggi → kurs naik 0,8%/tahun lebih lambat. Ditambah guncangan saat BI mengumumkan keputusan (`cross` di berita `rate_up`/`rate_down`). Aset lama tidak terpengaruh (nilainya tepat 0).
- **Sentimen:** bursa global anjlok → rupiah melemah dan yen paling diburu; modal asing masuk ke bursa → rupiah menguat. Plus 9 berita valas sendiri.
- **Kelompok berita** (`market.json` → `ext_news`): setiap kelompok punya satu peluang per bulan (komoditas 0,4, valas 0,3), sehingga menambah berita valas tidak mengurangi berita komoditas. Field `group` di `news.json`.
- **Tahap 5** (`unlocks.json`): kekayaan bersih ≥ Rp500 jt + 5 soal topik baru **Valas & Leverage** (`forex`, 20 soal, juga dasar leverage untuk tahap 6 nanti). Setelah tahap 4 terbuka, kuis otomatis fokus ke topik ini.
- **Hasil uji** (10 pasar x 60 tahun): USD/IDR naik ±2,3%/tahun (gejolak ±8%), EUR ±1,3%, SGD ±2,2% (paling tenang), JPY ±0,4% (paling liar); korelasi bulanan dengan RD saham USD -0,30, JPY -0,19.
- **Satuan** kini memuat jumlahnya (`UNIT_GRAM` = "1 gram", `UNIT_JPY100` = "100 yen") karena teksnya "1 unit = %s".

## Komoditas & Emas (v2a langkah 1)

- **4 aset baru kelas `commodity`** (`data/assets.json`): Emas Batangan per gram (tahap 3, fee beli & jual 1% = selisih harga ±2%), Minyak Mentah per barel, Minyak Sawit (CPO) per ton, Kopi Robusta per kg (tahap 4, fee 0,3%). Field baru: `unit_key` (satuan 1 unit, tampil di detail), `seasonal` (12 angka), `stream`.
- **Aliran angka acak kedua** (`Market.rng_ext`, seed + `ext_seed_offset`): semua yang baru (aset, faktor `commodity` & `gold`, berita `stream: 1`) memakai RNG ini, sehingga urutan angka acak pasar lama tidak bergeser dan harga saham/kripto/reksa dana, inflasi, serta suku bunga **sama persis** dengan versi sebelumnya. Analogi web: menambah tabel baru dengan sequence ID sendiri, bukan menyisipkan baris di tengah tabel lama sehingga semua ID bergeser.
- **Faktor terikat** (`market.json` → `factors.<f>.link`): faktor baru boleh ikut faktor lama dengan korelasi tertentu tanpa angka acak tambahan. Emas `rho -0,3` terhadap saham (cenderung naik saat saham turun), komoditas `+0,3`. Faktor `regimes: false` = tanpa siklus naik/turun (emas).
- **Pola musiman** (`seasonal`): tambahan drift tahunan per bulan kalender, dijumlah 0 sehingga drift setahun tetap. Bulan yang dipakai = bulan saat Lanjut ditekan. CPO cenderung menguat Nov-Mar & melemah Jun-Sep, kopi menguat Jan-Mar & melemah Mei-Jul, minyak menguat Feb-Mei & melemah Sep-Des. Teks di detail aset dibuat otomatis dari data (`UiText.season_text`, ambang ±0,10).
- **Dampak ikutan berita** (`news.json` → `cross`): guncangan berita x pengali tetap ke aset/faktor lain, tanpa angka acak. Bursa global anjlok → emas naik & komoditas turun; BBM naik → minyak naik; BI menaikkan suku bunga → emas tertekan; batu bara melonjak → komoditas ikut naik. Plus **13 berita komoditas** (OPEC+, El Niño, embun beku Brasil, biodiesel, larangan ekspor sawit, bank sentral memborong emas, ekonomi Tiongkok).
- **Kalibrasi** (uji 10 pasar x 60 tahun): imbal hasil per tahun emas ±5,6%, minyak ±3,2%, CPO ±3,3%, kopi ±2,9% (komoditas kira-kira mengikuti inflasi; gejolak tinggi menurunkan pertumbuhan geometrik, jadi drift dasarnya lebih tinggi). Korelasi bulanan dengan RD saham: emas -0,23, CPO +0,10, minyak +0,14.
- **Save lama:** aset yang belum ada di save mendapat riwayat isian 12 bulan (`Market._backfill`, harga awal x indeks harga sekarang); siklus komoditas dimulai saat dimuat.
- **Menambah komoditas:** satu baris di `assets.json` dengan `"stream": 1` dan `factor` `commodity`/`gold`, teks `ASSET_<ID>`, `DESC_ASSET_<ID>` (penjelasan khusus), dan satuan `UNIT_*`. Berita yang menyasar `asset:ID` wajib memuat `%s`.
- **Golden runner v7** (`scratchpad/v2a/golden7.gd` + `cmp_golden9.py`) membandingkan juga berita pasar lama setiap bulan.

## Penutup v1.5: Performa, Playtest & Legal

- **Hemat baterai** (`Settings._ready()`): `OS.low_processor_usage_mode = true`, jadi layar hanya digambar ulang saat ada yang berubah (animasi, scroll, sentuhan). Diam di Beranda = hampir 0 FPS. `Engine.max_fps = 60` agar HP berlayar 90/120 Hz tidak menggambar lebih sering dari perlu. Analogi web: halaman statis yang hanya *repaint* saat DOM berubah, bukan *game loop* `requestAnimationFrame` terus-menerus.
- **Info performa** (`PerfOverlay`, `scripts/ui/perf_overlay.gd`): Profil > Pengaturan > Info performa. Kotak kecil di atas tombol Lanjut, diperbarui tiap 0,5 detik: FPS, waktu proses per frame, memori statis, jumlah node. Disimpan di `settings.cfg` (`display/perf_overlay`), mati secara bawaan. Analogi web: panel *Performance* di DevTools, versi mini.
- **Cache tampilan** (`UiText.changed_key(cache, bagian, kunci)`): setiap bagian layar yang berat (riwayat transaksi, laporan, pencapaian, papan lowongan, statistik, tokoh) hanya dibangun ulang jika kunci datanya berubah. Kunci = `[run_id, bulan, format angka]` + data yang dipakai bagian itu. Analogi web: `React.memo` / `useMemo` dengan *dependency array*. Bila menambah data baru ke sebuah bagian, **tambahkan juga ke kuncinya**, kalau tidak tampilan tidak ikut berubah. Beranda & Pasar juga tidak di-*refresh* saat tabnya tidak terlihat (diperbarui saat tab dibuka lagi lewat `visibility_changed`).
- **Hasil di PC** (benchmark 30 tahun): Lanjut ±2 ms, simpan ±15-30 ms, memori +1,6 MB dalam 30 tahun. Refresh setelah aksi: Portofolio 141 → ±3-8 ms, Karier 67 → ±10 ms, Profil 90 → ±8 ms. Uji di HP: `docs/UJI_AKHIR_V15.md`.
- **Sesi bermain** (`PlaySessions`, `scripts/core/play_sessions.gd`, data pemain kunci `sessions`): setiap Lanjut mencatat waktu nyata. Jeda > 15 menit memulai sesi baru; maks. 20 sesi disimpan. Profil > **Sesi Bermain** menampilkan rata-rata bulan per sesi (10 terakhir) dan 5 sesi terakhir, untuk mengukur target playtest v1.5-0 (≥ 10 bulan per sesi). Data hanya di HP.
- **Analisis event di simulator** (`tools/balance/balance_sim.gd`, baris "Event"): jumlah event per tahun, persentase event buruk, persentase event yang menambah kekayaan, dan dampak riil per tahun (perubahan kekayaan bersih dibagi tingkat harga). Hasil: ±19-20 event/tahun, ±26% buruk, hanya ±3% yang langsung menambah kekayaan. Kekhawatiran lama (event positif terlalu sering) sudah teratasi sejak kenaikan gaji pindah ke sistem karier.
- **Legal:** disclaimer di layar judul ("... Uang virtual; aturan disederhanakan."), kebijakan privasi & syarat diperbarui (database lokal, data pemain lintas permainan, statistik sesi, izin getar, jam perangkat, tanpa iklan & analitik, tidak berafiliasi dengan lembaga resmi), dan menu baru **Lisensi Pihak Ketiga** (`legal.json` kunci `licenses`: Godot & godot-sqlite MIT, SQLite domain publik, Fredoka & Lilita One OFL 1.1). Teks MIT/OFL **wajib** ikut ditampilkan di aplikasi; jika menambah pustaka atau font baru, tambahkan lisensinya di sini.

## Pencapaian, Kosmetik & Laporan Tahunan (v1.5d langkah 4)

- **Pencapaian** (`data/achievements.json`, `GameState.achievements`, kelas `Achievements`): data pemain lintas permainan seperti kuis & petunjuk, disimpan di tabel `player` (kunci `achievements`: `unlocked`, `frame`, `title`), jadi tetap ada saat permainan baru dimulai. Syarat = `type` + `min` (stat, nilai investasi, dana darurat, kekayaan, bebas finansial, rumah, kuis, jenjang, skor kredit, riset tepat, kedekatan, lama bermain, investor sabar). Analogi web: tabel *badges* milik akun, terpisah dari data tiap sesi.
- **Kapan diperiksa:** setiap kali `GameState.changed` dikirim (aksi pemain) dan sekali di akhir `advance_month()` (`check_achievements()`), sehingga popup perayaan muncul setelah laporan bulanan. Juga saat layar utama dibuka (save lama langsung mendapat pencapaian yang syaratnya sudah terpenuhi). Statistik baru untuk syarat: `scams_avoided` (menolak penipuan), `mortgages_paid_off`, `bear_months_held` (bulan memegang saham ≥ Rp5 jt saat pasar lesu).
- **Kosmetik:** gelar (`title: true` → teks `TITLE_<ID>`) dan bingkai (`frame` → daftar `frames`: warna garis, latar, cahaya). `UiText.apply_avatar_frame()` mengganti gaya panel AvatarFrame; dipakai di top bar, Profil, dan layar akhir. Bagian **Tampilan** di Profil untuk memilih; bingkai/gelar yang belum terbuka tampil redup.
- **Laporan tahunan** (`GameState.annual`, kelas `Annual`, modul slot save): setiap laporan bulanan dijumlahkan ke `acc`; setiap Januari `close_year()` membuat laporan tahun lalu (maks. 40 disimpan) dan signal `year_closed` membuka `AnnualPopup` (`scenes/ui/annual_popup.tscn`, isi dari `MonthReport.fill_annual()`). Menu **Laporan Tahunan Terakhir** di Profil membukanya lagi. Save lama: catatan dimulai saat dimuat dan laporan pertamanya ditandai sebagian.
- **Save:** kunci slot baru `year_acc`, `annual_reports`; data pemain `achievements`.
- **Hasil simulator** (S1, 40 × 30 tahun): median 12 dari 21 pencapaian untuk pemain hemat, 11 untuk pemain acak; Kebal Tipu 100% / 73% / 0% dan Investor Sabar 100% / 23% / 0% (hemat / acak / boros).
- **Menambah pencapaian:** tambah satu baris di `achievements` (`id`, `type`, `min`, opsional `key`, `title`, `frame`), lalu teks `ACH_<ID>`, `ACH_<ID>_DESC` (dan `TITLE_<ID>`) di CSV. Ikon `assets/icons/achievements/<id>.svg` otomatis dipakai jika ada.

## Perluasan Konten & Penyeimbangan (v1.5d langkah 5)

- **Kuis 39 → 150 soal** (`data/quiz.json`): Dasar Keuangan 25, Risiko 20, Penipuan 20, Instrumen 25, dan 4 topik baru masing-masing 15 soal: **Utang & Kredit**, **Properti**, **Karier & Pajak**, **Asuransi**. Faktanya mengikuti aturan Indonesia (PTKP TK/0 Rp54 jt, SPT Tahunan 31 Maret, THR paling lambat H-7, PPh final sewa 10%, PPh penjualan properti 2,5%, jaminan LPS, SLIK OJK, batas akses aplikasi pinjol legal, kripto kini diawasi OJK). Urutan topik dibaca dari data (`topics`), sehingga chip topik di tab Karier bertambah otomatis. Pencapaian kuis dinaikkan ke **50 soal benar** (`quiz_50`).
- **14 event baru (total 104)**. Musiman (`month_of_year`): resolusi tahun baru (Januari), banjir & demam berdarah (Februari), batas lapor SPT & Ramadan (Maret), mudik Lebaran (April), biaya sekolah adik (Juli), lomba 17 Agustus, liburan akhir tahun (Desember). Pelengkap: tawaran kartu kredit (bayar penuh vs bayar minimum), HP baru rilis, undian tabungan resmi, hoaks "bank bangkrut" di grup keluarga, proyek akhir pekan rekan kerja (perjanjian tertulis vs saling percaya). Sebagian memakai tokoh berulang (Ibu, Bu Ratna, rekan kerja).
- **9 istilah glosarium baru** (total 81): aturan 72, bunga flat, dollar cost averaging, LPS, obligasi, rebalancing, SBN ritel, SPT Tahunan, THR.
- **Uji konten otomatis** memeriksa semua soal (4 opsi berbeda, jawaban, penjelasan, topik) dan semua event (syarat, tokoh, efek, rantai, token uang `{rp:N}`, bulan musiman), sehingga konten yang ditambah lewat file data langsung tervalidasi.
- **Menambah soal kuis:** satu baris di `data/quiz.json` (`id` unik, `topic` dari daftar `topics`, `q`, 4 `options`, `answer` mulai 0, `explain`). Topik baru = tambah id di `topics` dan teks `TOPIC_<TOPIK>` di CSV.
- **Hasil simulator** (40 × 30 tahun): ekonomi tetap seimbang setelah bobot event baru diturunkan dan Pelatihan dari Kantor dinaikkan (S1 hemat bebas finansial tahun 12,6, SMA 19,1, pemain acak 60%). Pelajaran penting: menambah banyak event ke jatah acak bisa mengencerkan event karier; bandingkan dengan opsi simulator `--skip-events=id1,id2`.

## Penyeimbangan Utang, Properti & Hunian (v1.5c langkah 5)

- **Target rancangan (MVP 5.3.7):** pemain hemat bergaji tinggi yang membeli rumah tidak bebas finansial sebelum usia ±40, dan gagal bayar terasa berbahaya tetapi bisa dipulihkan.
- **Penyesuaian dari hasil simulator:**
  - **Tawaran KTA pre-approved** hanya untuk skor kredit Baik (`offer.min_score` 60 di `loans.json`) dan tidak lagi lebih sering muncul saat kas menipis. Bank menawarkan kredit kepada nasabah dengan riwayat baik, bukan kepada yang sedang kesulitan. Paylater tetap lebih longgar (skor ≥ 40).
  - **Rumah subsidi:** ongkos perjalanan ke kota Rp400 rb per bulan saat dihuni (`commute_cost`, ditagih sebagai biaya tempat tinggal lewat `Properties.home_option()`) dan baru boleh dijual setelah 5 tahun (`min_hold_months` 60, aturan FLPP; `sell_quote()` mengembalikan `locked`). Lelang karena macet tidak terhalang aturan ini. Sebelumnya rumah subsidi menjadi jalan pintas: SMA bebas finansial 3 tahun lebih cepat daripada menyewa.
  - **Skor kredit setelah macet** paling tinggi 30 (`credit.default_max`): kategori Buruk, sehingga pengajuan ditolak ±10 bulan dan butuh ±30 bulan untuk kembali Baik. Sebelumnya pemain dengan skor 100 hanya turun ke ±50 dan pulih dalam 9 bulan.
- **Simulator** (`tools/balance`): tipe pemain baru **pembeli_rumah_nekat** (Rumah Tipe 45 DP 10% begitu syarat terpenuhi, tanpa dana darurat, pilihan event acak; `home_buffer` = cadangan bulan biaya hidup sebelum membeli). Ringkasan kini mencetak tawaran kredit yang diterima, restrukturisasi, take over KPR, dan pemulihan skor kredit setelah macet.

| Tipe pemain (Normal, 40 permainan x 30 tahun) | Bebas finansial | Catatan |
|:--|:--|:--|
| S1 hemat (menyewa kos) | 100%, median tahun 12,6 (usia ±34) | tidak berutang |
| S1 pembeli rumah subsidi (KPR FLPP) | 100%, tahun 13,6 | sebelum penyesuaian 12,4: kini sedikit lebih lambat dari menyewa |
| S1 pembeli Rumah Tipe 45 (KPR DP 20%) | 100%, tahun 22,4 (usia ±44) | take over KPR 45%, total bunga KPR Rp1,02 M, lelang 0% |
| S1 pembeli rumah nekat (DP 10%, tanpa cadangan, pilihan acak) | 55%, tahun 19,8 | 8% rumahnya dilelang |
| S1 pengendara (motor & mobil kredit) | 100%, tahun 20,3 | |
| S1 gaya hidup mewah / pengutang | 0% | bangkrut 5/40 dan 4/40 |
| SMA hemat | 95%, tahun 18,8 | |
| SMA pembeli rumah subsidi | 98%, tahun 17,6 | sebelum penyesuaian 15,5 |
| SMA gaya hidup mewah | 0% | bangkrut 28/40 (tanpa tawaran kredit 22/40); 83% menerima tawaran kredit |
| SMA pengutang | 0% | bangkrut 23/40; 40% pernah macet |

Tingkat kesulitan (S1 pembeli Rumah Tipe 45): Santai tahun 19,3, Normal 22,4, Sulit 24,2 (85% tercapai).

- **Kesimpulan:** kedua target tercapai. Membeli rumah di kota menunda kebebasan finansial S1 sampai usia ±44 (rumah subsidi tidak lagi mempercepatnya); pembeli yang nekat 8% kehilangan rumahnya; utang konsumtif tanpa agunan yang macet hampir selalu berakhir bangkrut, sedangkan KPR yang macet bisa dipulihkan (skor kembali Baik ±30 bulan setelah lelang).
- **Catatan:** pemain yang tetap menyewa kos dan hidup hemat masih bisa bebas finansial di usia ±34. Ini jalan "hidup sederhana" yang sah, dan pilihannya kini punya harga yang jelas (tanpa rumah, tanpa kendaraan). Tinjau lagi saat v2b (siklus hidup penuh & pensiun).

## Tampilan & Cerita: Hunian, Neraca, Event Utang & Properti (v1.5c langkah 4)

- **Kartu Hunian & Kendaraan** (Beranda, di bawah kartu Karier): `HomeScene` (`scripts/ui/home_scene.gd`) menumpuk 3 gambar berukuran sama (624 x 260): latar `home/bg.svg`, tempat tinggal `home/<id>.svg` (id hunian sewa di `economy.json` atau id properti yang dihuni), dan kendaraan `vehicle/<id>.svg` (kendaraan termahal, atau `walk`). Keterangan di bawahnya: "Kos · Jalan kaki & angkutan umum". Gambar sekarang masih **pengganti sederhana**; gambar final cukup menimpa file dengan nama yang sama (`docs/KEBUTUHAN_ASET.md`). Analogi web: komponen `<img>` yang `src`-nya dihitung dari state.
- **Neraca** (tab Portofolio setelah grafik kekayaan, dan "Neraca Akhir" di layar akhir): `GameState.balance_sheet()` memberi rincian aset (kas, tabungan dana darurat, investasi, dana impian, kendaraan, properti) dan utang per pinjaman; `BalanceSheet.fill()` merendernya beserta bar **rasio utang terhadap aset** (hijau ≤30%, emas ≤50%, merah di atasnya). Totalnya sama persis dengan `net_worth()`.
- **Event baru** (9, di `data/events/property.json` & `debt.json`, panduan di `docs/PANDUAN_EVENT.md`):
  - **Properti:** Atap Bocor (rumah tapak; perbaiki tuntas / tambal / biarkan dengan efek tertunda), Ingin Renovasi (rumah yang dihuni; renovasi jarang balik modal), Penyewa Telat Bayar (beri waktu / minta pindah). Biaya = persen nilai pasar properti (`cost_property`).
  - **Tawaran kredit:** Beli Sekarang, Bayar Nanti (paylater Rp6 jt, 12x, ±48% per tahun; produk tersembunyi `paylater` di `loans.json`) dan Telepon dari Bank (KTA pre-approved sampai 3x gaji, 36 bulan). Hanya muncul jika pengajuannya lolos syarat bank.
  - **Terjadwal oleh `Debt.scheduled_events()`** (tanpa undian): Penagih Utang Datang / Surat Peringatan Terakhir saat menunggak 2 bulan (bayar tunggakan, **restrukturisasi** 75% disetujui: tunggakan masuk pokok + tenor 12 bulan, atau menghindar), dan Masa Bunga Tetap KPR Berakhir sebulan sebelum mengambang (**take over** ke bank lain: bunga tetap BI + 1% selama 2 tahun dengan biaya 3% sisa pokok, syarat pegawai, skor ≥60, tanpa tunggakan, sisa tenor ≥2 tahun; **lunasi sebagian** 10% pokok + penalti 2%; atau terima bunga mengambang).
  - Angka di teks, biaya pilihan (`cost_var`), dan efeknya dihitung sekali di `event_vars()` lalu disimpan bersama event, jadi selalu cocok (juga setelah game dimuat ulang). Perubahan utang & skor kredit tampil di hasil event ("Utang +Rp6.000.000").
- **Petunjuk & cerita:** petunjuk sekali seumur pemain sebelum pertama kali membuka pinjaman, membeli kendaraan, atau melihat properti dijual (`main.gd` `_hint()`); cerita **Rumah Sendiri!** dengan konfeti saat pertama kali menghuni rumah sendiri; tutorial halaman Beranda menyebut kendaraan, rumah, dan pinjaman; rincian KPR di popup pinjaman menampilkan "tetap sampai ..." / "mengambang".
- **Analisis akhir:** restrukturisasi, tawaran kredit yang diterima, dan take over KPR. 5 istilah glosarium baru (Neraca, Paylater, Rasio utang terhadap aset, Restrukturisasi kredit, Take over KPR).
- **Statistik baru:** `offer_loans`, `restructures`, `refinances`. Simulator menilai pilihan event utang (`_debt_money()`: bunga tawaran kredit = biaya, take over = bunga yang dihemat).
- **Golden runner:** dengan 9 event baru dibuang (`--skip-events`), permainan identik dengan langkah 3, jadi perubahan lain (neraca, ilustrasi, kode event) tidak mengubah perilaku.
- **Simulator** (Normal, 40 permainan x 30 tahun, dibanding langkah 3). Pemain hemat menolak tawaran kredit, jadi hasilnya hanya bergeser karena urutan event acak berubah:

| Tipe pemain | Langkah 3 | Langkah 4 |
|:--|:--|:--|
| S1 hemat | bebas finansial tahun 12,6 | tahun 12,7 |
| S1 pembeli rumah kota (Rumah Tipe 45, KPR) | tahun 23,3; bunga KPR Rp1,52 M; dilelang 10% | tahun 21,3; bunga KPR Rp0,98 M (take over); dilelang 3% |
| S1 pembeli rumah (subsidi) | tahun 12,4; dilelang 5% | tahun 12,6; dilelang 0% |
| S1 gaya hidup mewah | bangkrut 1/40, tidak pernah berutang | bangkrut 2/40; 98% menerima tawaran KTA/paylater |
| SMA gaya hidup mewah | bangkrut 22/40 | bangkrut 30/40 (KTA untuk liburan, 38% macet) |
| SMA pengutang | bangkrut 20/40 | bangkrut 22/40 |

  Take over & penanganan penagih membuat KPR lebih ringan bagi pemain yang cermat, sedangkan tawaran KTA memperparah gaya hidup boros bergaji kecil. Keduanya dievaluasi di langkah 5 (penyeimbangan).

## Properti & KPR (v1.5c langkah 3)

- **Data:** `data/properties.json`: 5 jenis (Rumah Subsidi Rp180 jt, Apartemen Studio Rp450 jt, Rumah Tipe 45 Rp900 jt, Rumah Besar Rp2,5 M, Tanah Kavling Rp300 jt) dengan `rent_yield`, `growth` (kenaikan riil per tahun), `volatility`, `maintenance`, `happiness`, `livable`/`rentable`, dan `loans` (KPR yang boleh dipakai); aturan umum: BPHTB 5% + notaris 1% saat beli, PPh final 2,5% + agen 2,5% saat jual (laku 1-3 bulan), PBB 0,2%/tahun, PPh final sewa 10%, mencari penyewa 1-2 bulan, kontrak 12 bulan (70% diperpanjang). Di `loans.json`: **KPR** (pegawai ≥12 bulan, DP min 10%, 5-20 tahun, bunga tetap BI - 0,75% selama 36 bulan lalu mengambang BI + 5,5%) dan **KPR Subsidi FLPP** (bunga tetap 5%, DP mulai 1%, gaji maksimal Rp8 jt, rumah pertama, khusus Rumah Subsidi yang wajib dihuni). Hunian sewa baru **Kontrakan** (Rp2,2 jt, kebahagiaan +1) di `economy.json`.
- **Modul** `GameState.properties` (`scripts/game/properties.gd`, kelas `Properties`). State: `owned` (`[{uid, id, since, paid, use, lease_left, vacant_left, selling_left, loan_id}]`, `use` = live/rent/empty), `index` (indeks harga riil per jenis), `uid_seq`, dan `rng` sendiri. RNG terpisah membuat permainan tanpa properti tetap identik (golden runner).
- **Harga** = harga awal x indeks harga (inflasi) x indeks properti; indeks bergerak tiap bulan secara acak di sekitar `growth`. Analogi web: harga dihitung saat dibaca (computed), hanya indeksnya yang disimpan.
- **Bulanan** (`properties.month_step()`, dipanggil paling awal di `_start_month()`): indeks bergerak, PBB & perawatan dipotong, penyewa membayar sewa (dipotong PPh), kontrak berakhir/penyewa baru, dan properti yang dijual laku (`_complete_sale()`: hasil bersih masuk kas, KPR dilunasi dengan `debt.pay_off(id, true)`). Laporan: `rent_income`, `rent_tax`, `property_cost`, `property_sold`, `property_notes`.
- **Membeli:** `properties.buy_quote(id, method, dp_ratio, tenor)` (method `cash` / `kpr` / `kpr_subsidi`) dan `properties.buy(..., use)`. Biaya beli selalu tunai; dana impian **DP Rumah** dipakai lebih dulu (impiannya ditutup tanpa hadiah). Impian DP Rumah kini `keep_funds`: saat terkumpul, dananya **kembali ke kas** untuk uang muka (tidak hangus).
- **Dihuni / disewakan:** `properties.set_use(uid, use)`. Menghuni rumah sendiri = `GameState.housing_option()` mengembalikan pilihan "Rumah sendiri" tanpa sewa (`properties.home_option()`); memilih tempat sewa di Beranda (`set_housing()`) membuat rumahnya kosong (`move_out()`).
- **KPR mengambang:** `Debt.take()` menyimpan `fixed_until` & `float_spread`; tiap bulan `debt.update_rate()` mengganti bunga setelah masa tetap menjadi suku bunga BI + spread, lalu cicilan dihitung ulang dari sisa pokok. Laporan mencatat perubahan bunga (`loan_rate_changes`). `Debt.quote()` memberi perkiraan cicilan setelah masa tetap (`payment_after`) dan total bunga (`schedule_total()` dengan pergantian bunga).
- **Kekayaan & kebebasan finansial:** kekayaan bersih menambah nilai properti; pendapatan pasif = 4% investasi + sewa bersih (`properties.rent_income()`); pengeluaran rutin, sisa modal, dan Rencana Gaji (`property` & `rent`) menghitung biaya properti dan sewa. Kebebasan finansial kini cukup `passive_income() > 0` (bisa dari sewa saja).
- **Macet:** KPR menunggak 3 bulan → `properties.seize()`: dilelang 70% harga pasar, sisa hasil lelang dikembalikan; jika rumah itu dihuni, pemain kembali menyewa.
- **UI:** kartu **Properti** di Beranda, popup **Properti** (`scenes/ui/property_popup.tscn`: `open_market()` daftar, `open_buy()` biaya & hasil, rencana pemakaian, Tunai/KPR/KPR Subsidi, DP, tenor (bawaan: terpendek yang lolos rasio cicilan), cicilan setelah masa tetap, syarat; `open_detail()` nilai, pemakaian, KPR, jual/batal jual), pilihan **Kontrakan** & keterangan rumah sendiri di Tempat Tinggal, baris sewa & biaya properti di Rencana Gaji, Beranda, dan laporan, 6 istilah glosarium, analisis akhir tentang sewa, rumah sendiri, dan lelang.
- **Save lama:** tanpa kunci properti → tanpa properti, indeks 1,0, RNG dari seed permainan.
- **Simulator:** tipe pemain **pembeli_rumah** (rumah subsidi jika memenuhi syarat, selain itu Rumah Tipe 45) dan **pembeli_rumah_kota** (langsung Rumah Tipe 45 dengan KPR DP 20%):

| Tipe pemain (Normal, 40 permainan x 30 tahun) | Bebas finansial | Kekayaan riil tahun 30 | Rumah |
|:--|:--|:--|:--|
| S1 hemat (menyewa kos) | 100%, median tahun 12,6 | Rp8,16 M | - |
| S1 pembeli rumah (rumah subsidi, KPR FLPP 5% tetap) | 98%, tahun 12,4 | Rp7,79 M | dibeli median tahun 1,5; 5% dilelang |
| S1 pembeli rumah kota (Rumah Tipe 45, KPR DP 20%) | 98%, tahun 23,3 | Rp6,57 M | dibeli median tahun 10,5; bunga KPR Rp1,52 M; 10% dilelang |
| SMA hemat | 98%, tahun 18,4 | Rp3,06 M | - |
| SMA pembeli rumah (rumah subsidi) | 98%, tahun 15,5 | Rp3,77 M | dibeli median tahun 1,2 |
| SMA pembeli rumah kota | 90%, tahun 20,4 | Rp2,98 M | hanya 18% mampu membeli (median tahun 16) |

  Rumah subsidi dengan KPR FLPP sangat menguntungkan bagi gaji kecil (seperti di dunia nyata); KPR rumah kota menunda kebebasan finansial lebih dari 10 tahun dan 10% pembelinya mengalami lelang (penyeimbangan di langkah 5).

## Kendaraan (v1.5c langkah 2)

- **Data:** `data/vehicles.json` (motor Rp28 jt & mobil Rp250 jt: `depreciation` 12%/10% per tahun, `running_cost` Rp400 rb/Rp2 jt per bulan, `happiness` +1/+2, `loan` = produk kredit, `dream` = impian yang menghasilkan kendaraan ini), `sell_ratio` 90% (dijual ke dealer), `min_value_ratio` 15%. Produk `motor_loan` (BI + 18%, DP min 20%, kerja ≥3 bulan termasuk kerja lepas) dan `car_loan` (BI + 3,5%, DP min 25%, pegawai ≥12 bulan) di `loans.json` dengan `"collateral": "vehicle"`. Impian Motor Baru & Mobil Keluarga punya `"vehicle"` di `dreams.json`.
- **Modul** `GameState.vehicles` (`scripts/game/vehicles.gd`, kelas `Vehicles`). State: `owned` = `[{id, since, paid, loan_id}]`. Nilai pasar dihitung saat dibutuhkan (`value()` = harga baru hari ini x (1 - penyusutan)^usia), jadi tidak perlu diperbarui tiap bulan. Analogi web: *computed property*, bukan kolom yang disimpan.
- **Membeli:** `vehicles.buy_quote(id, method, dp_ratio, tenor)` = satu sumber angka untuk popup dan `vehicles.buy()`. Dana impian kendaraan itu dipakai lebih dulu. Tunai → impiannya terwujud (`dreams.achieve()`, ada perayaan); kredit → `debt.take(..., collateral)` lalu uang pinjaman langsung dibayarkan ke dealer, impiannya ditutup tanpa hadiah (`dreams.close_entry()`). Impian kendaraan yang dananya penuh (`dreams.check()`) otomatis menjadi kendaraan.
- **Bulanan:** di `_start_month()` biaya rutin dipotong bersama biaya hidup (`vehicles.running_cost()`) dan kebahagiaan kendaraan ditambahkan. Laporan berisi `vehicle_cost` dan `vehicle_depreciation` (penurunan nilai bulan itu).
- **Menjual & ditarik:** `vehicles.sell()` menerima 90% nilai pasar dan melunasi kreditnya lebih dulu. Kredit kendaraan yang macet 3 bulan → `Debt._default()` memanggil `vehicles.seize()`: kendaraan dilelang 70% nilai pasar, sisa hasil lelang dikembalikan, kekurangannya dihapus.
- **Terhubung ke sistem lain:** kekayaan bersih menambah nilai kendaraan; `monthly_spending()`, `runway_months()`, dan `budget.preview_for()` (baris `vehicle`) menghitung biaya rutin; premi asuransi kendaraan & biaya perbaikan di event (`cost_vehicle`) = persen dari **nilai pasar** kendaraan utama (`vehicles.repair_base()`); syarat event `has_vehicle` = `vehicles.has_any()`. Impian kendaraan tidak bisa dipilih jika kendaraannya sudah dimiliki.
- **UI:** kartu **Kendaraan** di Beranda (kendaraan dimiliki + tombol Beli), popup **Kendaraan** (`scenes/ui/vehicle_popup.tscn`: `open_buy()` dengan biaya kepemilikan, Tunai/Kredit, uang muka, tenor (bawaan: tenor terpendek yang cicilannya lolos), rincian & syarat; `open_detail()` dengan nilai, penurunan, kredit, dan jual), baris Biaya kendaraan di Rencana Gaji, Beranda, dan laporan, petunjuk kredit di detail impian kendaraan, 3 istilah glosarium. Teks syarat pinjaman kini dipakai bersama lewat `UiText.fill_loan_requirements()`.
- **Save lama:** tanpa kunci `vehicles`, impian motor/mobil yang sudah terwujud otomatis menjadi kendaraan (karena itu `vehicles` dimuat setelah `dreams` di `GameState.modules`).
- **Penyeimbangan (hasil simulator):** event Kecelakaan di Jalan dibuat lebih jarang (bobot 2 → 1) dan lebih murah (perbaikan 6% / 2,5% dari nilai pasar, sebelumnya 15% / 6% dari harga baru). Sebelumnya klaim asuransi kendaraan mencapai 6,5x premi; kini ±57% dari premi (asuransi melindungi dari kejadian besar, bukan cara mencetak uang). Tipe pemain **pengendara** (hemat + motor kredit begitu bisa, mobil kredit saat gaji riil ≥ Rp15 jt):

| Tipe pemain (Normal, 40 permainan x 30 tahun) | Bebas finansial | Kekayaan riil tahun 30 | Kendaraan |
|:--|:--|:--|:--|
| S1 hemat (tanpa kendaraan) | 100%, median tahun 12,6 | Rp8,16 M | - |
| S1 pengendara (hemat + motor & mobil kredit) | 100%, median tahun 20,1 | Rp5,43 M | motor & mobil 100%; biaya rutin total Rp1,19 M (nominal); bunga kredit Rp58 jt |
| SMA hemat | 98%, tahun 18,4 | Rp3,06 M | - |
| SMA pengendara | 93%, tahun 21,0 | Rp2,73 M | motor 98%, mobil 38% |

## Utang & Skor Kredit (v1.5c langkah 1)

- **Data:** `data/loans.json`: batas rasio cicilan (`dsr_limit` 35%), denda tunggakan (`late_fee` 5%), batas macet (`default_after` 3 bulan), aturan skor kredit (`credit`), dan produk pinjaman (`products`; langkah 1 baru **KTA**). Kredit kendaraan & KPR akan ditambah sebagai produk baru di file yang sama.
- **Modul** `GameState.debt` (`scripts/game/debt.gd`, kelas `Debt`). State: `loans` (pinjaman aktif), `credit_score` (0-100, mulai 60), `loan_seq`. Analogi web: seperti modul tagihan langganan: tagihan ditarik otomatis tiap bulan, yang gagal menumpuk menjadi tunggakan.
- **Bunga & cicilan:** bunga per tahun = suku bunga BI saat cair + `rate_spread` produk + penyesuaian tingkat skor (`credit.grades`). Cicilan anuitas dihitung ulang tiap bulan dari sisa pokok (`Debt.payment_for()`), sehingga nanti KPR berbunga mengambang cukup mengubah `rate`. `Debt.schedule_total()` memakai hitungan yang sama untuk menampilkan total bunga sebelum mengajukan.
- **Pengajuan:** `debt.quote(product, amount, tenor)` = satu sumber angka untuk popup dan `debt.take()` (seperti endpoint "hitung total checkout"). Syarat (`debt.requirements()`): pekerjaan & lama di perusahaan, skor ≥ 40, tidak menunggak, belum punya produk yang sama, plafon 5x gaji, rasio cicilan ≤ 35% gaji bruto. Disetujui = uang langsung cair; cicilan pertama awal bulan depan.
- **Alur bulanan:** `debt.pay_installments()` dipanggil di `_start_month()` setelah gaji & biaya hidup, **sebelum** premi, uang kuliah, dan rencana gaji. Tiap pinjaman: tunggakan dulu, lalu cicilan bulan ini (kas, lalu tabungan dana darurat lewat `budget.draw_emergency()`). Gagal bayar → tunggakan + denda 5%, skor -8. Tiga bulan berturut-turut → **macet**: KTA ditagih sekaligus (`debt._default()`), kas boleh minus sehingga aset dijual paksa dan aturan bangkrut yang lama berlaku.
- **Skor kredit:** +1 per bulan saat semua cicilan lancar, -8 per cicilan menunggak, -25 saat macet (sejak langkah 5 paling tinggi 30 setelah macet), +2 saat pelunasan dipercepat; tanpa tunggakan dan di bawah 60 pulih +1 per bulan. Efek event baru `credit_score`. Status pinjaman memakai kolektibilitas OJK (`Debt.collectibility()`: Kol 1-5).
- **Kekayaan & kebebasan finansial:** `net_worth()` dikurangi `debt.outstanding()` (sisa pokok + tunggakan). `monthly_spending()`, `runway_months()`, dan `budget.preview_for()` (baris `debt`) ikut menghitung cicilan. Syarat unlock dana darurat memakai aset likuid dikurangi utang, jadi dana darurat hasil pinjaman tidak dihitung.
- **UI:** kartu **Utang & Kredit** di Beranda (skor, daftar pinjaman, tombol Ajukan pinjaman), popup **Pinjaman** (`scenes/ui/loan_popup.tscn`: `open_apply()` jumlah/tenor/rincian/syarat, `open_detail()` rincian + pelunasan dipercepat), baris Cicilan utang di Rencana Gaji & Beranda, bagian UTANG di laporan bulanan, 9 istilah glosarium baru, dan analisis akhir tentang utang.
- **Save:** kunci baru `loans`, `credit_score`, `loan_seq` memakai nilai bawaan saat tidak ada, jadi save v1.5b tetap bisa dimuat (`SAVE_VERSION` tetap 3).
- **Simulator:** tipe pemain **pengutang** (gaya hidup mewah + KTA terbesar setiap kas menipis). Hasil 40 permainan x 30 tahun (Normal):
  - Tipe pemain lama (tanpa pinjaman) menghasilkan angka yang sama persis dengan v1.5b.
  - S1: pengutang bangkrut 3/40 (gaya hidup mewah tanpa KTA 1/40); 80% pernah meminjam, 9% di antaranya macet, bunga utang median Rp9,1 jt; kekayaan riil tahun ke-5 Rp81,9 jt (tanpa KTA Rp84,8 jt).
  - SMA: pengutang bangkrut 20/40 (tanpa KTA 22/40); 88% pernah meminjam, 49% di antaranya macet, bunga utang median Rp13,1 jt; kekayaan riil tahun ke-5 -Rp9,6 jt (tanpa KTA Rp2,1 jt).
  - Kesimpulan: KTA hanya menunda masalah gaya hidup yang melebihi gaji (menambah bunga, dan bagi gaji kecil sering berakhir macet), bukan menyelamatkannya. Penyeimbangan utang dilakukan di langkah 5.
- **Perbaikan:** baris Premi asuransi dan Uang kuliah di popup Rencana Gaji sebelumnya tertimpa teks "0% · Rp0" (bug sejak v1.5a langkah 3); kini menampilkan nominalnya.

## Pekerjaan & Lowongan (v1.5b langkah 1)

- **Data:** `data/jobs.json` berisi tingkat pendidikan, aturan lowongan (`board`), batas lamaran, syarat keahlian & pengalaman per jenjang, rumus peluang (`chance`), bidang (`tracks` + nama perusahaan), dan 28 pekerjaan. Latar belakang (`economy.json` `backgrounds`) kini menentukan usia, pendidikan, keahlian awal, dan tempat tinggal; modal awal ada di `difficulties[].start_cash`.
- **State** di `GameState`: `job` (`{id, company, since}` atau `{}`), `salary` (gaji bruto pekerjaan sekarang, 0 jika belum bekerja), `education` (indeks), `skill`, `experience` (bidang -> bulan), `job_board`, `applications`, `job_offers`. `unpaid_months` = cuti tanpa gaji (pekerjaan tetap).
- **Alur bulanan** (`_start_month`): hasil lamaran bulan lalu diundi (`_resolve_applications`) -> gaji (`_monthly_pay`, kerja lepas naik-turun) -> pengalaman & keahlian (`_work_month`) -> biaya hidup dst. -> lowongan baru (`_refresh_job_board`). Tawaran dikirim lewat signal `job_offers_received` setelah laporan; `career.accept_offer()` membayar gaji pertama jika bulan ini belum ada gaji.
- **Syarat & peluang:** `career.requirements()` (untuk ✓/✗ di UI), `career.meets_requirements()`, `career.hire_chance()`; `career.apply_block_reason()` menjelaskan kenapa tombol Lamar nonaktif. Analogi web: seperti endpoint validasi yang dipakai form (tombol nonaktif + pesan) dan endpoint submit.
- **UI:** tab Aktivitas berganti nama menjadi Karier (`activity_screen.gd`: `_refresh_job`, `_refresh_board`), popup `OfferPopup`, bagian LAMARAN KERJA di laporan, chip jabatan & pendidikan di Profil.
- **Menambah pekerjaan:** cukup tambah entri di `jobs.json` (id unik, `track`, `level`, `title`, `education`, `salary`, `workload`; opsional `skill`, `volatility`). Bidang baru butuh entri di `tracks` dan ikon `assets/icons/tracks/<id>.svg` (opsional).
- **Save:** `SAVE_VERSION` 3; save v1.5a ditolak dengan pesan `SAVE_OUTDATED`.

## Tampilan & Cerita Karier (v1.5b langkah 4)

- **Perjalanan karier:** `GameState.career.history` (`{month, kind, job_id, company, program}`, maks. 60) diisi `career.record()` saat diterima kerja, promosi, PHK, berhenti, lulus, dan berhenti kuliah. Ditampilkan lewat `UiText.fill_career_log()` di Profil dan layar akhir.
- **Cerita sekali per permainan:** `GameState.story_seen` + `mark_story(key)` (berbeda dari `hints_seen` yang berlaku untuk semua permainan). Cerita "Hari Pertama" (`STORY_START_<SMA|D3|S1>`) dimunculkan `main.gd` saat bulan 0 dan belum bekerja.
- **Beranda:** kartu Karier (`_refresh_career()`), `GameState.runway_months()` untuk sisa modal, dan catatan beban kerja (`_refresh_workload()`). Signal `career_requested` -> `main._show_screen(3)`.
- **Ikon bidang:** `UiText.track_icon()` / `track_tile()` dipakai tab Karier dan Beranda. Begitu `assets/icons/tracks/<bidang>.svg` ada, ikon itu otomatis menggantikan ikon sementara.
- **Analisis akhir:** aturan karier di `EndAnalysis.insights()` (PHK, menganggur, promosi, karier mandek, kuliah).
- **Teks:** perubahan teks lama memakai skrip yang mengganti baris CSV di tempat (kunci sama), bukan menambah baris baru.

## Pendidikan & Keahlian (v1.5b langkah 3)

- **Data:** `data/education.json` berisi program kuliah (`months` per pendidikan asal, `cost` per bulan, `result`, `skill`), beban kuliah (`load`), dan syarat beasiswa kantor (`sponsor`). Nama sertifikasi per bidang ada di `jobs.json` (`tracks[].certification`, `default_certification`). Aktivitas boleh punya `cooldown_months` (Kursus Online: sekali tiap 3 bulan).
- **State** di `GameState`: `study` (`{}` atau `{id, months_left, months_total, since, scholarship, sponsor, paid_month}`). Analogi web: seperti langganan berbayar per bulan yang punya tanggal mulai, sisa periode, dan diskon.
- **Alur bulanan:** `education.study_month()` dipanggil di `_start_month()` setelah premi asuransi: lulus jika `months_left` habis (`education._graduate()`), selain itu bayar `education.tuition_fee()` (kas, lalu tabungan dana darurat lewat `budget.draw_emergency()`), kurangi `months_left`, dan catat `paid_month` (dipakai `activities.energy_max()` untuk beban energi). Uang tidak cukup = cuti sebulan.
- **Fungsi utama:** `education.available_programs()`, `education.program_option()`, `education.enroll_block_reason()`, `education.enroll()`, `education.quit_study()`, `education.tuition_fee()`, `education.graduation_month()`, `education.sponsor_program()`, `education.certification_name()`. Beasiswa kantor berakhir saat pindah atau keluar kerja (`education.check_sponsor()`).
- **Event:** kategori `education`; syarat `requires: studying | sponsor_ready`; efek `scholarship`, `sponsored_study`, `study_delay`; isian teks `{program}` dan `{cert}`.
- **Signal:** `graduated(program, result, skill_gain)` dikirim setelah laporan bulanan (antrean `_report_signals`, dulu `_dream_signals`) -> popup "Selamat Lulus!" dengan confetti.
- **UI:** kartu Pendidikan & Keahlian di tab Karier (`_refresh_education()`, `_add_study()`, `_add_program()`), konfirmasi daftar/berhenti kuliah di `main.gd` (`_confirm_enroll()`), baris Uang kuliah di Rencana Gaji, Beranda, dan laporan.
- **Simulator:** `--persona=pelajar` (hemat + kuliah + kursus) untuk membandingkan kuliah vs tidak.

## Karier: Kinerja, Promosi, PHK (v1.5b langkah 2)

- **Data:** `data/jobs.json` bagian `performance` (target & kecepatan kinerja, predikat), `merit_raise` (kenaikan prestasi Januari), `promotion` (masa jabatan, kinerja minimal, peluang, kenaikan minimal), `layoff` (peluang PHK & pesangon), `headhunter`, dan `skill_curve`. Beban kerja ada di tiap pekerjaan (`workload`); stres menganggur di `economy.json` `monthly_drift.unemployed`.
- **State** di `GameState`: `performance` (0-100), `job.hired` (mulai di perusahaan, untuk pesangon) di samping `job.since` (mulai di jabatan, untuk promosi), `pending_vars` (isian teks event yang sedang tampil).
- **Alur bulanan:** Januari: `career.index_salary()` (inflasi) lalu `career.merit_raise()` (prestasi). `career.work_month()` menggerakkan kinerja menuju `performance_factors()["target"]`. `_drift()` memakai beban kerja jabatan.
- **Event karier dijadwalkan sistem**, di luar jatah event acak (`career.scheduled_events()`): wawancara jika ada tawaran kerja berjenjang; selain itu PHK (`career.layoff_chance()`) atau promosi (`career.promotion_ready()`). Analogi web: seperti cron job terpisah dari notifikasi acak. Event berjenis ini ditandai `chain_only` di `data/events/work.json` agar tidak pernah muncul acak.
- **Isian teks event:** saat event mulai tampil, `events._vars_for()` menghitung isian (`{job}`, `{company}`, `{salary}`, `{months}`, `{severance}`, `{raise}`) dan menyimpannya di `pending_vars` (ikut save). `UiText.event_text()` mengganti isian itu di popup. Analogi web: seperti props yang dihitung server saat request lalu dikirim ke template, sehingga teks dan efeknya (mis. besar pesangon) selalu sama.
- **Antrean event:** event yang sudah tidak relevan saat gilirannya tiba (mis. event kerja setelah PHK) dilewati (`events._still_valid()`, `EventManager.requires_met()`).
- **Signal baru:** `career_changed(kind, title)` ("promoted" -> toast + tinjau rencana gaji, "laid_off"). `job_offers_received` untuk tawaran berjenjang baru dikirim setelah event wawancara diputuskan.
- **UI:** kartu Pekerjaan di tab Karier (`_add_performance()`, `_add_promotion()`, tombol Berhenti kerja -> `InfoPopup` konfirmasi dengan `ok_text` "Batal"), bagian KARIER & baris kenaikan prestasi di laporan (`MonthReport._add_career()`).
- **Menambah event kerja:** tulis di `data/events/work.json` dengan `"requires": "career"`; efek baru yang tersedia: `performance`, `promote`, `layoff`, `offer_raise`, `headhunter`.

## Penyeimbangan Karier (v1.5b langkah 5)

- **Simulator** kini punya 6 tipe pemain (tambahan **pelajar**: hemat + kuliah + kursus) dan opsi `--background=sma|d3|s1`. Ringkasan per tipe juga mencetak bulan kerja pertama, gaji riil absolut, jenjang, pendidikan, promosi, PHK, uang kuliah, dan gaji total.
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/balance/balance_sim.tscn -- --save-root=user://_sim/ --games=40 --years=30 --background=s1`
- **Kebebasan finansial** (`GameState.is_financially_free()`) memakai `monthly_spending()` = biaya hidup + premi + belanja gaya hidup rencana gaji. Analogi: target FIRE dihitung dari seluruh pengeluaran, bukan hanya sewa & makan.
- **Diubah:** kenaikan prestasi 2%/1% (`jobs.json` `merit_raise`), syarat pengalaman pelamar luar 0/12/36/60/96 (`experience_by_level`), tinggal bersama keluarga kebahagiaan -2, pemulihan dalam di `economy.json` `monthly_drift` (`deep_below` 25, `deep_recover` 4).
- **Hasil:**

| Tipe pemain (Normal, 40 permainan) | Latar S1: bebas finansial | S1: gaji riil 30 thn | Latar SMA: bebas finansial | SMA: gaji riil 30 thn |
|:--|:--|:--|:--|:--|
| Hemat & investasi rutin | 100%, median tahun 12,6 | x4,5 (jenjang 4) | 98%, tahun 18,4 | x2,7 (D3, jenjang 3) |
| Menabung saja | 100%, tahun 14,8 | x4,9 | 73%, tahun 23,6 | x2,7 |
| Gaya hidup mewah | 0% (3% bangkrut) | x5,4 | 0% (55% bangkrut) | x1,7 |
| Spekulasi | 100%, tahun 14,6 (kekayaan p10-p90 Rp2,2 M-Rp64,7 M) | x3,8 | 90%, tahun 17,3 | x2,2 |
| Pilihan acak | 50%, tahun 26,3 | x4,0 | 18%, tahun 28,5 (0 kalah karena kebahagiaan) | x2,2 |
| Pelajar (kuliah + kursus) | 100%, tahun 10,8 | x6,0 | 98%, tahun 15,8 | x7,3 (S2, jenjang 5) |

- Tingkat kesulitan (S1 hemat): bebas finansial tahun 10,6 / 12,6 / 15,5 di Santai / Normal / Sulit.
- **Catatan:** pemain bergaji tinggi yang tetap hidup sederhana masih cepat bebas finansial (S1 hemat ±usia 35). v1.5c (rumah, kendaraan, cicilan) akan menambah pengeluaran besar; ukur ulang dengan simulator setelahnya.

## Penyeimbangan & Simulator (v1.5a langkah 5)

- **Simulator** `tools/balance/balance_sim.tscn` memainkan banyak permainan tanpa UI dengan 5 tipe pemain (hemat & investasi rutin, menabung saja, gaya hidup mewah, spekulan, acak), lalu mencetak ringkasan tahun 10/20/30: kekalahan, bebas finansial, kekayaan riil (median, p10, p90), pertumbuhan gaji riil, kesehatan, kebahagiaan, pajak, premi, dan klaim. Analogi web: skrip load test yang menjalankan ribuan sesi otomatis. Folder `tools/` tidak ikut ke APK.
- **Menjalankan** (±2,5 menit untuk semua tipe):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/balance/balance_sim.tscn -- --save-root=user://_sim/ --games=40 --years=30`
  Opsi: `--persona=hemat|penabung|boros|spekulan|acak`, `--difficulty=easy|normal|hard`. Hapus folder `_sim` di `%APPDATA%\Godot\app_userdata\Cuan Quest\` setelahnya.
- **Yang diubah:** event naik gaji/promosi/tawaran kerja/kursus dikecilkan; aktivitas Kursus dibatasi 10 kali (`max_total` di `activities.json`); rutinitas kerja `monthly_drift` (kesehatan & kebahagiaan -1/bulan, pulih +2 di bawah 50) di `economy.json`; premi asuransi memakai tabungan dana darurat jika kas kurang; imbal hasil kripto diturunkan.
- **Hasil (40 permainan x 30 tahun, Normal, latar Pekerja Kantoran):**

| Tipe pemain (Normal) | Kalah | Bebas finansial | Kekayaan riil tahun 10 | Kekayaan riil tahun 30 | Gaji riil tahun 10 |
|:--|:--|:--|:--|:--|:--|
| Hemat & investasi rutin | 0% | 100%, median tahun 16,6 | Rp424 jt | Rp4,11 M | x1,95 |
| Menabung saja (tabungan) | 0% | 100%, median tahun 21,0 | Rp343 jt | Rp1,76 M | x1,95 |
| Gaya hidup mewah | 75% bangkrut | 0% | negatif | negatif | x1,17 |
| Spekulasi saham & kripto | 0% | 100%, median tahun 16,7 | Rp285 jt (p10-p90: Rp155 jt-Rp769 jt) | Rp3,67 M (Rp0,98 M-Rp14,8 M) | x1,70 |
| Pilihan acak | 0% | 13%, median tahun 29,2 | Rp304 jt | Rp1,58 M | x1,76 |

- **Target keseimbangan:** berinvestasi rutin harus jelas mengalahkan menabung saja (tahun 30: 2,3x); gaya hidup di atas kemampuan berujung bangkrut; spekulasi berhasil sangat beragam; pemain acak jarang bebas finansial; tingkat kesulitan terasa (bebas finansial pemain hemat tahun 12 / 16,6 / 18,4 di Santai / Normal / Sulit).
- **Setiap perubahan ekonomi berikutnya** (pekerjaan, utang, properti) sebaiknya diukur ulang dengan simulator ini sebelum APK dibagikan.

## Stop Loss & Take Profit (v1.5a langkah 4)

- **State:** `GameState.portfolio.orders` = `{asset_id: {"stop_loss": harga, "take_profit": harga}}` (0 = mati). Dipasang lewat `portfolio.set_order()` dari `OrderPopup` (tombol di kartu kepemilikan tab Pasar). Pilihan jarak di `economy.json` bagian `orders`.
- **Eksekusi** (`portfolio.execute_orders()` di `advance_month`, setelah `market.step()`): untuk setiap pesanan (urutan id tetap), harga harian bulan itu dicek dari hari pertama. Harga pertama yang menyentuh batas menjual semua unit lewat `portfolio.sell(..., kind, at_price)`, sehingga fee, pajak, statistik, dan riwayat transaksi sama dengan penjualan biasa. Analogi web: seperti cron job yang memproses order bersyarat terhadap data harga per hari.
- **Tanggal:** langkah harga ke-`i` (0-based) = tanggal `floor(i x 30 / langkah per bulan) + 1`, kebalikan dari `MarketAsset.price_on_day()`.
- **Laporan:** `orders` di laporan berisi yang terpicu. "Perubahan nilai" = nilai investasi sekarang + nilai jual pesanan - nilai awal; grafik harian menilai aset yang terjual dengan harga harian sampai tanggal terpicu. Pembanding "kalau tidak bertransaksi" tetap hanya untuk transaksi manual (dihitung sebelum pesanan dijalankan).
- **Catatan desain:** pesanan menjual semua unit (tidak sebagian) dan berlaku untuk semua unit, termasuk yang dibeli setelah pesanan dipasang.

## Asuransi (v1.5a langkah 3)

- **Data:** `data/insurance.json` berisi produk per kategori (`health`, `life`, `vehicle`), premi (harga awal permainan, ikut inflasi), `coverage`, `critical_payout`, `premium_rate` & `deductible` (kendaraan), serta `waiting_months`.
- **State:** `GameState.insurance.policies` = `{kategori: {"id", "since"}}`. `insurance.set_policies()` dari popup Perlindungan; ganti produk = masa tunggu ulang. `insurance.active_policy()` hanya mengembalikan polis yang sudah melewati masa tunggu.
- **Premi:** `insurance.pay_premiums()` di `_start_month` setelah gaji & biaya hidup, sebelum rencana gaji. Kas kurang = polis berhenti (`insurance_lapsed` di laporan). `budget.preview_for()` memasukkan premi sehingga "Sisa ke kas" sudah memperhitungkannya.
- **Klaim:** pilihan event dengan `"claim": "medical"` (ditanggung asuransi kesehatan) atau `"vehicle"` (asuransi kendaraan, dikurangi risiko sendiri). `insurance.cover(choice)` dipakai di `can_choose` (yang ditanggung tidak perlu dibayar dulu), `resolve_event`, dan label pilihan di popup event. Event `"critical": true` membayar uang pertanggungan asuransi jiwa.
- **Kendaraan:** sejak v1.5c langkah 2 kendaraan dikelola modul `GameState.vehicles` (lihat "Kendaraan (v1.5c langkah 2)"). Event dengan `"requires": "has_vehicle"` hanya muncul jika punya kendaraan; `"cost_vehicle": 0.06` = biaya 6% dari nilai pasar kendaraan utama; premi asuransi kendaraan = persen per tahun dari nilai pasar kendaraan.
- **Menambah event yang bisa diklaim:** beri pilihan `"claim": "medical"` atau `"vehicle"`. Teks event tidak perlu menyebut asuransi; popup menampilkan bagian yang ditanggung secara otomatis.

## Pajak & Layar Konfirmasi Transaksi (v1.5a langkah 2)

- **PPh 21** (`GameState.income_tax`, `economy.json` bagian `income_tax`): gaji sebulan disetahunkan, dikurangi PTKP (Rp54 jt, lajang), lalu tarif bertingkat 5% (s.d. Rp60 jt), 15% (s.d. Rp250 jt), 25% (s.d. Rp500 jt), 30% (s.d. Rp5 M), 35%. PTKP & batas lapisan ikut indeks harga. Contoh: gaji Rp5,5 jt kena Rp50 ribu/bulan, Rp20 jt kena Rp1,83 jt/bulan.
- **`salary` = gaji bruto.** Kas menerima gaji bersih; rencana gaji, Beranda, dan popup rencana memakai `career.net_salary()`.
- **Pajak investasi** di `assets.json`: `buy_tax` / `sell_tax` (saham: jual 0,1%; kripto: beli 0,11% + jual 0,1%). Pajak bunga deposito 20% (`interest_tax`) kini dicatat terpisah.
- **Satu sumber hitungan:** `GameState.portfolio.trade_quote(asset, beli?, jumlah)` mengembalikan fee, pajak, penalti, yang masuk/diterima, unit, untung/rugi, dan peringatan. Layar konfirmasi, `portfolio.buy()`, dan `portfolio.sell()` memakai fungsi yang sama, jadi angka di layar = angka yang dijalankan. Analogi web: endpoint "preview checkout" yang dipakai juga saat order dibuat.
- **Alur UI:** tombol Beli/Jual di tab Pasar -> `market_screen.trade_requested` -> `main` membuka `TradeConfirmPopup` -> "Ya, beli/jual" menjalankan transaksi -> `trade_done` -> pesan hasil di tab Pasar.
- **Peringatan** (`economy.json` bagian `trade_warnings`): di atas profil risiko, satu aset > 60% investasi, dana darurat belum cukup sebelum beli aset berisiko (risiko >= 3), sisa kas < biaya hidup sebulan, jual rugi, penalti deposito.
- **Laporan:** `month_costs` mengumpulkan fee & pajak transaksi (termasuk autodebet dan jual paksa) serta pajak bunga sejak laporan terakhir, lalu direset setelah laporan dibuat.
- **Migrasi database:** `SaveDb.SCHEMA_VERSION` = 2; `MIGRATIONS` berisi `ALTER TABLE transactions ADD COLUMN tax`. Database lama dimigrasi otomatis saat dibuka (seperti `php artisan migrate`), database baru langsung dibuat dengan skema terbaru.

## Penyimpanan SQLite (v1.5-0 langkah 5)

- **Plugin:** `godot-sqlite` v4.9 (GDExtension, MIT) di `addons/godot-sqlite/`. Analogi web: seperti memasang paket npm berisi *native binary*. Hanya pustaka Windows (editor) dan Android arm64 (APK) yang disimpan. Plugin ini tidak menyediakan Android 32-bit, jadi preset export kini **arm64 saja**.
- **Pembagian kerja:** `GameState` tetap store di memori dan tidak tahu soal database. `SaveManager` berperan sebagai *repository* yang memetakan `GameState.to_dict()` ke tabel, lewat `SaveDb` (pembungkus SQL). Fungsi publik `SaveManager` tidak berubah, jadi UI tidak perlu diubah.
- **Tabel** di `user://cuan_quest.db`:

| Tabel | Isi |
|:--|:--|
| `player` | Data pemain: kuis, tutorial, petunjuk (key -> JSON) |
| `games` | Riwayat permainan selesai (semua; 10 terakhir tampil di Profil) |
| `slots` | Satu baris per slot (`auto`, `slot_1..3`): versi, nama, bulan, kekayaan, dan sisa state |
| `price_daily` | Harga harian per aset, 24 bulan terakhir (`month`, `day`) |
| `price_monthly` | Harga penutupan bulanan per aset, sepanjang permainan |
| `transactions` | Riwayat transaksi per slot (200 terakhir), kunci `seq` |

- **Simpan bertahap:** `SaveManager._synced` mencatat sampai bulan dan transaksi ke berapa tiap slot sudah tersimpan. Simpan berikutnya hanya menulis data baru dan menghapus harga harian yang lewat 24 bulan. Setelah game baru atau dimuat (`GameState.run_id` berubah), slot ditulis ulang penuh sekali. Di PC: simpan bertahap ±10 ms, tulis penuh ±16 ms, muat ±20 ms.
- **Kenapa sisa state disimpan biner (`var_to_bytes`), bukan JSON:** pembaca angka teks Godot meleset 1 digit terakhir pada ±10% angka desimal, walau teksnya 17 digit. Akibatnya permainan yang dimuat bisa bercabang sedikit dari aslinya (simpanan JSON lama juga begitu). Kolom `REAL` SQLite dan format biner selalu persis, sehingga "simpan → lanjut 3 bulan" kini sama persis dengan "muat → lanjut 3 bulan".
- **Transaksi atomik:** setiap simpan dibungkus `BEGIN ... COMMIT`. Jika gagal di tengah jalan, semuanya dibatalkan (`ROLLBACK`), jadi tidak ada simpanan setengah jadi. Mode WAL mengurangi tulis ke disk (hemat baterai) dan aman bila app dimatikan Android.
- **Impor JSON lama:** saat game dibuka dan masih ada `player.json` / `saves/*.json`, isinya dipindah ke database sekali lalu file lamanya dihapus. Save versi 2 ikut pindah utuh; save versi 1 tetap ditolak (tanpa migrasi).
- **Melihat isi database:** buka `%APPDATA%\Godot\app_userdata\Cuan Quest\cuan_quest.db` dengan [DB Browser for SQLite](https://sqlitebrowser.org/) saat game tidak berjalan. Kolom `slots.state` berupa biner, sedangkan tabel lain bisa dibaca langsung.
- **Uji otomatis tanpa menyentuh data asli:** jalankan Godot dengan `-- --save-root=user://_uji/`. **Semua** perintah Godot yang menjalankan kode game, termasuk `--script`, ikut menjalankan `SaveManager`. Tanpa argumen ini, data asli di `user://` ikut terbaca dan diubah.

## Event, Kuis & Unlock (M4)

- **Antrean popup** (`main.gd`): setelah Lanjut bisa muncul beberapa popup berurutan, yaitu laporan, lalu instrumen baru, lalu event. Popup berikutnya tampil setelah yang sebelumnya ditutup. Tombol Lanjut nonaktif selama ada event yang belum diputuskan.
- **Teks event & kuis** ditulis langsung dalam bahasa Indonesia di JSON dan ditampilkan lewat `tr(teks)`. Untuk bahasa Inggris nanti, tambahkan file terjemahan dengan teks Indonesia sebagai key, tanpa perlu mengubah JSON atau kode.
- **Jatah kuis memakai jam perangkat** (`QuizManager.current_week_id()`), sehingga menekan Lanjut tidak menambah jatah. Catatan: jatah ini akan hilang saat game ditutup, sampai fitur save/load selesai di M5.
- **Tips testing unlock:** turunkan angka `min` di `data/unlocks.json` (misalnya `50000000` menjadi `5000000`) agar tahap saham dan kripto cepat terbuka. Jangan lupa kembalikan angkanya.

## Simpan & Muat (M5)

- **Alur layar:** `title.tscn` -> `new_game.tscn` -> `tutorial.tscn` (hanya jika belum pernah) -> `main.tscn`. Perpindahan memakai `get_tree().change_scene_to_file()`, sedangkan autoload (`GameState` dkk.) tetap hidup.
- **Dua jenis data:**
  - *Slot save* (`auto`, `slot_1..3`): state satu permainan, hasil `GameState.to_dict()`.
  - *Data pemain*: jatah kuis, status tutorial, dan petunjuk yang sudah dilihat. Dipisah agar membuat save baru tidak mereset jatah kuis mingguan.
  - Sejak v1.5-0 langkah 5 keduanya disimpan di database SQLite `user://cuan_quest.db` (lihat bagian Penyimpanan SQLite); sebelumnya berupa file JSON.
- **Kapan tersimpan otomatis:** setiap akhir bulan, setiap event diputuskan, serta saat aplikasi di-pause (Android) atau ditutup.
- **Lokasi file di PC:** `%APPDATA%\Godot\app_userdata\Cuan Quest\`. Hapus `cuan_quest.db` (atau Profil -> Reset Data) untuk mulai dari nol.
- **Pelajaran dari bug:** urutan key `Dictionary` bisa berubah setelah melewati JSON. Loop yang mengambil angka acak harus memakai urutan tetap (lihat `Market._factor_order()`), kalau tidak hasil simulasi setelah load akan berbeda. Hal yang sama berlaku untuk RNG state 64-bit, yang disimpan sebagai string karena angka JSON hanya presisi 53-bit.
- **Menjalankan scene utama langsung (F6)** tetap bisa: `main.gd` otomatis membuat game baru dengan profil default.

## Menang, Kalah & Pengaturan (M6)

**Kondisi akhir** (angka di `data/economy.json` bagian `end`):

| Hasil | Syarat | Catatan |
|---|---|---|
| Menang: Miliarder | Kekayaan bersih >= Rp1 miliar | Pemain boleh lanjut bermain |
| Menang: Bebas finansial | Investasi x 4% / 12 >= biaya hidup bulanan (aturan 4%) | Pemain boleh lanjut bermain |
| Pensiun | Usia 60 | Selesai, dengan skor warisan |
| Kalah: Bangkrut | Kas minus 3 bulan berturut-turut | Sebelumnya aset dijual paksa, mulai dari risiko terendah |
| Kalah: Kesehatan/Kebahagiaan | Bernilai 0 selama 3 bulan berturut-turut | Ada peringatan merah di laporan bulanan |

- **Game over** menghapus simpanan otomatis dan mencatat hasilnya di *Riwayat Permainan* (tabel `games`). Slot manual tetap ada, sehingga pemain bisa memuat ulang ke titik sebelumnya.
- **Analisis akhir** (`EndAnalysis`) dibuat berbasis aturan dari statistik selama bermain, misalnya rugi karena penipuan, panik jual, uang menganggur, gaya hidup mewah, biaya transaksi, dan konsentrasi aset.
- **Efek suara** (`Sfx`) dibangkitkan dari gelombang sinus, tanpa file audio. Semua tombol otomatis berbunyi lewat signal `SceneTree.node_added`. Musik belum ada, karena butuh aset audio.
- **Bahasa Inggris** baru mencakup tampilan; isi event/kuis/glosarium masih Bahasa Indonesia.
- **Kebijakan privasi** untuk Play Store ada di `docs/kebijakan-privasi.md` (diperbarui di penutup v1.5, termasuk catatan formulir *Data safety*: tidak ada data yang dikumpulkan). Isi `[EMAIL KONTAK]` & `[NAMA PENGEMBANG]` (dan `[EMAIL KONTAK]` di `data/legal.json`), lalu unggah ke URL publik.

## Energi, Lompat Waktu & Portofolio (M6.5)

- **Energi:** 3 per bulan, +1 jika kesehatan >= 70, -1 jika < 30. Kapasitasnya dikunci di awal bulan; energi yang tidak terpakai hangus. Aktivitas ada di `data/activities.json` dan memakai format efek yang sama dengan event.
- **Lompat waktu** (`GameState.fast_forward`): maju hingga 6/12 bulan, tapi **berhenti otomatis** saat ada event, peringatan bahaya, penjualan paksa, instrumen baru terbuka, target tercapai, atau game berakhir. Laporan semua bulan digabung menjadi satu. Selama lompat waktu, peluang event dikali `fast_forward_event_mult` (0,15) di `economy.json`, agar lompatan tidak terus terpotong (rata-rata sekitar 5-6 bulan per tekan; THR setiap April selalu menghentikan lompatan).
- **Signal yang ditunda:** selama lompat waktu, signal seperti `event_triggered` disimpan dulu (`_emit_later`), lalu dikirim setelah laporan gabungan. Dengan begitu urutan popup tetap sama: laporan, lalu unlock/event.
- **Riwayat transaksi** menyimpan 200 transaksi terakhir (beli, jual, jual paksa, panik jual) beserta untung/rugi terealisasi.
- **Profil risiko:** skor kuesioner 0-6 dipetakan ke Konservatif/Moderat/Agresif. Detail aset di Pasar menampilkan peringatan jika risikonya di atas profil. Profil bisa diubah di tab Profil.

## Latihan M6.5 (opsional)

1. Tambah aktivitas baru di `data/activities.json`, misalnya "Masak di rumah" (energi 1, kebahagiaan +2).
2. Ubah `fast_forward_event_mult` menjadi `1.0`, lalu bandingkan seberapa sering tombol "+1 Thn" berhenti.
3. Ubah `base_energy` menjadi `5`, lalu rasakan bedanya pada pilihan aktivitas tiap bulan.

## Latihan M6 (opsional)

1. Ubah `win_net_worth` di `data/economy.json` menjadi `100000000`, lalu coba capai kemenangan pertama dengan cepat.
2. Tambah aturan analisis baru di `scripts/ui/end_analysis.gd`, misalnya pujian jika pemain tidak pernah tertipu (`scam_loss == 0`) setelah 2 tahun.
3. Ganti nada suara di `scripts/autoload/sfx.gd` (fungsi `_tone`), misalnya buat bunyi "coin" yang lebih tinggi.

## Latihan M5 (opsional)

1. Tambah latar belakang baru, misalnya `"pns"` (gaji stabil, volatilitas 0) di `data/economy.json`. Tombolnya otomatis muncul di layar Buat Karakter.
2. Buka file `auto.json` di folder save dengan VS Code, lihat strukturnya, lalu bandingkan dengan `GameState.to_dict()`.
3. Tambah istilah baru di `data/glossary.json` dan coba cari di popup glosarium.

## Latihan M4 (opsional)

1. Tulis event baru di `data/events/finance.json` (panduan lengkap: `docs/PANDUAN_EVENT.md`): salin event `found_money`, ganti `id`, judul, dan efeknya. Coba pakai `outcomes` agar hasilnya acak.
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

