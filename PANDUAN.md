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
localization/strings.csv      Semua teks UI (kolom id & en)
theme/main_theme.tres         Font global, warna tombol aktif, panel, progress bar
scripts/
  autoload/game_state.gd      STATE GLOBAL: kas, bulan, kondisi, portofolio, loop bulanan
  core/                       Logika murni tanpa UI (mudah dites)
    market.gd, market_asset.gd   Simulasi pasar (GBM, RNG ber-seed)
    fmt.gd                    Format Rp1.234.567, +2,35%, tanggal game
    data_loader.gd            Baca JSON
  ui/
    main.gd                   Shell: top bar, router tab, tombol Lanjut, popup
    price_chart.gd            Grafik garis (dipakai di Pasar & Portofolio)
    month_report.gd           Pembuat baris laporan (dipakai di popup & Portofolio)
    month_summary_popup.gd    Modal laporan bulanan
    screens/                  Satu script per tab
scenes/
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
| 1 | Profil karakter dan pilihan kesulitan | M5 | ⬜ |
| 2 | Tutorial singkat dan glosarium | M5 | ⬜ |
| 3 | Loop bulanan dengan tombol Lanjut | M2 | ✅ |
| 4 | Gaji dan biaya hidup (makan, sewa) | M2 | ✅ |
| 5 | Tabungan, deposito, reksa dana, saham, kripto | M3 | ⬜ |
| 6 | Dashboard dengan grafik harga dan tombol beli/jual | M1 + M3 | 🟨 1 aset; daftar aset di M3 |
| 7 | Portofolio dasar dan ringkasan bulanan | M2 | ✅ |
| 8 | Simulasi harga dengan siklus pasar sederhana | M3 | 🟨 GBM ada; siklus bull/bear di M3 |
| 9 | Event hidup (minimal 30 event) | M4 | ⬜ |
| 10 | Kuis 3 per minggu + iklan rewarded (minimal 30 soal) | M4 | ⬜ |
| 11 | Sistem unlock instrumen | M4 | ⬜ |
| 12 | Kondisi menang dan kalah serta layar akhir | M6 | ⬜ |
| 13 | Save/load otomatis dan manual | M5 | ⬜ |
| 14 | Pengaturan dan halaman profil | M6 | ⬜ |
| 15 | Disclaimer simulasi dan kebijakan privasi | M6 | 🟨 disclaimer ada; kebijakan privasi di M6 |

## Milestone

- [x] **M1: Prototipe.** 1 aset, grafik, beli/jual + fee, saldo, tombol Lanjut
- [x] **M2: Loop bulanan.** Gaji, biaya hidup, kesehatan/kebahagiaan, laporan bulanan, tab Portofolio, navigasi bawah
- [ ] **M3: Pasar lengkap.** 5 kelas instrumen, daftar aset, siklus bull/bear, berita pasar, bunga deposito
- [ ] **M4: Event hidup (30+), kuis (30+ soal, 3/minggu nyata + stub iklan), sistem unlock**
- [ ] **M5: Save/load, layar judul, onboarding (profil, kesulitan), tutorial & glosarium**
- [ ] **M6: Menang/kalah + layar akhir, profil & pengaturan, kebijakan privasi**
- [ ] **M7: Export Android, playtest, balancing**

## Latihan M2 (opsional)

1. **Balancing:** ubah `salary` di `data/economy.json` menjadi `4000000`, lalu lihat bagaimana sisa uang bulanan menjadi minus jika memilih Mewah + Apartemen.
2. **Tambah pilihan:** tambahkan opsi makan `"homecook"` (masak sendiri) di `economy.json` beserta key terjemahannya di CSV. Tombolnya akan muncul otomatis karena dibuat dari data.
3. **Eksplorasi editor:** buka `scenes/main.tscn` dan klik node `MarketScreen`. Ikon "film" menandakan node itu instance dari scene lain. Klik ikon tersebut untuk membuka scene aslinya.

