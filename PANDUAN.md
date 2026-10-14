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
  assets.json                 Parameter aset (drift, volatilitas, fee)
  economy.json                Gaji, modal awal, pilihan makan & tempat tinggal (untuk balancing)
  market.json                 Siklus pasar, suku bunga acuan, peluang berita
  news.json                   Template berita pasar & dampaknya ke harga
  events.json                 33 event hidup: syarat muncul, pilihan, efek
  quiz.json                   39 soal kuis (4 topik)
  glossary.json               31 istilah glosarium
  legal.json                  Kebijakan privasi & syarat penggunaan (tampil di game)
  activities.json             6 aktivitas bulanan & aturan energi
  risk_profile.json           Kuesioner & 3 profil risiko
  unlocks.json                Syarat membuka tiap tahap instrumen
localization/strings.csv      Semua teks UI (kolom id & en)
addons/godot-sqlite/          Plugin SQLite (GDExtension, MIT): pustaka Windows + Android arm64
theme/main_theme.tres         Font global, warna tombol aktif, panel, progress bar
scripts/
  autoload/game_state.gd      STATE GLOBAL: kas, bulan, kondisi, portofolio, loop bulanan, XP, unlock, event
  autoload/ad_service.gd      Iklan rewarded (STUB, nanti diganti AdMob dengan interface sama)
  autoload/settings.gd        Pengaturan perangkat (user://settings.cfg)
  autoload/save_manager.gd    Simpan/muat ke database SQLite (user://cuan_quest.db) + simpan otomatis
  autoload/sfx.gd             Efek suara buatan kode + getar
  core/                       Logika murni tanpa UI (mudah dites)
    market.gd, market_asset.gd   Simulasi pasar (GBM, RNG ber-seed)
    fmt.gd                    Format Rp1.234.567, +2,35%, tanggal game
    data_loader.gd            Baca JSON
    quiz_manager.gd           Bank soal + jatah mingguan (waktu nyata) + kredit iklan
    event_manager.gd          Pemilihan event berdasarkan syarat & bobot
    save_db.gd                Pembungkus tipis SQLite: query, insert banyak baris, transaksi, skema
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
  end_screen.tscn             Layar akhir (hasil, statistik, analisis)
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
- [ ] **v1.5a/b/c, v2a/b/c/d** (lihat `MVP_Cuan_Quest_Revisi3.md`)

Rangkuman semua checklist MVP (v1, v1.5, v2, M7) ada di [docs/CHECKLIST_MVP.md](docs/CHECKLIST_MVP.md).
- [ ] **M7: Export rilis & Play Store** (setelah v2 selesai; tanpa monetisasi)

## Prototipe Waktu (diarsipkan)

Tiga prototipe sistem waktu (A: per jam, B: hari cepat, C: sesi pasar) sudah dicoba dan **tidak dipakai**: waktu yang berjalan sendiri terasa membosankan atau lag. Kodenya disimpan di cabang git `archive/prototipe-waktu` (`git switch archive/prototipe-waktu` untuk melihatnya). Kesimpulan dan arah baru ada di dokumen `MVP_Cuan_Quest_Revisi3.md`: giliran tetap bulanan, tetapi setiap bulan dibuat lebih hidup.

## Cara Kerja Simulasi Pasar (M3)

Setiap bulan `Market.step()` menjalankan (sejak v1.5-0 harga bergerak **harian**, lihat bagian berikutnya):
1. **Siklus pasar.** Saham dan kripto masing-masing berada di fase *bull*, *sideways*, atau *bear* selama beberapa bulan acak. Saat fase berganti, muncul berita "Analis: ...".
2. **Berita** (peluang 50%). Satu template dipilih dari `news.json` berdasarkan bobot, lalu memberi guncangan harga ke satu aset, satu kelas aset, atau suku bunga.
3. **Harga baru:** `harga × exp(drift_bulanan − ½σ² + σ·z) × (1 + guncangan)`, dengan `z = rho·z_pasar + √(1−rho²)·z_acak`. Bagian `z_pasar` yang sama untuk semua aset membuat saham cenderung naik-turun bersamaan (korelasi).
4. **Tabungan & deposito** tidak bergerak harganya. Bunganya (`suku bunga acuan + spread`, dipotong pajak) dibayar di `GameState._pay_interest()`.

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

- **Rencana dalam persen gaji** (`GameState.plan`): gaya hidup, dana darurat, dan investasi otomatis per aset. Karena berupa persen, rencana otomatis menyesuaikan saat gaji naik, turun, atau saat menganggur (gaji 0 berarti tidak ada yang dibagi).
- **Satu sumber hitungan:** `GameState.plan_preview(plan, penghasilan)` dipakai popup Rencana Gaji, kartu Beranda, dan eksekusi di awal bulan, sehingga angka yang dilihat pemain selalu sama dengan yang dijalankan.
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
- **Target bulanan** (`GameState.targets`): 2 target acak per bulan dari daftar yang masuk akal (investasi manual, aktivitas tertentu, kas akhir bulan, naikkan kesehatan/kebahagiaan, kuis benar, setor ke impian, tidak menjual rugi). Hadiah kecil, gagal tidak dihukum. Target "akhir bulan" dinilai di `_finalize_targets()` saat Lanjut ditekan.
- **Pembanding "kalau tidak bertransaksi":** portofolio dicatat di awal giliran (`_snapshot_turn`); saat Lanjut, selisihnya = (perubahan unit x pergerakan harga bulan itu) - fee. Autodebet tidak dihitung sebagai transaksi manual.
- **Perayaan & umpan balik:** `Confetti.burst()` (digambar lewat kode) untuk impian terwujud, tahap baru, dan target kemenangan; notifikasi singkat (toast) untuk target selesai dan naik level; kartu progres impian di sorotan laporan bulanan.
- **Urutan popup:** sinyal impian dikirim setelah laporan (`_flush_dream_signals`), sehingga urutannya laporan → perayaan/tenggat → tahap baru → event.

## Event Director & Kuis Tanpa Iklan (v1.5-0 langkah 4)

- **Jumlah event per bulan** diambil dari `difficulties[].event_counts` di `economy.json` (bobot untuk 0/1/2/3 event; Normal 15/40/30/15). Setelah 2 bulan tanpa event acak, bulan berikutnya memakai `quiet_counts` sehingga pasti ada kejadian.
- **Urutan per bulan** (`GameState._roll_events`): event kalender (mis. THR, `guaranteed`) → event lanjutan yang jatuh tempo (`chain_events`) → event acak. Event kalender & lanjutan tidak mengurangi jatah acak.
- **Diputuskan satu per satu:** event pertama jadi `pending_event`, sisanya di `event_queue`. Setelah satu diputuskan, `_next_queued_event()` memunculkan berikutnya. Tombol Lanjut terkunci sampai semua selesai.
- **Konteks:** `event_context()` menghitung kondisi pemain (kas berlebih/tipis, kesehatan/kebahagiaan rendah, memegang saham/kripto). Event dengan tag `"context"` di `events.json` bobotnya dikali saat kondisinya aktif, mis. investasi bodong ×3 saat kas berlebih, pinjol ×4 saat kas tipis.
- **Anti-sial beruntun:** setelah event buruk, bobot event buruk berikutnya dikali `bad_after_bad` (0,5).
- **Rantai event:** efek `"chain": {"event": id, "months": [min, max]}` menjadwalkan event lanjutan (`chain_only: true`, tidak pernah muncul acak). Contoh: pinjaman teman → Janji Temanmu; investasi bodong → Pengelola Kabur; pinjol → Penagih Pinjol.
- **Hasil simulasi** (20 permainan x 10 tahun, pilihan acak): sebaran 15/41/30/13%, rata-rata 1,42 event/bulan (sebelumnya 0,61). Karena event positif seperti kenaikan gaji ikut lebih sering, median gaji akhir naik dari Rp9,4 jt ke Rp13,4 jt dan median kekayaan dari Rp402 jt ke Rp558 jt. Perlu ditinjau saat penyeimbangan (inflasi v1.5a akan menekannya).
- **Kuis:** 6 soal per minggu nyata, tanpa iklan. Setiap soal yang dibuka memakai jatah; soal yang sudah muncul minggu ini tidak diulang di minggu yang sama (`QuizManager.shown_this_week`).
- **Iklan dilepas dari UI:** tombol "Tonton iklan" dihapus. `AdService` masih terdaftar sebagai autoload tetapi tidak dipanggil (disimpan untuk v3). Kebijakan privasi kini menyatakan game tanpa iklan.

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
- **Kebijakan privasi** untuk Play Store ada di `docs/kebijakan-privasi.md`. Isi `[EMAIL KONTAK]` & `[NAMA PENGEMBANG]` (juga di `data/legal.json`), lalu unggah ke URL publik.

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

