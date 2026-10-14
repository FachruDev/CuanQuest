# Checklist MVP Cuan Quest

Rangkuman semua checklist dalam satu tempat. Diperbarui setiap kali satu langkah selesai.

- **Terakhir diperbarui:** 14 Oktober 2026 (v1.5a langkah 4 selesai)
- **Sumber:** GDD bagian 11 (v1) dan `MVP_Cuan_Quest_Revisi3.md` (v1.5, v2, M7)
- **Tanda:** ✅ selesai · 🔄 sebagian · ⬜ belum

## Ringkasan Progres

| Tahap | Isi | Status |
|:--|:--|:--|
| **v1** (M1-M6.5) | Game dasar, 15 item GDD bagian 11 | ✅ 15/15 |
| **UI "Senja Cuan"** | Redesain seluruh tampilan | ✅ |
| **Prototipe waktu A/B/C** | Uji sistem waktu berjalan (tidak dipakai, diarsipkan) | ✅ |
| **v1.5-0** | Giliran Bulanan yang Hidup | 🔄 5/5 langkah; tinggal playtest |
| **v1.5a** | Realisme ekonomi | 🔄 4/5 langkah |
| **v1.5b** | Utang, properti, hunian yang tumbuh | ⬜ |
| **v1.5c** | Karier, tokoh, konten | ⬜ |
| **v2a-v2d** | Instrumen lanjut, hidup penuh, dana investor, mini-game | ⬜ |
| **M7** | Rilis Play Store (setelah v2) | ⬜ |

---

## v1: Game Dasar (GDD bagian 11)

| # | Item | Milestone | Status |
|:--|:--|:--|:--|
| 1 | Profil karakter dan pilihan kesulitan | M5 | ✅ |
| 2 | Tutorial singkat dan glosarium | M5 | ✅ |
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
| 15 | Disclaimer simulasi dan kebijakan privasi | M6 | ✅ (isi `[EMAIL KONTAK]` sebelum rilis) |

Tambahan di M6.5 (semua ✅): energi & 6 aktivitas bulanan, riwayat transaksi, periode grafik, grafik alokasi aset, peringatan konsentrasi, profil risiko.

---

## v1.5-0: Giliran Bulanan yang Hidup

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Pasar harian + animasi pergantian bulan | ✅ |
| 2 | Rencana gaji + autodebet; hapus tombol +6 Bln / +1 Thn | ✅ |
| 3 | Impian + target bulanan + perayaan | ✅ |
| 4 | Event Director + kuis 6 soal/minggu tanpa iklan + lepas iklan | ✅ |
| 5 | Penyimpanan SQLite | ✅ |

### Rincian fitur

**Langkah 1: Pasar harian & animasi** ✅
- ✅ Harga bergerak harian (21 hari bursa untuk saham/reksa dana, 30 hari untuk kripto); kalibrasi tahunan sama dengan v1
- ✅ Berita pasar jatuh pada tanggal tertentu (lonjakan terlihat di grafik)
- ✅ Riwayat bertingkat: harian 24 bulan terakhir + penutupan bulanan sepanjang permainan
- ✅ Grafik Pasar: periode 1B / 3B / 1T / Semua
- ✅ Laporan bulanan: grafik kekayaan harian digambar mulus, angka kekayaan berputar, kartu aset yang paling bergerak; ketuk untuk melewati
- ✅ Save versi 2; save lama ditolak dengan pesan jelas; data pemain (kuis, tutorial) tetap aman

**Langkah 2: Rencana gaji & autodebet** ✅
- ✅ Rencana dalam persen gaji: gaya hidup, dana darurat, investasi otomatis per aset
- ✅ Gaya hidup memengaruhi kebahagiaan (0% = -2, 5% = 0, 10% = +1, 20% = +2, 30% = +3)
- ✅ Dana darurat otomatis ke Tabungan sampai 6 bulan pengeluaran pokok
- ✅ Autodebet tiap awal bulan; pos yang kasnya kurang dilewati dan dicatat di laporan
- ✅ Popup muncul di bulan pertama, saat gaji berubah, atau dari Beranda
- ✅ Tombol +6 Bln / +1 Thn dihapus

