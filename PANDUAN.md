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

## Struktur Project

```
data/assets.json              Konten aset (parameter drift, volatilitas, fee)
localization/strings.csv      Semua teks UI (kolom id & en)
scripts/autoload/game_state.gd   STATE GLOBAL: kas, bulan, portofolio, beli/jual
scripts/core/market.gd        Simulasi pasar (RNG ber-seed)
scripts/core/market_asset.gd  Satu aset + rumus pergerakan harga (GDD 8.3)
scripts/core/fmt.gd           Format Rp1.234.567 dan +2,35%
scripts/ui/main.gd            Layar utama (membaca GameState, render ulang)
scripts/ui/price_chart.gd     Grafik garis yang digambar manual (_draw)
scenes/main.tscn              Susunan node layar utama
theme/main_theme.tres         Ukuran font global
```

**Alur data (satu arah, seperti Redux):**
`Tombol ditekan → main.gd memanggil GameState.buy() → GameState mengubah data → signal "changed" → main.gd._refresh() menggambar ulang`

## Cara Menjalankan

1. Buka Godot, lalu **Import** folder `cuan-quest` (atau pilih dari daftar project).
2. Tekan **F5** (Run Project). Jendela akan tampil berukuran 405×720 (simulasi HP portrait).
3. Untuk melihat struktur layar, buka `scenes/main.tscn` dan lihat panel **Scene** di kiri atas.

## Milestone

- [x] **M1: Prototipe.** 1 aset, grafik, beli/jual + fee, saldo, tombol Lanjut
- [ ] **M2: Loop bulanan.** Gaji, biaya hidup (makan & sewa), ringkasan bulan, navigasi bawah
- [ ] **M3: Pasar.** Tabungan, deposito, reksa dana, saham, kripto, serta siklus bull/bear dan berita
- [ ] **M4: Event hidup, kuis (3/minggu nyata + stub iklan), sistem unlock**
- [ ] **M5: Save/load, onboarding & tutorial, profil, pengaturan, menang/kalah**
- [ ] **M6: Export Android, playtest, balancing**

## Latihan M1 (opsional, untuk membiasakan diri)

1. Ubah `volatility` NUSA di `data/assets.json` menjadi `0.8`, jalankan, lalu lihat grafiknya menjadi lebih liar.
2. Tambah tombol "10%" di `QuickRow`: duplikat node `Quick25` (Ctrl+D), ganti namanya, lalu tambahkan ke array di `main.gd`.
3. Ganti teks tombol Lanjut di `localization/strings.csv`. Godot otomatis re-import CSV saat editor fokus.
