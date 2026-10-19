# Checklist MVP Cuan Quest

Rangkuman semua checklist dalam satu tempat. Diperbarui setiap kali satu langkah selesai.

- **Terakhir diperbarui:** 19 Oktober 2026 (v2c langkah 1: dana kelolaan & investor pertama)
- **Sumber:** GDD bagian 11 (v1) dan `MVP_Cuan_Quest_Revisi3.md` (v1.5, v2, M7)
- **Tanda:** ✅ selesai · 🔄 sebagian · ⬜ belum

## Ringkasan Progres

| Tahap | Isi | Status |
|:--|:--|:--|
| **v1** (M1-M6.5) | Game dasar, 15 item GDD bagian 11 | ✅ 15/15 |
| **UI "Senja Cuan"** | Redesain seluruh tampilan | ✅ |
| **Prototipe waktu A/B/C** | Uji sistem waktu berjalan (tidak dipakai, diarsipkan) | ✅ |
| **v1.5-0** | Giliran Bulanan yang Hidup | 🔄 5/5 langkah; tinggal playtest |
| **v1.5a** | Realisme ekonomi | ✅ 5/5 langkah |
| **v1.5b** | Pekerjaan & karier (melamar kerja, keahlian, jenjang) | ✅ 5/5 langkah |
| **v1.5c** | Utang, properti, hunian yang tumbuh | ✅ 5/5 langkah (aset final menyusul setelah v2) |
| **v1.5d** | Tokoh, riset, kontrak, konten | ✅ 5/5 langkah (aset final menyusul setelah v2) |
| **Penutup v1.5** | Performa & baterai, playtest, legal | ✅ legal & performa (APK dicoba di HP); playtest berjalan terus lewat Profil > Sesi Bermain |
| **v2a** | Instrumen lanjut: komoditas, valas, leverage & margin | ✅ 5/5 langkah (ikon kelas menyusul setelah v2) |
| **v2b** | Siklus hidup penuh: bab, penuaan, kematian, depresi, warisan | ✅ 5/5 langkah (pedoman konten sensitif disetujui) |
| **v2c** | Mengelola dana investor | 🔄 1/4 langkah |
| **v2d** | Mini-game trading (opsional) | ⬜ |
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
- ✅ Bobot event menyesuaikan kondisi pemain (kas berlebih/tipis, kesehatan/kebahagiaan rendah, memegang saham/kripto) lewat tag `context` di data event (`data/events/*.json`)
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

## v1.5a: Realisme Ekonomi ✅

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Inflasi, suku bunga BI & daya beli | ✅ |
| 2 | Pajak + layar konfirmasi transaksi (fee, pajak, konsentrasi, indikator risiko) | ✅ |
| 3 | Asuransi kesehatan, jiwa, kendaraan + klaim di event | ✅ |
| 4 | Stop loss & take profit (dicek harian) | ✅ |
| 5 | Penyeimbangan ekonomi (simulasi + playtest) | ✅ |

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

**Langkah 5: Penyeimbangan** ✅
- ✅ Simulator keseimbangan permanen `tools/balance/` (5 tipe pemain x 40 permainan x 30 tahun; tidak ikut APK)
- ✅ Kenaikan gaji dari event dikecilkan: naik gaji +3%, promosi +15% (maks. 2, jeda 24 bulan), tawaran kerja +20%, kursus +5%
- ✅ Aktivitas Kursus: +1% gaji, maksimal 10 kali sepanjang permainan (sebelumnya +2% tanpa batas)
- ✅ Rutinitas kerja: kesehatan & kebahagiaan -1 per bulan, pulih alami +2 di bawah 50
- ✅ Premi asuransi diambil dari tabungan dana darurat jika kas kurang
- ✅ Imbal hasil kripto diturunkan (GRD 20%, MRP 35% per tahun)
- ✅ Hasil (Normal): pemain hemat bebas finansial median tahun 16,6 (sebelumnya 10,6); menabung saja tertinggal jauh dari berinvestasi; gaji riil tahun 10 x1,95 (sebelumnya x3,8)
- ✅ Tingkat kesulitan terasa: bebas finansial pemain hemat tahun 12 (Santai) / 16,6 (Normal) / 18,4 (Sulit); pemain acak 48% / 13% / 0%

**Kriteria selesai**
- ✅ Uang yang hanya disimpan di tabungan terasa tergerus dari waktu ke waktu
- ✅ Laporan bulanan menampilkan pajak dan fee dengan jelas
- ✅ Event sakit/kecelakaan berbeda hasilnya bagi yang berasuransi
- ✅ Stop loss & take profit tereksekusi tepat dan tercatat di riwayat

## v1.5b: Pekerjaan & Karier ✅ (usulan pengembang, disetujui 14 Oktober 2026)

Rancangan detail: `MVP_Cuan_Quest_Revisi3.md` bagian 5.2 (semua keputusan 5.2.10 disetujui). Kebutuhan aset: `docs/KEBUTUHAN_ASET.md`.

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Fondasi pekerjaan: jobs.json, latar SMA/D3/S1 tanpa kerja (Rp5 jt), lowongan & melamar, tab Karier awal | ✅ |
| 2 | Karier: kinerja, beban kerja, kenaikan prestasi, promosi, berhenti, PHK + pesangon, event kerja | ✅ |
| 3 | Pendidikan & keahlian: kuliah D3/S1/S2, kursus, sertifikasi, beasiswa | ✅ |
| 4 | Tampilan & cerita: wizard Game Baru, Beranda, Profil, petunjuk | ✅ |
| 5 | Penyeimbangan dengan simulator | ✅ |

### Rincian fitur

**Langkah 1: Fondasi pekerjaan** ✅
- ✅ `data/jobs.json`: 5 bidang x 5 jenjang + 3 kerja lepas (28 pekerjaan), syarat pendidikan/keahlian/pengalaman, gaji, beban kerja
- ✅ Latar baru SMA/SMK (18), D3 (21), S1 (22); semua mulai tanpa pekerjaan dengan modal Rp5 jt (Santai Rp7,5 jt, Sulit Rp3 jt)
- ✅ Statistik Pendidikan, Keahlian (0-100, kenaikan makin kecil saat tinggi), Pengalaman per bidang
- ✅ Lowongan 4-6 per bulan (selalu ada kerja lepas & lowongan yang cocok), syarat ✓/✗, peluang diterima dalam persen
- ✅ Melamar memakai 1 energi, maks. 3 per bulan; hasil awal bulan berikutnya di laporan (LAMARAN KERJA) + popup Tawaran Kerja; gaji pertama langsung dibayar
- ✅ Tab Aktivitas menjadi **Karier** (kartu Pekerjaan + Lowongan + aktivitas, kuis, unlock)
- ✅ Kursus & belajar mandiri menambah keahlian; kerja sampingan memberi uang tetap
- ✅ Event naik gaji/promosi/tawaran startup dihapus (39 event); PHK membuat kehilangan pekerjaan + pesangon 2x gaji; sakit kritis = cuti tanpa gaji
- ✅ Simulator `tools/balance` bisa mencari kerja (`--background=sma|d3|s1`)
- ✅ `SAVE_VERSION` 3 (save v1.5a ditolak); `docs/KEBUTUHAN_ASET.md` disusun ulang per versi
- 🔁 Ikon latar, ikon bidang, dan ikon tab Karier masih memakai ikon lain (lihat `docs/KEBUTUHAN_ASET.md`; aset dibuat pengembang setelah v2 selesai)