**Langkah 3: Impian, target, perayaan** ✅
- ✅ 12 impian di `data/dreams.json` (HP baru sampai pensiun dini)
- ✅ Pilih 1-2 impian di awal permainan; maksimal 3 aktif; tambah dari Beranda
- ✅ Pos impian per impian (lewat Rencana Gaji atau setor manual), berbunga seperti tabungan
- ✅ Terwujud otomatis + perayaan (confetti), kebahagiaan & XP naik
- ✅ Tenggat terlewat: perpanjang 12 bulan (kebahagiaan -3) atau lepaskan (kebahagiaan -5)
- ✅ 2 target bulanan acak, hadiah kecil, gagal tidak dihukum
- ✅ Notifikasi singkat saat target selesai dan naik level
- ✅ Laporan: hasil target, pos impian, dan pembanding "kalau tidak bertransaksi"
- ⬜ Avatar bereaksi sesuai kondisi (ditunda: butuh aset ekspresi avatar)

**Langkah 4: Event Director, kuis, iklan** ✅
- ✅ 0-3 event per bulan sesuai tingkat kesulitan (Santai 25/45/25/5, Normal 15/40/30/15, Sulit 10/30/35/25 %)
- ✅ Event diputuskan satu per satu; tombol Lanjut terkunci sampai semua selesai
- ✅ Bobot event menyesuaikan kondisi pemain (kas berlebih/tipis, kesehatan/kebahagiaan rendah, memegang saham/kripto) lewat tag `context` di `events.json`
- ✅ Anti-sial beruntun dan peluang naik setelah 2 bulan tenang
- ✅ Rantai event: pinjaman teman → Janji Temanmu, investasi bodong → Pengelola Kabur, pinjol → Penagih Pinjol
- ✅ 3 event kontekstual baru: Tawaran Konseling, Harbolnas 12.12, Cek Kesehatan (total 39 event)
- ✅ Event kalender (THR) dan event lanjutan terpisah dari jatah acak
- ✅ Kuis 6 soal per minggu, gratis; benar atau salah memakai kuota; soal tidak diulang di minggu yang sama
- ✅ Tombol iklan dihapus; teks iklan di UI, `legal.json`, dan kebijakan privasi disesuaikan (game tanpa iklan)
- 🔄 Catatan keseimbangan: event kini rata-rata 1,42/bulan (sebelumnya 0,61); simulasi 10 tahun menunjukkan gaji & kekayaan tumbuh lebih cepat karena event positif ikut lebih sering. Ditinjau saat penyeimbangan ekonomi

**Langkah 5: SQLite** ✅
- ✅ Plugin `godot-sqlite` v4.9 (MIT) cocok dengan Godot 4.7; Android hanya arm64, jadi APK kini arm64 saja (HP 32-bit tidak didukung)
- ✅ Satu database `user://cuan_quest.db` berisi 6 tabel: data pemain, riwayat permainan, slot save, harga harian, harga bulanan, transaksi
- ✅ Riwayat harga bertingkat: harian 24 bulan terakhir + penutupan bulanan sepanjang permainan
- ✅ Simpan bertahap: hanya data baru yang ditulis (±10 ms per simpan otomatis di PC)
- ✅ Simpan & muat persis sampai digit terakhir (sisa state disimpan biner, bukan JSON)
- ✅ Riwayat permainan disimpan semua (tampil 10 terakhir); hapus slot ikut menghapus harga & transaksinya
- ✅ File JSON lama (`player.json`, `saves/*.json`) diimpor otomatis sekali saat game dibuka, lalu dihapus
- ✅ Uji otomatis: 52 pemeriksaan (bertahap == penuh, muat lalu lanjut 3 bulan == tanpa muat, batas 200 transaksi, save lama ditolak, impor JSON lama)

### Kriteria selesai v1.5-0

