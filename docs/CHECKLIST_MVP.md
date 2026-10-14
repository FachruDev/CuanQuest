# Checklist MVP Cuan Quest

Rangkuman semua checklist dalam satu tempat. Diperbarui setiap kali satu langkah selesai.

- **Terakhir diperbarui:** 14 Oktober 2026 (v1.5b langkah 2 selesai)
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
| **v1.5b** | Pekerjaan & karier (melamar kerja, keahlian, jenjang) | 🔄 2/5 langkah |
| **v1.5c** | Utang, properti, hunian yang tumbuh | ⬜ |
| **v1.5d** | Tokoh, riset, kontrak, konten | ⬜ |
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

## v1.5b: Pekerjaan & Karier 🔄 (usulan pengembang, disetujui 14 Oktober 2026)

Rancangan detail: `MVP_Cuan_Quest_Revisi3.md` bagian 5.2 (semua keputusan 5.2.10 disetujui). Kebutuhan aset: `docs/KEBUTUHAN_ASET.md`.

### Langkah pengerjaan

| Langkah | Isi | Status |
|:--|:--|:--|
| 1 | Fondasi pekerjaan: jobs.json, latar SMA/D3/S1 tanpa kerja (Rp5 jt), lowongan & melamar, tab Karier awal | ✅ |
| 2 | Karier: kinerja, beban kerja, kenaikan prestasi, promosi, berhenti, PHK + pesangon, event kerja | ✅ |
| 3 | Pendidikan & keahlian: kuliah D3/S1/S2, kursus, sertifikasi, beasiswa | ⬜ |
| 4 | Tampilan & cerita: wizard Game Baru, Beranda, Profil, petunjuk | ⬜ |
| 5 | Penyeimbangan dengan simulator | ⬜ |

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

**Langkah berikutnya**
- ⬜ Pendidikan lewat kuliah D3/S1/S2 dengan biaya & waktu, sertifikasi, beasiswa (langkah 3)
- ⬜ Kartu "Kamu belum bekerja" di Beranda, wizard & petunjuk pekerjaan, ikon bidang (langkah 4)
- ⬜ Penyeimbangan akhir dengan simulator, termasuk tipe pemain yang rajin kursus (langkah 5)

**Kriteria selesai**
- ✅ Pemain mulai tanpa pekerjaan dan harus melamar
- ✅ Minimal 15 pekerjaan dan 5 jenjang karier dengan syarat jelas
- ⬜ Keahlian & pendidikan bisa ditingkatkan dan membuka pekerjaan lebih baik (pendidikan: langkah 3)
- ✅ Promosi, kenaikan gaji berbasis prestasi, PHK, dan pindah kerja berjalan
- ✅ Pekerjaan & karier baru bisa ditambah lewat file data saja

## v1.5c: Utang, Properti, dan Hunian yang Tumbuh ⬜

- ⬜ Utang: pinjaman pribadi, kredit kendaraan, KPR, skor kredit, gagal bayar, pinjol ilegal (event)
- ⬜ Properti: rumah, apartemen, tanah; tunai atau KPR; dihuni, disewakan, dijual
- ⬜ Ilustrasi hunian & kendaraan di Beranda berubah sesuai kepemilikan (aset dari pengembang)

**Kriteria selesai**
- ⬜ Utang bisa diambil, dibayar, dilunasi; skor kredit berubah
- ⬜ KPR terasa sebagai beban cicilan; properti sewa menghasilkan pendapatan pasif
- ⬜ Gagal bayar berkonsekuensi nyata; bangkrut menghitung utang dengan benar
- ⬜ Ilustrasi hunian dan kendaraan berubah sesuai kepemilikan

## v1.5d: Konten dan Cerita ⬜

- ⬜ 4-6 tokoh berulang di event dan rantai event
- ⬜ Riset pasar (laporan analis dengan tingkat keyakinan)
- ⬜ Kontrak dengan tenggat 1-3 bulan
- ⬜ Minimal 15 pencapaian; tema & avatar dibuka lewat pencapaian
- ⬜ Laporan tahunan
- ⬜ Sekitar 80 event dan 150 soal kuis

**Kriteria selesai**
- ⬜ Minimal 10 rantai event dengan tokoh berulang
- ⬜ Laporan analis benar/salah sesuai akurasi
- ⬜ Event, soal, dan impian baru bisa ditambah lewat file data saja

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