**Langkah 2: Karier** ✅
- ✅ **Kinerja** 0-100 untuk pekerjaan berjenjang: tiap bulan bergerak menuju target = 55 + keahlian dibanding syarat jabatan (-25..+20) + kesehatan & kebahagiaan (-15..+10), ditambah pilihan di event kerja. Tampil di kartu Pekerjaan (bar + predikat + penyusun target) dan laporan bulanan (bagian KARIER)
- ✅ **Beban kerja** per jabatan menggantikan rutinitas umum (kesehatan & kebahagiaan per bulan); menganggur: kebahagiaan -2/bulan; cuti tanpa gaji: nol
- ✅ **Kenaikan prestasi** tiap Januari di samping penyesuaian inflasi: kinerja ≥80 naik 3%, ≥60 naik 1,5% (setelah 6 bulan bekerja); tampil di laporan
- ✅ **Promosi** lewat event: masa jabatan 12/18/24/36 bulan, kinerja ≥70, pendidikan & keahlian jabatan berikutnya (pengalaman tidak perlu); peluang 35%/bulan saat siap; gaji = gaji pasar jabatan baru (minimal naik 10%); ditolak = jeda 12 bulan. Syarat ✓/✗ tampil di kartu Pekerjaan
- ✅ **PHK** dijadwalkan sistem: 0,1%/bulan, x5 jika kinerja <40 (x2 jika <60), x2,5 saat pasar saham bear; pesangon 1 bulan gaji per tahun masa kerja (maks. 9 bulan)
- ✅ **Berhenti kerja** (tombol + konfirmasi), tanpa pesangon
- ✅ **7 event kerja baru** (46 event): wawancara (negosiasi gaji sebelum tawaran muncul), tawaran promosi, lembur, proyek besar, beda pendapat dengan atasan, pelatihan kantor, headhunter (gaji pasar jabatan +20%, atau dipakai untuk minta naik gaji). Event PHK dirombak; THR hanya untuk pekerjaan berjenjang
- ✅ Teks event bisa berisi isian `{job}`, `{company}`, `{salary}`, `{months}`, `{severance}`, `{raise}`; syarat event baru `requires: career`
- ✅ **Kurva keahlian** (hasil simulator): tambahan keahlian x (1 - keahlian/100)², agar jenjang tinggi butuh usaha bertahun-tahun
- ✅ Simulator mencetak jenjang, promosi, PHK, kinerja, dan gaji total; 92 uji otomatis lulus

**Langkah 3: Pendidikan & keahlian** ✅
- ✅ `data/education.json`: Kuliah D3 (dari SMA, 36 bulan, Rp1 jt/bulan), S1 (48 bulan dari SMA atau 24 bulan alih jenjang dari D3, Rp1,5 jt), S2 (dari S1, 24 bulan, Rp3 jt); biaya ikut inflasi
- ✅ Kuliah sambil bekerja atau tidak: mulai bulan setelah mendaftar, energi -1 & kebahagiaan -1 per bulan; uang kuliah dari kas lalu tabungan dana darurat, jika tidak cukup kuliah cuti sebulan; berhenti kapan saja (biaya hangus)
- ✅ Lulus: pendidikan naik, keahlian +10 (dikali kurva keahlian), popup perayaan + baris di laporan (bagian KARIER)
- ✅ Kartu **Pendidikan & Keahlian** di tab Karier: pendidikan, keahlian, pengalaman, penjelasan kurva keahlian, daftar program (Daftar + konfirmasi) atau kuliah berjalan (kemajuan, tanggal lulus, beasiswa, Berhenti kuliah)
- ✅ Uang kuliah tampil di Rencana Gaji, Beranda, dan laporan bulanan
- ✅ Event pendidikan (kategori baru PENDIDIKAN, 49 event): **Beasiswa Prestasi** (50% uang kuliah), **Beasiswa dari Kantor** (ditanggung penuh selama bekerja di perusahaan itu; syarat 24 bulan & kinerja ≥75, sekali seumur permainan), **Minggu Ujian** (belajar seadanya bisa mundur 3 bulan); event kursus menjadi **Sertifikasi Profesi** sesuai bidang kerja (+8 keahlian, +3 kinerja)
- ✅ Kursus Online sekali tiap 3 bulan (`cooldown_months`), Belajar Mandiri +0,5 keahlian (hasil simulator)
- ✅ Simulator: tipe pemain baru **pelajar** (hemat + kuliah + kursus), cetak pendidikan, kelulusan, dan uang kuliah; 60 uji otomatis pendidikan + 94 uji karier lulus
- 🔁 Ikon program kuliah memakai ikon kursus (lihat `docs/KEBUTUHAN_ASET.md`)

**Langkah 4: Tampilan & cerita** ✅
- ✅ **Cerita "Hari Pertama"** saat permainan baru, berbeda untuk SMA/D3/S1 (modal, tempat tinggal, prospek kerja) + tombol Lihat Lowongan
- ✅ **Kartu Karier di Beranda** (paling atas): saat menganggur peringatan merah, sisa modal (kas + dana darurat) dalam bulan biaya hidup, lamaran terkirim, tombol Lihat Lowongan; saat bekerja jabatan, jenjang, kinerja, dan sisa syarat promosi; kuliah yang berjalan
- ✅ Catatan di kartu Kondisi kini menjelaskan beban kerja jabatan, stres mencari kerja, cuti, dan beban kuliah (sebelumnya catatan "rutinitas kerja" lama menampilkan 0)
- ✅ **Perjalanan Karier** (diterima kerja, promosi, PHK, berhenti, lulus/berhenti kuliah) di Profil dan layar akhir; statistik Promosi & Bulan menganggur
- ✅ Layar akhir: chip jabatan & pendidikan, analisis karier (PHK, menganggur, promosi, karier mandek, kuliah)
- ✅ Tutorial & petunjuk diperbarui: mulai tanpa kerja, tab Karier, 6 kuis per minggu; petunjuk tab Karier baru; deskripsi tingkat kesulitan menyebut modal awal
- ✅ Ikon bidang sementara kini berbeda per bidang (dompet, map, brankas, kaca pembesar, lampu, tas kerja) sampai aset bidang dibuat
- ✅ 43 uji otomatis baru (cerita, perjalanan karier, sisa modal, analisis akhir) + uji karier & pendidikan tetap lulus

**Perapian kode (sebelum langkah 5)** ✅
- ✅ `game_state.gd` (3.070 baris) dipecah menjadi root store (±750 baris) + 10 modul di `scripts/game/` (Career, Education, Insurance, Portfolio, Budget, Dreams, Targets, LifeEvents, Activities, Progress) dengan kelas dasar `GameModule`; UI memanggil `GameState.<modul>.<fungsi>()`
- ✅ Event dipecah per kategori ke `data/events/<kategori>.json` + panduan `docs/PANDUAN_EVENT.md` (field, efek per modul, syarat, isian teks)
- ✅ Perilaku tidak berubah: "golden runner" (6 permainan x 96 bulan) menghasilkan state akhir identik byte demi byte, 197 uji lulus, output simulator identik; format save tetap (save lama bisa dimuat)