- ✅ Grafik berisi data harian; drift dan volatilitas tahunan tetap sesuai `data/assets.json`
- ✅ Animasi pergantian bulan mulus dan bisa dilewati dengan ketukan
- ✅ Bulan rutin tidak perlu mengatur gaji lagi: rencana berjalan otomatis
- ✅ Autodebet tereksekusi setiap bulan dan dicatat di laporan serta riwayat transaksi
- ✅ Minimal 12 impian; progres, tercapai, dan terlewat berjalan benar
- ✅ Event Director menghasilkan 0-3 event per bulan sesuai distribusi, dan rantai event berjalan
- ✅ Simpan dan muat menghasilkan keadaan yang sama persis (harga, RNG, antrean & jadwal event; sejak SQLite persis sampai digit terakhir)
- ✅ Save versi lama ditolak dengan pesan yang jelas, tanpa crash
- ✅ Kuota kuis 6 soal per minggu, tanpa tombol iklan
- ⬜ **Playtest:** penguji rata-rata memainkan minimal 10 bulan per sesi dan jarang merasa "hanya menekan Lanjut"

---

## v1.5a: Realisme Ekonomi 🔄

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Inflasi, suku bunga BI & daya beli | ✅ |
| 2 | Pajak + layar konfirmasi transaksi (fee, pajak, konsentrasi, indikator risiko) | ✅ |
| 3 | Asuransi kesehatan, jiwa, kendaraan + klaim di event | ✅ |
| 4 | Stop loss & take profit (dicek harian) | ✅ |
| 5 | Penyeimbangan ekonomi (simulasi + playtest) | ⬜ |

### Rincian fitur

**Langkah 1: Inflasi, suku bunga BI & daya beli** ✅
- ✅ Inflasi tahunan bergerak pelan di sekitar 3,5% (kisaran ±2-5%); berita BBM naik / panen raya ikut menggesernya
- ✅ Indeks harga: biaya makan & sewa, biaya event & aktivitas, harga impian, hadiah kuis, dan nominal target ikut naik
- ✅ Teks event & impian memakai token `{rp:...}` sehingga angka di cerita sama dengan biaya sebenarnya
- ✅ Gaji disesuaikan setiap Januari sebesar inflasi setahun (tanpa popup tinjau rencana)
- ✅ Bank Indonesia menaikkan/menurunkan suku bunga mengikuti inflasi (±2 kali per tahun) dan diumumkan lewat berita; bunga tabungan, deposito, dan imbal hasil RD pasar uang ikut berubah; saham tergoncang saat pengumuman
- ✅ Laporan bulanan: bagian Ekonomi (inflasi bulan ini & setahun, daya beli kas & tabungan yang tergerus) dan penyesuaian gaji
- ✅ Profil: kartu Daya Beli (inflasi, BI Rate, bunga tabungan bersih, kenaikan harga sejak awal, kekayaan riil)
- ✅ Pasar: chip inflasi di samping suku bunga acuan
- ✅ Simulasi 40 x 10 tahun: indeks harga median 1,43; kekayaan riil median Rp536 jt (tanpa inflasi Rp587 jt)
- ℹ️ Target menang "Miliarder" tetap Rp1 miliar nominal; target "Bebas finansial" otomatis ikut inflasi karena memakai biaya hidup

