# Panduan Uji Prototipe Waktu (Cuan Proto Waktu)

APK `cuan-quest-proto-waktu.apk` berisi **tiga prototipe** yang dipilih dari menu pembuka. Aplikasi ini terpisah dari game Cuan Quest, jadi simpanan game utama tidak terganggu. **Prototipe C adalah arah yang sedang diuji**; A dan B disimpan sebagai pembanding.

| | C: Sesi Pasar | B: Hari Cepat | A: Waktu per Jam |
|---|---|---|---|
| Waktu hidup | Per bulan, tombol **Bulan berikutnya** | 1 hari sekitar 1 detik | 1 jam game = 2,5 detik |
| Grafik | Berjalan sendiri selama sesi bulan itu (sekitar 90 detik), lalu pasar tutup | Bergerak sekali sehari | Bergerak per jam di jam bursa |
| Yang dikerjakan | Trading dengan tombol cepat, bereaksi pada berita kilat, menghadapi event hidup | Aktivitas, misi, menjaga kesehatan | Beli/jual, tidur, lompat waktu |

Di prototipe C:
- Tekan **Bulan berikutnya** kapan saja. Sisa pergerakan harga bulan itu dihitung instan, lalu laporan muncul.
- **Berita kilat** muncul di banner. Sebagian kabar benar dan harganya berlanjut; sebagian hanya rumor dan harganya berbalik.
- **Laporan bulanan** membandingkan hasil tradingmu dengan "kalau hanya menahan" portofolio awal bulan.
- Setelah sesi selesai, kamu masih boleh trading di harga penutupan.

Di semua prototipe ada tombol **Jeda / 1x / 2x / 4x**, jeda otomatis saat aplikasi ditinggal atau 3 menit tanpa sentuhan, dan **Panel uji** di bagian bawah (panjang sesi/skala waktu, salin laporan, ganti prototipe).

## Yang diminta dari penguji

1. Mainkan **prototipe C** minimal 2-3 sesi dalam beberapa hari (sekitar 10+ bulan game). A dan B boleh dicoba sebagai pembanding.
2. Coba ketiga panjang sesi di Panel uji (120 / 90 / 60 detik per bulan).
3. Di akhir, buka **Panel uji**, tekan **Salin laporan**, lalu kirim ke pengembang beserta jawaban:
   - Apakah trading selama sesi terasa seru? Apakah kamu menonton sampai pasar tutup atau sering langsung lanjut?
   - Panjang sesi mana yang paling pas?
   - Apakah berita kilat membuatmu ingin bereaksi? Apakah terlalu sering atau terlalu jarang?
   - Apakah pembanding "kalau hanya menahan" di laporan mudah dipahami dan membuatmu berpikir ulang soal trading?
   - Apakah event hidup di tengah sesi terasa mengganggu atau justru menarik?
   - Apakah HP terasa panas atau baterai cepat habis? Tipe HP yang dipakai.

## Kriteria keputusan

| Pertanyaan | Lanjut jika |
|---|---|
| Seru? | Mayoritas penguji menonton sebagian besar sesi dan ingin lanjut ke bulan berikutnya |
| Tidak membosankan? | Penguji jarang merasa "hanya menunggu" |
| Tetap edukatif? | Penguji memahami pembanding "kalau hanya menahan" |
| Baterai & performa aman? | Tidak ada panas atau lag berarti di HP kelas menengah |

Jika lolos, prototipe C menjadi dasar implementasi v1.5-0 di game utama, dan dokumen MVP diperbarui sesuai hasilnya.