**Langkah 5: Penyeimbangan** ✅
- ✅ Kebebasan finansial kini membandingkan pendapatan pasif dengan **seluruh pengeluaran rutin** (biaya hidup + premi + gaya hidup sesuai rencana gaji), bukan hanya makan & tempat tinggal; gaya hidup yang naik bersama gaji ikut menjauhkan tujuan
- ✅ Kenaikan prestasi 2% (kinerja ≥80) / 1% (≥60); syarat pengalaman pelamar luar 0/12/36/60/96 bulan
- ✅ Tinggal bersama keluarga: kebahagiaan -2 (dari -3); pemulihan alami +4 saat kesehatan/kebahagiaan di bawah 25 (sebelumnya pemain acak berlatar SMA sering kalah karena kebahagiaan habis)
- ✅ Simulator mencetak bulan kerja pertama dan gaji riil absolut
- ✅ Target: S1 bekerja di bulan 1 (p90 bulan 1); SMA yang kuliah menyusul gaji S1 hemat sebelum tahun ke-10 (Rp17,9 jt vs Rp14,3 jt); menganggur lebih dari 1-2 bulan berbahaya bagi SMA (modal ±1 bulan biaya hidup); karier baik x4-5 gaji riil dalam 30 tahun (target x3 dilonggarkan, lihat dokumen MVP); investasi rutin 2,3x menabung saja; tingkat kesulitan terasa (tahun 10,6 / 12,6 / 15,5)


**Kriteria selesai**
- ✅ Pemain mulai tanpa pekerjaan dan harus melamar
- ✅ Minimal 15 pekerjaan dan 5 jenjang karier dengan syarat jelas
- ✅ Keahlian & pendidikan bisa ditingkatkan dan membuka pekerjaan lebih baik
- ✅ Promosi, kenaikan gaji berbasis prestasi, PHK, dan pindah kerja berjalan
- ✅ Pekerjaan & karier baru bisa ditambah lewat file data saja

## v1.5c: Utang, Properti, dan Hunian yang Tumbuh ✅

Rancangan detail: `MVP_Cuan_Quest_Revisi3.md` bagian 5.3 (ditulis 14 Oktober 2026; keputusan 5.3.9 masih bisa diubah sebelum langkahnya dikerjakan). Kebutuhan aset: `docs/KEBUTUHAN_ASET.md`.

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Utang & skor kredit: KTA, cicilan anuitas, tunggakan & denda, macet, pelunasan dipercepat, kartu Beranda, popup pinjaman | ✅ |
| 2 | Kendaraan: aset menyusut + biaya rutin, kredit motor/mobil + DP, impian motor/mobil terhubung | ✅ |
| 3 | Properti & KPR: beli/sewakan/jual, BPHTB & PBB, KPR tetap → mengambang, kontrakan, DP rumah | ✅ |
| 4 | Tampilan & cerita: ilustrasi hunian & kendaraan, neraca di Portofolio, event utang & properti | ✅ |
| 5 | Penyeimbangan dengan simulator (pemain berutang & pembeli rumah) | ✅ |

### Rincian fitur

**Langkah 1: Utang & skor kredit** ✅
- ✅ `data/loans.json` + modul `GameState.debt` (`scripts/game/debt.gd`)
- ✅ **Pinjaman Tunai (KTA):** Rp5 jt sampai 5x gaji bruto, tenor 12/24/36 bulan, bunga = suku bunga BI + 12% (±17,75%) dikunci saat cair; syarat pegawai ≥6 bulan di perusahaan, skor ≥40, tidak menunggak, rasio cicilan ≤35% gaji. Syarat tampil ✓/✗, uang langsung cair
- ✅ **Cicilan anuitas** otomatis tiap awal bulan setelah gaji & biaya hidup (kas, lalu tabungan dana darurat); tampil di Rencana Gaji, Beranda, dan laporan
- ✅ **Menunggak:** tunggakan + denda 5%/bulan, skor -8; **3 bulan berturut-turut = macet**: seluruh sisa ditagih sekaligus (kas bisa minus → jual paksa → bangkrut)
- ✅ **Pelunasan dipercepat** dengan penalti 3% + perkiraan bunga yang dihemat
- ✅ **Skor kredit 0-100** (mulai 60): Sangat baik ≥80 (bunga -1%), Baik ≥60, Cukup ≥40 (bunga +2%), Buruk (ditolak); status pinjaman Kol 1-5 (OJK)
- ✅ Kekayaan bersih dikurangi utang; pengeluaran rutin untuk kebebasan finansial & sisa modal menghitung cicilan; dana darurat hasil pinjaman tidak membuka tahap instrumen
- ✅ Kartu **Utang & Kredit** di Beranda, popup **Pinjaman** (ajukan & rincian/pelunasan), bagian UTANG di laporan, 9 istilah glosarium, analisis akhir tentang utang
- ✅ Save v1.5b tetap bisa dimuat (tanpa reset)
- ✅ Simulator: tipe pemain **pengutang**; golden runner membuktikan permainan tanpa pinjaman tidak berubah; 84 uji utang + 201 uji lama lulus
- ✅ Perbaikan bug: baris Premi asuransi & Uang kuliah di popup Rencana Gaji tertimpa "0% · Rp0"
- 🔁 Lencana popup Pinjaman memakai ikon dompet (lihat `docs/KEBUTUHAN_ASET.md`)

**Langkah 2: Kendaraan** ✅
- ✅ `data/vehicles.json` + modul `GameState.vehicles` (`scripts/game/vehicles.gd`): motor Rp28 jt & mobil Rp250 jt sebagai **aset yang nilainya menyusut** (12%/10% per tahun, minimal 15%), biaya rutin Rp400 rb/Rp2 jt per bulan (bensin, servis, pajak), kebahagiaan +1/+2 per bulan
- ✅ **Beli tunai** (dana impian dipakai dulu, impian terwujud dengan perayaan) atau **kredit**: Kredit Motor (leasing, BI + 18%, DP min 20%, kerja ≥3 bulan termasuk kerja lepas) & Kredit Mobil (bank, BI + 3,5%, DP min 25%, pegawai ≥12 bulan); impian ditutup tanpa hadiah dan dananya menjadi DP
- ✅ Impian Motor Baru / Mobil Keluarga yang terwujud otomatis menjadi kendaraan; impian kendaraan tidak bisa dipilih jika kendaraannya sudah dimiliki
- ✅ **Jual ke dealer** (90% nilai pasar, kredit dilunasi dulu); **kredit macet 3 bulan → kendaraan ditarik & dilelang** (70% nilai pasar, sisa hasil lelang dikembalikan)
- ✅ Kekayaan bersih memuat nilai kendaraan; biaya rutin masuk pengeluaran rutin (kebebasan finansial), sisa modal, Rencana Gaji, Beranda, dan laporan (+ penyusutan bulanan)
- ✅ Asuransi kendaraan: premi & biaya perbaikan dari nilai pasar kendaraan; event kecelakaan lebih jarang & lebih murah (klaim ±57% premi, sebelumnya 6,5x)
- ✅ Kartu **Kendaraan** di Beranda, popup **Kendaraan** (beli tunai/kredit dengan DP & tenor, rincian & jual), petunjuk kredit di detail impian, 3 istilah glosarium, analisis akhir tentang kendaraan
- ✅ Save lama: impian motor/mobil yang sudah terwujud menjadi kendaraan
- ✅ Simulator: tipe pemain **pengendara**; S1 bebas finansial tahun 20,1 (hemat tanpa kendaraan 12,6); golden runner identik untuk permainan tanpa kendaraan; 81 uji kendaraan + 285 uji lama lulus
- 🔁 Lencana popup Kendaraan memakai ikon kerja sampingan (lihat `docs/KEBUTUHAN_ASET.md`)

