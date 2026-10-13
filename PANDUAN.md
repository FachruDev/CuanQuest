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
  legal.json                  Kebijakan privasi & syarat penggunaan (tampil di game)
  activities.json             6 aktivitas bulanan & aturan energi
  risk_profile.json           Kuesioner & 3 profil risiko
  unlocks.json                Syarat membuka tiap tahap instrumen
localization/strings.csv      Semua teks UI (kolom id & en)
theme/main_theme.tres         Font global, warna tombol aktif, panel, progress bar
scripts/
  autoload/game_state.gd      STATE GLOBAL: kas, bulan, kondisi, portofolio, loop bulanan, XP, unlock, event
  autoload/ad_service.gd      Iklan rewarded (STUB, nanti diganti AdMob dengan interface sama)
  autoload/settings.gd        Pengaturan perangkat (user://settings.cfg)
  autoload/save_manager.gd    Simpan/muat file JSON di user:// + simpan otomatis
  autoload/sfx.gd             Efek suara buatan kode + getar
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
| 10 | Kuis 3 per minggu + iklan rewarded (minimal 30 soal) | M4 | ✅ 39 soal; iklan masih stub (AdMob di M7) |
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
- [ ] **v1.5-0 langkah 1: Prototipe waktu** (`prototypes/`, lihat bagian di bawah). A (per jam), B (hari cepat), dan C (sesi pasar, arah yang dipilih) selesai, menunggu uji C
- [ ] **v1.5-0 langkah 2: Sistem waktu hybrid di game utama** (+ Event Director, rebalancing, SQLite, kuis 6/minggu tanpa iklan)
- [ ] **v1.5a/b/c, v2a/b/c** (lihat `MVP_Baru_Sistem_Waktu_Hybrid.md`)
- [ ] **M7: Export rilis & Play Store** (setelah v2 selesai; tanpa monetisasi)

## Prototipe Waktu (v1.5-0 langkah 1)

Dua prototipe terpisah di `prototypes/` untuk memilih cara waktu berjalan sebelum game utama dirombak. Tidak memakai `GameState`/`SaveManager`; simpanannya ada di `user://prototype/`.

- **A: Waktu per Jam** (`prototypes/time/`): 1 jam game = 2,5 detik, jam bursa, antrean pesanan, tidur & begadang.
- **B: Hari Cepat** (`prototypes/day/`): 1 hari sekitar 1 detik, berhenti otomatis saat ada keputusan, plus aktivitas berdurasi, misi bulanan, kesehatan & kebahagiaan, dan reaksi saat harga bergerak besar. Dibuat karena di A pemain sering hanya menunggu gajian/akhir bulan.
- **C: Sesi Pasar** (`prototypes/session/`, arah yang dipilih setelah A & B terasa kurang seru): hidup tetap per bulan lewat tombol manual seperti v1, tetapi di dalam bulan grafik berjalan sendiri selama satu sesi (120 pergerakan, sekitar 90 detik pada 1x). Pemain trading langsung dengan tombol cepat, ada berita kilat (70% kabar asli yang berlanjut, 30% rumor yang berbalik), event hidup di tengah sesi, dan laporan yang membandingkan hasil trading dengan "kalau hanya ditahan".

**Kenapa sesi C punya panjang tetap:** kalau grafik berjalan tanpa batas selama pemain belum menekan Lanjut, pemain bisa menunggu harga naik terus tanpa membayar tagihan. Dengan 120 pergerakan per bulan, menekan Lanjut lebih awal menghitung sisa pergerakan secara instan, dan hasil akhirnya sama persis dengan menonton sampai habis (dicek di `test_session.gd`). `dt` per tick = 1/(120 x 12) = 1/1.440.

**Cara menjalankan:**
- Di editor: buka `prototypes/launcher.tscn` (atau langsung `time/time_proto.tscn` / `day/day_proto.tscn`), lalu tekan **F6** (Run Current Scene).
- Di HP: pasang `build/cuan-quest-proto-waktu.apk` (preset "Android Prototipe Waktu"). Aplikasinya bernama *Cuan Proto Waktu*, membuka menu pilihan C/B/A, dan bisa terpasang berdampingan dengan game utama.
- Uji otomatis: `godot --headless --path . --script res://prototypes/time/test_proto.gd` (juga `day/test_day.gd` dan `session/test_session.gd`)

Prototipe B memakai ulang `GameClock`, `ProtoDirector`, `ProtoMetrics`, dan `ProtoDialog` dari A. Langkah waktunya 6 jam (pagi, siang, sore, malam = warna latar), pasarnya bergerak sekali sehari (`day_market.gd`, `dt` = 1/257 untuk saham dan 1/360 untuk kripto), dan isinya ada di `day_world.gd` + `day_config.json`.

| File | Isi |
|---|---|
| `time_config.json` | Semua angka: skala waktu, jam bangun/pingsan, energi, kalender, gaji, pasar, distribusi event |
| `game_clock.gd` | Jam game (menit sejak hari ke-0), kalender 30 hari, jeda, kecepatan, *fixed timestep* |
| `proto_market.gd` | 1 saham (jam bursa + gap saat buka) dan 1 kripto (24/7), harga per jam, berita intraday |
| `proto_director.gd` | Event Director mini: 0-3 event per bulan, jadwal di jam bangun, jarak minimal 4 hari |
| `proto_world.gd` | Simulasi: kas, energi, tidur, pingsan, lompat waktu, antrean pesanan, laporan, simpan/muat |
| `proto_metrics.gd` | Pengukur uji (waktu per kecepatan, jeda, transaksi, tidur, lompatan), bisa disalin |
| `time_proto.gd/.tscn`, `proto_dialog.gd` | Tampilan prototipe dan popup |

**Konsep penting:**
- **Fixed timestep.** `GameClock.consume(delta)` mengumpulkan detik nyata lalu mengubahnya menjadi langkah 15 menit game. Mirip `setInterval` yang mengejar waktu tertinggal, tetapi angka acak hanya diambil per langkah, sehingga hasil simulasi sama di HP lambat maupun cepat.
- **Jeda dengan alasan.** Jeda disimpan sebagai kumpulan alasan (`manual`, `popup`, `idle`, `background`). Jam baru berjalan setelah semua alasan dilepas, mirip *reference counting*. Dengan begitu menutup popup tidak menjalankan waktu jika pemain sebelumnya menekan Jeda.
- **`dt` per instrumen** (MVP bagian 5.1). Saham hanya bergerak 7 jam per hari kerja, sehingga `dt = 1/1.799`; kripto `1/8.640`. Sebanyak 18% variasi saham dialokasikan ke langkah *gap* saat bursa buka. Uji otomatis memastikan drift dan volatilitas tahunan tetap sesuai `data/assets.json`.
- **Tidur dan lompat waktu = simulasi batch.** Semua langkah yang dilewati dihitung dalam satu frame tanpa menggambar grafik, lalu UI diperbarui sekali. Lompatan berhenti saat ada event atau laporan.
- **Hemat baterai.** `OS.low_processor_usage_mode = true` (layar hanya digambar ulang bila ada perubahan), `Engine.max_fps = 30`, UI diperbarui hanya saat waktu maju, dan tidak ada pembaruan sama sekali saat jeda.
- **Feature tag.** Preset ekspor prototipe memberi fitur kustom `prototipe`, dan `project.godot` berisi `run/main_scene.prototipe`. Analogi web: seperti variabel `.env` per build, sehingga satu project menghasilkan dua APK dengan scene awal berbeda.

**Panduan untuk penguji** ada di `prototypes/README.md`.

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

## Menang, Kalah & Pengaturan (M6)

**Kondisi akhir** (angka di `data/economy.json` bagian `end`):

| Hasil | Syarat | Catatan |
|---|---|---|
| Menang: Miliarder | Kekayaan bersih >= Rp1 miliar | Pemain boleh lanjut bermain |
| Menang: Bebas finansial | Investasi x 4% / 12 >= biaya hidup bulanan (aturan 4%) | Pemain boleh lanjut bermain |
| Pensiun | Usia 60 | Selesai, dengan skor warisan |
| Kalah: Bangkrut | Kas minus 3 bulan berturut-turut | Sebelumnya aset dijual paksa, mulai dari risiko terendah |
| Kalah: Kesehatan/Kebahagiaan | Bernilai 0 selama 3 bulan berturut-turut | Ada peringatan merah di laporan bulanan |

- **Game over** menghapus simpanan otomatis dan mencatat hasilnya di *Riwayat Permainan* (`player.json`). Slot manual tetap ada, sehingga pemain bisa memuat ulang ke titik sebelumnya.
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