**Langkah 2: Pajak & layar konfirmasi** ✅
- ✅ PPh 21 dipotong dari gaji: gaji setahun - PTKP Rp54 jt, tarif 5/15/25/30/35% (PTKP & lapisan ikut inflasi)
- ✅ Rencana gaji & Beranda memakai gaji bersih; Beranda menampilkan potongan PPh 21
- ✅ Pajak investasi: saham pajak final 0,1% saat jual (fee broker 0,15%), kripto PPN 0,11% saat beli + PPh 0,1% saat jual, bunga deposito 20% (tercatat), reksa dana bebas pajak
- ✅ Layar konfirmasi beli/jual: harga, fee, pajak, penalti deposito, yang masuk/diterima, unit, untung/rugi, meter risiko 1-5 + batas profil risiko
- ✅ Peringatan: di atas profil risiko, konsentrasi > 60% di satu aset, dana darurat belum cukup, sisa kas < biaya hidup sebulan, jual rugi, penalti deposito
- ✅ Laporan bulanan: PPh 21 di pemasukan + bagian PAJAK & BIAYA (fee, pajak transaksi, pajak bunga, total)
- ✅ Riwayat transaksi menampilkan pajak; Profil menampilkan total pajak & fee dibayar
- ✅ Database skema 2: kolom `tax` di tabel transaksi (migrasi otomatis dari skema 1)
- ✅ Simulasi 40 x 10 tahun: kekayaan riil median Rp488 jt; total pajak 10 tahun median Rp54,7 jt; semua permainan bertahan

**Langkah 3: Asuransi** ✅
- ✅ 4 produk di `data/insurance.json`: BPJS Kesehatan (premi Rp150 rb, tanggung 80%), asuransi kesehatan swasta (Rp500 rb, 100%), asuransi jiwa berjangka (Rp150 rb, uang pertanggungan Rp100 jt saat penyakit kritis), kendaraan all risk (2,5%/tahun harga kendaraan, risiko sendiri Rp300 rb)
- ✅ Popup Perlindungan + kartu Perlindungan di Beranda; premi tampil di rencana gaji, Arus Kas Beranda, dan laporan bulanan
- ✅ Premi dibayar otomatis tiap awal bulan (ikut inflasi); masa tunggu 1 bulan; polis berhenti jika kas tidak cukup
- ✅ Klaim otomatis: pilihan event bertanda `claim` (berobat: demam, rawat inap, gigi, penyakit kritis; kendaraan: kecelakaan) dan event `critical` (asuransi jiwa)
- ✅ Event baru: Kecelakaan di Jalan (hanya jika punya kendaraan dari impian motor/mobil), Penyakit Kritis (langka, sekali seumur permainan), Tawaran Unit Link (edukasi). Total 42 event
- ✅ Pilihan event menampilkan "bayar RpX, asuransi menanggung RpY"; hasil event menampilkan klaim
- ✅ Analisis akhir: manfaat asuransi atau biaya berobat yang dibayar sendiri
- ✅ Glosarium: Polis, Premi, Klaim, Masa tunggu, Risiko sendiri, Unit link, Uang pertanggungan

**Langkah 4: Stop loss & take profit** ✅
- ✅ Popup "Stop Loss & Take Profit" dari kartu kepemilikan di detail aset (saham, kripto, reksa dana); batas dipilih sebagai jarak dari harga sekarang (stop loss 5-50%, take profit 10-200%) dengan perkiraan uang diterima & untung/rugi
- ✅ Dicek setiap hari bursa/kalender di simulasi harian; harga harian pertama yang menyentuh batas menjual semua unit di harga hari itu (kena fee & pajak), lalu pesanan selesai
- ✅ Tercatat di riwayat transaksi (Stop loss / Take profit) dan laporan bulanan bagian PESANAN OTOMATIS: tanggal, harga, untung/rugi, harga akhir bulan sebagai pembanding
- ✅ Grafik kekayaan harian & perubahan nilai investasi memperhitungkan penjualan di tengah bulan
- ✅ Jual semua secara manual menghapus pesanan; simpan & muat tetap persis
- ✅ Glosarium: Stop loss, Take profit

**Langkah 5: Penyeimbangan** ⬜
- ⬜ Simulasi ulang setelah pajak & asuransi; atur event positif, kenaikan gaji, dan biaya agar game tidak terlalu mudah

**Kriteria selesai**
- ✅ Uang yang hanya disimpan di tabungan terasa tergerus dari waktu ke waktu
- ✅ Laporan bulanan menampilkan pajak dan fee dengan jelas
- ✅ Event sakit/kecelakaan berbeda hasilnya bagi yang berasuransi
- ✅ Stop loss & take profit tereksekusi tepat dan tercatat di riwayat