**Langkah 3: Properti & KPR** ✅
- ✅ `data/properties.json` + modul `GameState.properties` (`scripts/game/properties.gd`): Rumah Subsidi, Apartemen Studio, Rumah Tipe 45, Rumah Besar, Tanah Kavling; harga = inflasi x indeks properti yang bergerak pelan per jenis (RNG sendiri)
- ✅ **Beli tunai atau KPR**; BPHTB 5% + notaris 1% dibayar tunai; **KPR** bunga tetap 3 tahun (±5%) lalu **mengambang** mengikuti suku bunga BI (±11,25%), cicilan dihitung ulang & tercatat di laporan; **KPR Subsidi FLPP** bunga tetap 5%, DP mulai 1%, gaji maks Rp8 jt, rumah pertama
- ✅ **Dihuni** (menggantikan sewa tempat tinggal, kebahagiaan +1 sampai +4), **disewakan** (sewa bersih setelah PPh final 10%, mencari penyewa 1-2 bulan, kontrak 12 bulan), atau **kosong**; rumah subsidi wajib dihuni
- ✅ **Jual**: PPh final 2,5% + agen 2,5%, laku 1-3 bulan dengan harga saat itu, KPR dilunasi dari hasil penjualan; bisa dibatalkan
- ✅ PBB & perawatan bulanan; KPR macet 3 bulan → **dilelang** 70% harga (sisa dikembalikan, kembali menyewa)
- ✅ Kekayaan bersih memuat properti; **sewa bersih = pendapatan pasif** untuk kebebasan finansial; biaya properti & cicilan masuk pengeluaran rutin
- ✅ Hunian sewa baru **Kontrakan**; impian **DP Rumah** kini mengembalikan dananya ke kas saat terkumpul (untuk uang muka)
- ✅ Kartu **Properti** di Beranda, popup **Properti** (daftar, beli dengan perkiraan cicilan setelah masa tetap, rincian/pemakaian/jual), baris sewa & biaya properti di Rencana Gaji, Beranda, laporan; 6 istilah glosarium; analisis akhir
- ✅ Simulator: tipe **pembeli_rumah** & **pembeli_rumah_kota**; S1 yang membeli Rumah Tipe 45 bebas finansial tahun 23,3 (tanpa rumah 12,6); golden runner identik untuk permainan tanpa properti; 77 uji properti + 366 uji lama lulus
- ✅ Perapian: baris Premi asuransi di Beranda tidak lagi menampilkan "+Rp0" merah saat belum berasuransi
- 🔁 Lencana popup Properti memakai ikon rumah navigasi (lihat `docs/KEBUTUHAN_ASET.md`)

**Langkah 4: Tampilan & cerita** ✅
- ✅ Kartu **Hunian & Kendaraan** di Beranda: ilustrasi 3 lapis (latar, tempat tinggal, kendaraan) yang berubah sesuai kondisi: menumpang → kos → kontrakan → apartemen/rumah sendiri (subsidi, tipe 45, rumah besar); jalan kaki → motor → mobil
- ✅ Kartu **Neraca** di Portofolio (kas, dana darurat, investasi, dana impian, kendaraan, properti − utang = kekayaan bersih, bar rasio utang terhadap aset) dan **Neraca Akhir** di layar akhir
- ✅ 9 event baru (58 total) dalam 2 kategori baru: **Properti** (Atap Bocor, Ingin Renovasi, Penyewa Telat Bayar) dan **Kredit** (tawaran Paylater & KTA pre-approved, Penagih Utang Datang / Surat Peringatan Terakhir sebulan sebelum macet, Masa Bunga Tetap KPR Berakhir)
- ✅ Pilihan baru di event: **restrukturisasi** utang (tunggakan masuk pokok + tenor 12 bulan), **take over KPR** ke bank lain (bunga tetap baru 2 tahun, biaya 3%), **pelunasan sebagian** KPR; produk tersembunyi **paylater** (±48% per tahun)
- ✅ Petunjuk pertama kali (pinjaman, kendaraan, properti), cerita **Rumah Sendiri!**, tutorial Beranda menyebut rumah/kendaraan/pinjaman, rincian KPR "tetap sampai ... / mengambang" di popup pinjaman
- ✅ Analisis akhir: restrukturisasi, tawaran kredit yang diterima, take over KPR; 5 istilah glosarium baru (67 total)
- ✅ Golden runner identik dengan langkah 3 saat event baru dibuang; 96 uji langkah 4 + 443 uji lama lulus
- 🔁 Ilustrasi hunian & kendaraan masih gambar pengganti sederhana (11 file, lihat `docs/KEBUTUHAN_ASET.md`; tinggal ditimpa dengan nama yang sama)

**Langkah 5: Penyeimbangan** ✅
- ✅ Tawaran KTA pre-approved hanya untuk skor kredit Baik (≥60) dan tidak lagi menyasar saat kas menipis
- ✅ Rumah subsidi: ongkos ke kota Rp400 rb/bulan saat dihuni + baru boleh dijual setelah 5 tahun (aturan FLPP); tidak lagi jalan pintas menuju bebas finansial
- ✅ Macet membuat skor kredit paling tinggi 30 (Buruk): pengajuan ditolak ±10 bulan, kembali Baik ±30 bulan
- ✅ Simulator: tipe **pembeli_rumah_nekat** + statistik tawaran kredit, restrukturisasi, take over, dan pemulihan skor
- ✅ Target tercapai: S1 pembeli Rumah Tipe 45 bebas finansial tahun 22,4 (usia ±44; Santai 19,3, Sulit 24,2); pembeli nekat 8% dilelang; KTA macet hampir selalu berujung bangkrut, KPR macet bisa dipulihkan
- ✅ Golden runner identik untuk permainan tanpa event baru; 25 uji langkah 5 + 539 uji lama lulus
- ✅ Tidak ada aset baru (lihat `docs/KEBUTUHAN_ASET.md`)

**Kriteria selesai**
- ✅ Utang bisa diambil, dibayar, dilunasi; skor kredit berubah
- ✅ KPR terasa sebagai beban cicilan; properti sewa menghasilkan pendapatan pasif
- ✅ Gagal bayar berkonsekuensi nyata; bangkrut menghitung utang dengan benar
- ✅ Ilustrasi hunian dan kendaraan berubah sesuai kepemilikan (gambar pengganti sampai aset final)

