# Panduan Uji Akhir v1.5 (Performa, Baterai, Playtest)

Panduan ini untuk menutup v1.5 sebelum lanjut ke v2. Ada tiga uji yang harus dilakukan di HP sungguhan. Isi tabel hasilnya, lalu laporkan ke pengembang.

- **Siapkan:** APK debug terbaru, HP kelas menengah (RAM 4-6 GB), baterai terisi ≥ 80%, kecerahan layar sedang, mode hemat daya HP **dimatikan**.
- **Nyalakan info performa:** Profil > Pengaturan > **Info performa (untuk uji di HP)**. Kotak kecil di atas tombol Lanjut menampilkan FPS, waktu proses per frame, memori, dan jumlah node. Matikan lagi setelah selesai uji.

## 1. Uji performa

Cara membaca info performa: game memakai **mode hemat prosesor**, jadi layar hanya digambar ulang saat ada yang berubah. **FPS rendah saat diam itu bagus.** Saat animasi atau scroll, FPS sebaiknya mendekati 60 (dibatasi 60 agar hemat baterai di layar 90/120 Hz).

| # | Uji | Cara | Target | Hasil |
|:--|:--|:--|:--|:--|
| 1 | Membuka game | Tutup paksa aplikasi, buka lagi, hitung sampai Beranda tampil | < 5 detik | |
| 2 | Diam di Beranda | Biarkan 30 detik tanpa disentuh | FPS 0-5 | |
| 3 | Scroll tab | Scroll Beranda, Pasar, Portofolio, Karier, Profil dari atas ke bawah | Terasa mulus, FPS ≥ 45 | |
| 4 | Pindah tab | Tekan kelima tab bergantian | Tidak ada jeda yang terasa (< 0,3 detik) | |
| 5 | Lanjut bulan | Tekan Lanjut 10 kali, tutup laporan tiap kali | Animasi laporan mulus, tidak patah | |
| 6 | Aksi kecil | Beli aset, ikut aktivitas, riset rumor, terima proyek | Tampilan langsung berubah tanpa jeda | |
| 7 | Memori | Lihat angka MB di awal dan setelah 30 menit bermain | Naik < 50 MB, tidak terus naik | |
| 8 | Suhu | Rasakan HP setelah 30 menit | Hangat wajar, tidak panas | |

## 2. Uji baterai

1. Catat persentase baterai di awal (mis. 85%).
2. Mainkan Cuan Quest **30 menit** seperti biasa (Info performa boleh dimatikan).
3. Catat persentase di akhir, lalu buka **Pengaturan HP > Baterai > Penggunaan baterai** dan lihat persentase untuk Cuan Quest.
4. Uji diam: buka game di Beranda, biarkan layar menyala **10 menit** tanpa disentuh, lalu bandingkan penurunannya dengan layar beranda HP yang dibiarkan menyala 10 menit.

| Uji | Target | Hasil |
|:--|:--|:--|
| Main aktif 30 menit | Turun ≤ 6% | |
| Diam 10 menit di Beranda | Hampir sama dengan layar HP biasa | |

## 3. Playtest

Tujuan v1.5-0: penguji rata-rata memainkan **minimal 10 bulan per sesi** dan jarang merasa "hanya menekan Lanjut".

- **Sesi bermain** tercatat otomatis di **Profil > Sesi Bermain** (tanggal, lama, jumlah bulan, rata-rata 10 sesi terakhir). Sesi baru dimulai jika kembali bermain setelah jeda 15 menit. Data hanya tersimpan di HP.
- Mainkan seperti biasa selama beberapa hari (idealnya ajak 2-3 teman ikut mencoba), lalu jawab:

| # | Pertanyaan | Jawaban |
|:--|:--|:--|
| 1 | Rata-rata bulan per sesi (lihat Profil > Sesi Bermain) | |
| 2 | Kapan saja terasa "hanya menekan Lanjut"? (bulan ke berapa, situasinya) | |
| 3 | Apakah kembali bermain keesokan harinya? Kenapa? | |
| 4 | Event yang terasa terlalu sering, terlalu jarang, atau membosankan | |
| 5 | Terlalu mudah atau terlalu sulit menjadi kaya / bebas finansial? | |
| 6 | Fitur yang membingungkan (rencana gaji, utang, properti, riset, proyek, dll.) | |
| 7 | Bug atau tampilan yang terpotong | |

## 4. Hasil uji di PC (pengembang, 15 Oktober 2026)

Diukur dengan benchmark permainan 30 tahun (headless, PC) yang memakai hampir semua fitur: lamaran kerja, autodebet, jual-beli saham & kripto, riset rumor, proyek sampingan, aktivitas, event.

| Ukuran | Tahun 1 | Tahun 10 | Tahun 30 |
|:--|:--|:--|:--|
| Tekan Lanjut (simulasi sebulan) | ±1,6-1,9 ms | ±2,0-2,4 ms | ±1,7-2,2 ms |
| Simpan ke database | ±15-28 ms | ±21-24 ms | ±22-25 ms |

- **Memori** permainan hampir tidak bertambah dalam 30 tahun (+1,6 MB), karena riwayat yang tumbuh sudah dibatasi (transaksi 200, berita 30, laporan tahunan 40, perjalanan karier 60).
- **Refresh tab setelah aksi** (sebelum → sesudah optimasi penutup v1.5): Portofolio 141 → ±3-8 ms, Karier 67 → ±10 ms, Profil 90 → ±8 ms (rentang = hasil beberapa kali ukur). Bagian yang berat (riwayat transaksi, laporan, pencapaian, papan lowongan, statistik, tokoh, ringkasan slot simpanan) kini hanya dibangun ulang jika datanya berubah. Tab yang tidak terlihat tidak diperbarui.
- Di HP kelas menengah angka-angka ini biasanya 3-5 kali lebih lambat. Itu masih di bawah ±100 ms, batas jeda yang mulai terasa oleh pemain, tetapi uji di HP tetap diperlukan untuk memastikan.