## v1.5b: Utang, Properti, dan Hunian yang Tumbuh ⬜

- ⬜ Utang: pinjaman pribadi, kredit kendaraan, KPR, skor kredit, gagal bayar, pinjol ilegal (event)
- ⬜ Properti: rumah, apartemen, tanah; tunai atau KPR; dihuni, disewakan, dijual
- ⬜ Ilustrasi hunian & kendaraan di Beranda berubah sesuai kepemilikan (aset dari pengembang)

**Kriteria selesai**
- ⬜ Utang bisa diambil, dibayar, dilunasi; skor kredit berubah
- ⬜ KPR terasa sebagai beban cicilan; properti sewa menghasilkan pendapatan pasif
- ⬜ Gagal bayar berkonsekuensi nyata; bangkrut menghitung utang dengan benar
- ⬜ Ilustrasi hunian dan kendaraan berubah sesuai kepemilikan

## v1.5c: Konten, Karier, dan Cerita ⬜

- ⬜ Jalur karier (minimal 5 jenjang)
- ⬜ 4-6 tokoh berulang di event dan rantai event
- ⬜ Riset pasar (laporan analis dengan tingkat keyakinan)
- ⬜ Kontrak dengan tenggat 1-3 bulan
- ⬜ Minimal 15 pencapaian; tema & avatar dibuka lewat pencapaian
- ⬜ Laporan tahunan
- ⬜ Sekitar 80 event dan 150 soal kuis

**Kriteria selesai**
- ⬜ Minimal 5 jenjang karier dengan syarat dan dampak yang jelas
- ⬜ Minimal 10 rantai event dengan tokoh berulang
- ⬜ Laporan analis benar/salah sesuai akurasi
- ⬜ Event, soal, impian, dan karier baru bisa ditambah lewat file data saja

## Penutup v1.5 ⬜

- ⬜ Uji performa dan baterai di HP kelas menengah
- ⬜ Playtest ulang dan penyeimbangan ekonomi (termasuk frekuensi event positif dari Event Director)
- ⬜ Disclaimer simulasi dan kebijakan privasi diperbarui

---

## v2 ⬜

**v2a: Instrumen lanjut**
- ⬜ Komoditas (3-4), forex (3-4 pasangan), leverage & margin (dicek harian)
- ⬜ Margin call dan likuidasi tidak bisa dieksploitasi
- ⬜ Peringatan risiko sebelum transaksi leverage pertama

**v2b: Siklus hidup penuh**
- ⬜ Bab kehidupan, penuaan, pensiun usia 60 yang berlanjut
- ⬜ Kesehatan & kematian (tabel peluang meninggal), status Kritis dengan peringatan
- ⬜ Depresi dengan pedoman konten sensitif
- ⬜ Warisan & layar akhir lengkap
- ⬜ Lompat per tahun di masa pensiun

**v2c: Mengelola dana investor**
- ⬜ Investor dengan target & toleransi risiko, fee + bagi hasil, reputasi

**v2d (opsional): Mini-game trading**
- ⬜ Sesi 60 detik, dibatasi energi, hasil dibandingkan dengan "kalau hanya ditahan"

**Penutup v2**
- ⬜ Peninjauan kebijakan Google Play untuk leverage, forex, serta konten depresi dan kematian

---

## M7: Rilis Play Store (setelah v2) ⬜

- ⬜ Export Android rilis (keystore, ikon adaptif; arm64 saja)
- ⬜ Layar lisensi pihak ketiga (Godot & godot-sqlite: MIT; SQLite: domain publik; font: OFL)
- ⬜ Isi `[EMAIL KONTAK]` dan `[NAMA PENGEMBANG]` di `data/legal.json` dan `docs/kebijakan-privasi.md`
- ⬜ Kebijakan privasi di URL publik, formulir *Data safety*
- ⬜ Rilis Play Store (tanpa iklan dan tanpa pembelian)