## v1.5d: Konten dan Cerita ✅

Rancangan detail: `MVP_Cuan_Quest_Revisi3.md` bagian 5.4 (ditulis 15 Oktober 2026; keputusan 5.4.9 masih bisa diubah sebelum langkahnya dikerjakan).

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Tokoh berulang & rantai event: `data/characters.json`, kedekatan, 10 rantai, tokoh di popup event, kartu Orang Terdekat | ✅ |
| 2 | Riset pasar & rumor: rumor benar/jebakan, riset dasar 55% & mendalam 75%, rekam jejak analis | ✅ |
| 3 | Kontrak & proyek sampingan: papan proyek, 3 strategi, tenggat 1-3 bulan | ✅ |
| 4 | Pencapaian (≥15), kosmetik (bingkai avatar & gelar), laporan tahunan | ✅ |
| 5 | Perluasan konten (±150 soal kuis, event pelengkap) & penyeimbangan | ✅ |

### Rincian fitur

**Langkah 1: Tokoh berulang & rantai event** ✅
- ✅ 6 tokoh di `data/characters.json`: Bima (sahabat), Ibu, Kak Wulan (mentor keuangan), Bu Ratna (tetangga), atasan & rekan kerja (nama mengikuti perusahaan)
- ✅ Kedekatan 0-100 yang diubah pilihan event; lanjutan cerita bisa mensyaratkan kedekatan; atasan/rekan kerja sedikit memengaruhi promosi, PHK, dan kinerja
- ✅ 10 rantai event bertokoh (32 event baru, total 90 event): koin viral & rug pull, kedai kopi & perjanjian tertulis, Ibu sakit & BPJS, arisan online bodong, cek kesehatan keuangan dengan saran sesuai kondisi pemain, tanah bersurat girik, presentasi klien, evaluasi kinerja & negosiasi gaji, robot trading ilegal, dan pinjam uang
- ✅ Tokoh di popup event (potret, nama, peran, kedekatan), perubahan kedekatan di hasil event, kartu **Orang Terdekat** di Profil
- ✅ Golden runner identik saat event baru dibuang; 57 uji tokoh + uji lama lulus
- 🔁 Potret tokoh sementara lingkaran berwarna + inisial (lihat `docs/KEBUTUHAN_ASET.md`)

**Langkah 2: Riset pasar & rumor** ✅
- ✅ 10 jenis rumor di `data/rumors.json` (naik & turun, saham & kripto), hanya untuk aset yang sudah terbuka, ±4 kali setahun
- ✅ Rumor menggerakkan harga saat beredar, lalu terbukti atau ternyata hoaks bulan berikutnya; rata-rata netral bagi harga jangka panjang
- ✅ Kartu **Kabar Burung** di tab Pasar (daftar & detail aset): riset dasar (1 energi, 55%) dan riset mendalam (2 energi + biaya, 75%)
- ✅ Bagian **Rumor & Riset** di laporan bulanan: terbukti/hoaks, harga sejak rumor, riset tepat/meleset, posisi pemain, pelajaran
- ✅ Kartu **Rekam Jejak Riset** di Profil (akurasi nyata vs tingkat keyakinan), petunjuk pertama kali, 4 istilah glosarium baru
- ✅ Simulator: tipe pemain `pemburu_rumor` & `periset`; golden runner identik saat rumor dimatikan; 108 uji riset + 621 uji lama lulus

**Langkah 3: Kontrak & proyek sampingan** ✅
- ✅ 17 proyek di `data/contracts.json` (5 bidang kerja + Umum, 3 tier), papan 0-2 tawaran per bulan di tab Karier, maksimal 2 proyek sekaligus
- ✅ 3 strategi (teliti, cepat, bersama rekan) dengan energi bulanan, peluang berhasil, dan bagi hasil berbeda; tenggat 1-3 bulan
- ✅ Hasil memuaskan/selesai/revisi/gagal; bayaran, pengalaman bidang, keahlian, XP, dan reputasi (membuka proyek lebih besar)
- ✅ Dipengaruhi pasar (kampanye & konsultasi saat pasar lesu, proyek dibayar token kripto); dua proyek sekaligus melelahkan dan menurunkan kinerja kantor
- ✅ Kartu proyek aktif & tawaran di tab Karier, baris di Beranda, bagian Proyek Sampingan di laporan bulanan, statistik di Profil, petunjuk pertama kali
- ✅ Simulator: tipe pemain `pekerja_lepas` & `gila_kerja`; golden runner identik; 86 uji proyek + 729 uji lama lulus
- 🔁 Ikon bidang Umum sementara `book.svg` (lihat `docs/KEBUTUHAN_ASET.md`)

**Langkah 4: Pencapaian, kosmetik & laporan tahunan** ✅
- ✅ 21 pencapaian lintas permainan di `data/achievements.json` (syarat sebagai data), popup perayaan saat terbuka
- ✅ Kosmetik tanpa aset baru: 16 gelar & 7 bingkai avatar (dipilih di Profil; tampil di top bar, Profil, layar akhir)
- ✅ Bagian Tampilan & Pencapaian di Profil (progres tiap pencapaian, hadiahnya)
- ✅ Laporan tahunan setiap Januari (pemasukan, pengeluaran per pos, investasi vs inflasi, kekayaan nominal & riil, impian & pencapaian), bisa dibuka lagi dari Profil
- ✅ Simulator mencetak persentase permainan yang membuka tiap pencapaian; golden runner identik; 62 uji pencapaian & laporan tahunan + 815 uji lama lulus
- 🔁 Lencana pencapaian sementara ikon bintang/gembok; tema & avatar tambahan menyusul bersama aset final setelah v2

**Langkah 5: Perluasan konten & penyeimbangan** ✅
- ✅ 150 soal kuis (8 topik; 4 topik baru: utang & kredit, properti, karier & pajak, asuransi); pencapaian kuis 50 soal
- ✅ 14 event baru (total 104), termasuk event musiman: resolusi tahun baru, banjir & DBD, SPT & Ramadan, mudik Lebaran, sekolah adik, 17 Agustus, liburan akhir tahun
- ✅ 9 istilah glosarium baru (81)
- ✅ Uji konten otomatis untuk semua soal & event; 98 uji konten + 877 uji lain lulus
- ✅ Simulator: ekonomi tetap seimbang (S1 hemat 12,6, SMA 19,1, acak 60%) setelah bobot event baru diturunkan & Pelatihan dari Kantor dinaikkan; opsi `--skip-events` untuk membandingkan dampak event

**Daftar fitur v1.5d**
- ✅ 4-6 tokoh berulang di event dan rantai event
- ✅ Riset pasar (laporan analis dengan tingkat keyakinan)
- ✅ Kontrak dengan tenggat 1-3 bulan
- ✅ Minimal 15 pencapaian (21); kosmetik bingkai avatar & gelar dibuka lewat pencapaian (tema & avatar baru setelah aset v2)
- ✅ Laporan tahunan
- ✅ Sekitar 80 event dan 150 soal kuis (104 event, 150 soal)

**Kriteria selesai**
- ✅ Minimal 10 rantai event dengan tokoh berulang
- ✅ Laporan analis benar/salah sesuai akurasi
- ✅ Event, soal, dan impian baru bisa ditambah lewat file data saja (divalidasi uji konten)

## Penutup v1.5 ✅ (playtest berjalan terus)

Panduan uji di HP: `docs/UJI_AKHIR_V15.md` (tabel performa, baterai, dan pertanyaan playtest).

**Uji performa dan baterai di HP kelas menengah** ✅
- ✅ Hemat baterai: mode hemat prosesor (layar hanya digambar ulang saat ada perubahan) dan FPS dibatasi 60 (layar 90/120 Hz)
- ✅ Info performa di Profil > Pengaturan: FPS, waktu proses, memori, jumlah node (mati secara bawaan)
- ✅ Benchmark 30 tahun di PC: Lanjut ±2 ms, simpan ±15-30 ms, memori +1,6 MB dalam 30 tahun
- ✅ Refresh tab dipercepat dengan cache tampilan (`UiText.changed_key`): Portofolio 141 → ±3-8 ms, Karier 67 → ±10 ms, Profil 90 → ±8 ms; Beranda & Pasar tidak diperbarui saat tidak terlihat
- ✅ APK penutup v1.5 dicoba di HP pemilik proyek (15 Oktober 2026); tidak ada masalah performa yang dilaporkan

**Playtest ulang dan penyeimbangan ekonomi** 🔄
- ✅ Sesi bermain tercatat otomatis (Profil > Sesi Bermain: rata-rata bulan per sesi, 5 sesi terakhir; disimpan lokal)
- ✅ Analisis Event Director di simulator: ±19-20 event per tahun, ±26% buruk, hanya ±3% event yang langsung menambah kekayaan; dampak bersih ±-Rp8 jt/tahun riil (pemain hemat). Kekhawatiran v1.5-0 (event positif terlalu sering) sudah teratasi sejak kenaikan gaji pindah ke sistem karier, jadi bobot event tidak diubah
- ✅ Ekonomi semua tipe pemain simulator tetap seimbang (lihat langkah 5 v1.5d)
- 🔄 Playtest berjalan terus (idealnya dengan 2-3 teman); target rata-rata ≥ 10 bulan per sesi, angka Sesi Bermain belum dilaporkan

**Disclaimer simulasi dan kebijakan privasi diperbarui** ✅
- ✅ Disclaimer di layar judul: bukan saran keuangan, uang virtual, aturan disederhanakan
- ✅ Kebijakan privasi (`data/legal.json` & `docs/kebijakan-privasi.md`): database lokal, data pemain lintas permainan, statistik sesi, izin getar, jam perangkat untuk kuis, tanpa iklan & analitik
- ✅ Syarat & ketentuan: bukan saran, aturan disederhanakan, tidak berafiliasi dengan OJK/BI/LPS/BPJS/BPOM/BPN, uang virtual, data fiktif, contoh penipuan
- ✅ Layar Lisensi Pihak Ketiga (Godot & godot-sqlite: MIT; SQLite: domain publik; Fredoka & Lilita One: OFL 1.1)

---

## v2 🔄

**v2a: Instrumen lanjut** ✅ (rancangan: `MVP_Cuan_Quest_Revisi3.md` 6.1.1-6.1.9)

*Langkah pengerjaan*
- ✅ **Langkah 1: Komoditas & emas**
  - ✅ 4 aset kelas baru Komoditas: Emas Batangan (tahap 3), Minyak Mentah, Minyak Sawit (CPO), Kopi Robusta (tahap 4)
  - ✅ Aliran angka acak kedua untuk aset, faktor, & berita baru: harga aset lama tetap sama persis (golden runner identik)
  - ✅ Siklus komoditas dunia (naik/datar/turun), emas berlawanan arah dengan saham, pola musiman (CPO, kopi, minyak)
  - ✅ 13 berita komoditas + dampak ikutan berita lama (bursa anjlok → emas naik, BBM naik → minyak naik, BI naik → emas turun)
  - ✅ Tampilan: kelas Komoditas di Pasar & alokasi, chip siklus komoditas, satuan (gram/barel/ton/kg), pola musiman & penjelasan per aset
  - ✅ Save lama tetap bisa dimuat (riwayat harga isian); emas bisa diautodebet & dihitung sebagai investasi di pencapaian
  - ✅ 6 istilah glosarium baru (87); 88 uji komoditas + 1007 uji lama lulus
  - 🔁 Ikon kelas komoditas sementara `trend_line.svg` (lihat `docs/KEBUTUHAN_ASET.md`)
- ✅ **Langkah 2: Valas**
  - ✅ 4 kurs kelas baru Valas: Dolar AS, Euro, Dolar Singapura, Yen Jepang (per 100 yen); kurs naik = rupiah melemah
  - ✅ Suku bunga BI tinggi menahan pelemahan rupiah (`rate_drift`); keputusan BI menggeser kurs; bursa panik → rupiah melemah, yen diburu; modal asing masuk → rupiah menguat
  - ✅ 9 berita valas (bank sentral AS, intervensi BI, neraca dagang, arus modal, Eropa, Jepang); berita dibagi per kelompok (komoditas 40%, valas 30% bulan)
  - ✅ Tahap 5: kekayaan bersih ≥ Rp500 jt + kuis topik baru **Valas & Leverage** 5 benar (20 soal, termasuk dasar leverage untuk tahap 6)
  - ✅ Tampilan: kelas Valas di Pasar & alokasi, chip kurs dolar, satuan per mata uang; valas bisa diautodebet
  - ✅ 5 istilah glosarium baru + Depresiasi diperluas (92); 71 uji valas + 1098 uji lama lulus; golden runner identik
  - 🔁 Ikon kelas valas sementara `arrow_badge.svg` (lihat `docs/KEBUTUHAN_ASET.md`)
- ✅ **Langkah 3: Leverage & margin**
  - ✅ Posisi leverage (`scripts/game/leverage.gd`, `data/leverage.json`): saham long 2x; emas & komoditas 2/5/10x; valas 5/10/20x; long & short; kripto & reksa dana tidak bisa
  - ✅ Margin terpisah per posisi, satu posisi per aset, maksimal 5 posisi; fee buka & tutup; biaya inap harian (BI + 4%/tahun atas dana pinjaman)
  - ✅ Dicek setiap hari bursa: likuidasi otomatis saat ekuitas ≤ 40% margin; margin call saat < 70% di akhir bulan; rugi melebihi margin (harga melompat) ditagih ke kas
  - ✅ Tahap 6: Tahap 5 terbuka + riset rumor tepat ≥ 5 + kuis Valas & Leverage 8 benar + skor kredit ≥ 60
  - ✅ Tampilan dasar: kartu Leverage di detail aset (syarat / buka / tambah margin / tutup), popup buka posisi dengan pratinjau risiko (harga margin call & likuidasi, rugi jika harga bergerak 5% & 10%), popup tambah margin, daftar Posisi Leverage di Portofolio, bagian LEVERAGE di laporan, riwayat transaksi, neraca
  - ✅ Ekuitas posisi masuk kekayaan bersih & grafik harian laporan; kas minus → posisi ikut ditutup paksa setelah aset dijual
  - ✅ 78 uji leverage + 1170 uji lama lulus; golden runner identik; strategi acak leverage maksimal rugi ±12% margin per posisi-bulan
- ✅ **Langkah 4: Peringatan & cerita**
  - ✅ Peringatan risiko wajib sebelum transaksi leverage pertama di setiap permainan ("Saya Paham Risikonya"); tanpa itu posisi tidak bisa dibuka (dicek juga di logika, bukan hanya tampilan)
  - ✅ Popup **Margin Call!** / **Posisi Dilikuidasi** setelah laporan bulanan, dengan tombol Lihat Posisi; spanduk margin call di atas Beranda
  - ✅ Popup peringatan bergaya peringatan (lencana "!" merah & bunyi peringatan), bukan gaya perayaan
  - ✅ 7 event baru (111): broker valas bonus 100% + dana tidak bisa ditarik, opsi biner, grup sinyal VIP, Bima & leverage 100x, emas untuk Lebaran (Ibu), Tidak Bisa Tidur saat margin call (syarat baru `has_margin_call`)
  - ✅ 8 istilah glosarium leverage (100); analisis layar akhir (likuidasi, rugi melebihi margin, biaya inap, untung tanpa likuidasi); statistik leverage di Profil; posisi leverage dihitung aset berisiko untuk event
  - ✅ 33 uji langkah 4 + 1248 uji lama lulus; golden runner identik (event baru disaring)
- ✅ **Langkah 5: Penyeimbangan & uji celah**
  - ✅ Simulator: 6 tipe pemain baru (`penabung_emas`, `pedagang_musiman`, `pemegang_dolar`, `penjudi_leverage`, `leverage_disiplin`, `musiman_leverage`) + ringkasan emas/komoditas/valas, dagang musiman, dan leverage
  - ✅ Tidak ada strategi yang jauh mengungguli hemat: musiman & leverage disiplin hanya +3-6% kekayaan akhir dengan risiko lebih besar; penjudi leverage −11%; tanpa penyesuaian angka
  - ✅ Uji celah lindung nilai (long/short searah, emas fisik + short emas) rugi rata-rata; 34 uji langkah 4-5 + 1248 uji lama lulus

*Daftar fitur*
- ✅ Komoditas (3-4) dengan siklus musiman
- ✅ Forex (4 kurs terhadap rupiah), kurs dipengaruhi suku bunga & event makro, selisih kurs 0,5%
- ✅ Leverage & margin (dicek harian), peringatan jelas sebelum likuidasi (laporan, kartu posisi, popup setelah laporan, spanduk Beranda)
- ✅ Syarat pembukaan sesuai draft (emas tahap 3, komoditas tahap 4, valas tahap 5, leverage tahap 6)

*Kriteria selesai*
- ✅ Margin call dan likuidasi tidak bisa dieksploitasi (satu posisi per aset, kekurangan ditagih ke kas, strategi acak & lindung nilai rugi, simulator 6 tipe pemain)
- ✅ Peringatan risiko sebelum transaksi leverage pertama

**v2b: Siklus hidup penuh** ✅ (rancangan: `MVP_Cuan_Quest_Revisi3.md` 6.2.1-6.2.9; pedoman: `docs/PEDOMAN_KONTEN_SENSITIF.md`)

*Langkah pengerjaan*
- ✅ **Pedoman konten sensitif** disetujui pemilik proyek (16 Oktober 2026); uji kata terlarang berjalan di uji konten
- ✅ **Langkah 1: Bab kehidupan & pensiun berlanjut**
  - ✅ 4 bab (Awal Karier, Membangun 30, Puncak 45, Pensiun 60) di `data/life.json`; popup ringkasan bab (kekayaan nominal & riil, impian, pekerjaan) + pesan bab berikutnya
  - ✅ Titik simpan bab otomatis (slot "Awal Bab", bisa dimuat dari Profil); kartu Perjalanan Hidup di Profil
  - ✅ Pensiun di 60 tanpa mengakhiri permainan: pekerjaan berakhir, lowongan tertutup, tanpa stres mencari kerja; proyek sampingan tetap ada
  - ✅ JHT (3,7% gaji pekerjaan formal, ±5,5%/tahun) cair sekaligus; Jaminan Pensiun bulanan 1% x tahun iuran x upah riil rata-rata (ikut inflasi), atau sekaligus jika iuran < 15 tahun; kerja lepas tanpa JHT/JP; perkiraan JHT & JP di kartu pekerjaan
  - ✅ Tombol "+1 Tahun" di masa pensiun; JP masuk laporan bulanan & tahunan; batas usia 100 (sementara, sampai kematian di langkah 3)
  - ✅ Save lama tetap bisa dimuat (bab dimulai saat dimuat, JHT/JP diperkirakan); 46 uji siklus hidup + 1282 uji lama lulus; golden runner identik
- ✅ **Langkah 2: Penuaan**
  - ✅ Tabel penuaan di `data/life.json`: energi −1 (60) / −2 (70); kesehatan turun alami 1 poin tiap 4 bulan (40), tiap 2 bulan (50), tiap bulan (60), 2 per bulan (70)
  - ✅ Biaya berobat ×1,5 (45) / ×2 (60), ditanggung asuransi sesuai porsinya; premi asuransi kesehatan swasta naik per kelompok usia; asuransi jiwa berjangka terkunci di usia saat membeli dan tidak bisa dibeli baru mulai 60
  - ✅ Peluang diterima pekerjaan berjenjang ×0,85 (50) / ×0,7 (55); kerja lepas tidak terpengaruh
  - ✅ 4 event usia (pemeriksaan rutin, reuni, mentor, rencana penarikan dana pensiun dengan aturan 4%); syarat event `min_age`/`max_age`; glosarium +4
  - ✅ Popup "Usia N Tahun" saat efek usia berubah (digabung ke ringkasan bab di 45 & 60); efek usia di Beranda, Profil, Karier, Perlindungan, laporan bulanan
  - ✅ Event Ibu berhenti di usia pemain 55 (pedoman); perbaikan ringkasan bab Puncak yang kini mencatat jabatan terakhir
  - ✅ 74 uji penuaan + 1331 uji lama lulus (termasuk uji kata terlarang); golden runner identik; simulator 45 tahun
- ✅ **Langkah 3: Kesehatan Kritis & kematian**
  - ✅ Tabel peluang meninggal (usia × kesehatan, `data/life.json` `mortality`; tambahan baris 90+), diundi tiap bulan dengan RNG tersendiri
  - ✅ Selalu dengan peringatan: status Kritis (kesehatan < 20, berakhir di 30) atau masa senja (pemberitahuan tahunan mulai 70); tanpa peringatan tidak ada undian
  - ✅ Status Kritis: popup peringatan, spanduk Beranda dengan tombol Pulihkan, peringatan di laporan bulanan, event Perawatan Kondisi Kritis (biaya ikut usia & asuransi)
  - ✅ Kesehatan 0 selama 3 bulan = meninggal karena sakit parah, dengan peringatan tiap bulan
  - ✅ Asuransi jiwa berjangka membayar ahli waris (warisan), berakhir di usia 70; lompat 1 tahun berhenti di peringatan Kritis & masa senja
  - ✅ Popup perpisahan & layar akhir yang tenang (tanpa "kalah"/"GAME OVER"), penyebab umum & warisan, analisis akhir baru; glosarium +2
  - ✅ 61 uji kematian + 1405 uji lama lulus; golden runner identik; simulator hidup penuh 80 tahun
- ✅ **Langkah 4: Depresi**
  - ✅ Status Depresi (`data/mental_health.json`): kebahagiaan < 20 selama 2 bulan, pulih saat > 40 selama 1 bulan; tidak pernah mengakhiri permainan (aturan kalah karena kebahagiaan 0 dihapus)
  - ✅ Efek: energi −2, kesehatan −1/bulan (berhenti di 30), Nongkrong tidak tersedia
  - ✅ Aktivitas Konseling (tampil saat kebahagiaan < 40 atau Depresi); event bantuan terjadwal + 3 event selama Depresi (puskesmas, Bima, Ibu), semuanya tenang dan selalu punya pilihan bantuan tanpa hukuman
  - ✅ Pesan dukungan (119) di popup Depresi pertama & Profil > Bantuan & Dukungan; catatan Beranda + Cari Bantuan; laporan bulanan; analisis akhir
  - ✅ Perbaikan: target bulanan hanya memakai aktivitas yang tersedia
  - ✅ 59 uji Depresi + 1468 uji lama lulus (termasuk uji pedoman untuk event Depresi); golden runner identik saat Depresi dimatikan; simulator hidup penuh + tipe pemain baru `acak_peduli`
- ✅ **Langkah 5: Warisan, layar akhir & penyeimbangan**
  - ✅ Skor warisan v2 (`data/legacy.json`): kekayaan riil (350, skala log), usia (200), rata-rata kesehatan & kebahagiaan sepanjang hidup (100 + 100), impian (100), keputusan bijak (150); tampil untuk semua akhir permainan
  - ✅ Layar akhir: rincian skor, label rekor baru, grafik kekayaan riil dengan penanda bab, keputusan terbaik/terburuk dalam nilai riil, wawasan bagian skor terlemah
  - ✅ Profil: skor terbaik sepanjang masa, skor & usia di riwayat permainan, perkiraan skor sejauh ini
  - ✅ Perkiraan dana pensiun di popup pensiun & masa senja (saran jika habis sebelum 90); glosarium +2
  - ✅ Penyeimbangan: peluang dasar meninggal 70+ dinaikkan (6% / 15% / 30%) agar pemain sehat rata-rata hidup ±85; simulator mencatat usia meninggal rata-rata & skor warisan per tipe pemain
  - ✅ 74 uji warisan (termasuk satu hidup penuh) + 1529 uji lama lulus; golden runner identik kecuali pemilihan transaksi terburuk (kini riil)

*Daftar fitur*
- ✅ Bab kehidupan ✅, penuaan ✅, pensiun usia 60 yang berlanjut ✅
- ✅ Kesehatan & kematian (tabel peluang meninggal), status Kritis dengan peringatan
- ✅ Depresi dengan pedoman konten sensitif
- ✅ Warisan & layar akhir lengkap
- ✅ Lompat per tahun di masa pensiun

*Kriteria selesai*
- ✅ Pemain dapat menyelesaikan satu hidup penuh (uji otomatis hidup penuh sampai meninggal dunia)
- ✅ Pemain yang menjaga kesehatan hampir tidak pernah meninggal sebelum 60; yang mengabaikannya bisa meninggal muda, selalu dengan peringatan (simulator langkah 3 & 5)
- ✅ Konten depresi dan kematian mengikuti pedoman konten sensitif (diperiksa uji otomatis; nomor layanan diverifikasi sebelum rilis)
- ✅ Skor warisan konsisten dan bisa dibandingkan antar permainan (nilai riil, bobot di file data, riwayat & skor terbaik di Profil)
  
**v2c: Mengelola dana investor** 🔄 (rancangan: `MVP_Cuan_Quest_Revisi3.md` 6.3.1-6.3.8)

*Langkah pengerjaan*
- ✅ **Langkah 1: Dana kelolaan & investor pertama**
  - ✅ Tahap 7 (tahap 4 + Rp1 miliar + 8 soal kuis baru "Manajemen Investasi" / ujian WMI, 20 soal); popup "Fitur Baru Terbuka!"
  - ✅ Modul dana kelolaan: 5 keranjang (tanpa kripto & leverage), alokasi kelipatan 10%, profil Konservatif/Moderat/Agresif, NAB per unit, setoran & pengembalian dana, seimbang ulang bulanan (ambang 2 poin)
  - ✅ Fee manajemen 1,5%/tahun ke kas pribadi (laporan bulanan & tahunan), 1 energi per bulan
  - ✅ 8 investor fiktif, papan tawaran (RNG tersendiri, tawaran pertama dijamin & cocok profil), mandat & peringatannya, reputasi minimal untuk investor besar
  - ✅ Kartu Dana Kelolaan di Portofolio, popup Dana Kelolaan, bagian Dana Kelolaan di laporan bulanan
  - ✅ Dana investor terpisah dari kekayaan bersih, neraca, dan skor warisan
  - ✅ 60 uji dana kelolaan + 1606 uji lama lulus (termasuk uji semua file data JSON terbaca); golden runner identik
- ⬜ Langkah 2: Kepuasan, penarikan & reputasi
- ⬜ Langkah 3: Laporan per investor & cerita
- ⬜ Langkah 4: Penyeimbangan & uji celah

*Kriteria selesai*
- 🔄 Pemain bisa menerima, mengelola, dan kehilangan dana investor (menerima, mengelola, mengembalikan ✅; investor pergi sendiri di langkah 2)
- ✅ Dana investor terpisah dari dana pribadi di portofolio dan laporan
- ⬜ Laporan bulanan per investor
- ⬜ Fee dan setor/tarik tidak bisa dieksploitasi

**v2d (opsional): Mini-game trading**
- ⬜ Sesi 60 detik, dibatasi energi, hasil dibandingkan dengan "kalau hanya ditahan"

**Penutup v2**
- ⬜ Peninjauan kebijakan Google Play untuk leverage, forex, serta konten depresi dan kematian

---

## M7: Rilis Play Store (setelah v2) ⬜

- ⬜ Export Android rilis (keystore, ikon adaptif; arm64 saja)
- ✅ Layar lisensi pihak ketiga (Godot & godot-sqlite: MIT; SQLite: domain publik; font: OFL), selesai di penutup v1.5
- ⬜ Isi `[EMAIL KONTAK]` di `data/legal.json` serta `[EMAIL KONTAK]` & `[NAMA PENGEMBANG]` di `docs/kebijakan-privasi.md`
- ⬜ Kebijakan privasi di URL publik, formulir *Data safety*
- ⬜ Rilis Play Store (tanpa iklan dan tanpa pembelian)
