# Panduan Uji Prototipe Waktu (Cuan Proto Waktu)

Prototipe ini menguji satu hal: **apakah waktu yang berjalan per jam (bukan per bulan) enak dimainkan di HP**. Isinya sengaja sederhana: satu saham, satu kripto, gaji, tagihan, dan beberapa event hidup.

## Cara pasang

1. Pasang `cuan-quest-proto-waktu.apk` di HP (izinkan "Instal dari sumber tidak dikenal").
2. Aplikasi bernama **Cuan Proto Waktu**. Aplikasi ini terpisah dari game Cuan Quest, jadi simpanan game utama tidak terganggu.

## Aturan di prototipe

| Hal | Aturan |
|---|---|
| Waktu | 1 jam game = 2,5 detik nyata pada kecepatan 1x (bisa diubah di **Panel uji**) |
| Kecepatan | Jeda, 1x, 2x, 4x |
| Tidur | Langsung ke pukul 06:00 besok; energi pulih |
| Begadang | Peringatan pukul 00:00; pingsan pukul 02:00 dan baru bangun pukul 09:00 |
| Bursa saham | Senin-Jumat 09:00-16:00. Di luar jam itu, pesanan **masuk antrean** dan dieksekusi di harga pembukaan |
| Kripto | Buka 24 jam |
| Kalender | Gaji tanggal 25, tagihan tanggal 1, laporan bulanan tanggal 30 pukul 20:00 |
| Lompat waktu | "Ke gajian" dan "Ke akhir bulan"; berhenti otomatis bila ada event |
| Jeda otomatis | Saat popup/form terbuka, saat aplikasi ditinggal, dan setelah 3 menit tanpa sentuhan |

## Yang diminta dari penguji

1. Mainkan **minimal 3 hari nyata**, setidaknya 2 sesi per hari. Sesi pendek (5-10 menit) juga boleh.
2. Coba ketiga skala waktu di **Panel uji** (5 / 2,5 / 1,25 detik per jam), masing-masing minimal satu sesi.
3. Bermainlah senatural mungkin: beli/jual, tidur, lompat waktu, tinggalkan aplikasi di tengah jalan.
4. Di akhir, buka **Panel uji**, tekan **Salin laporan**, lalu kirim hasilnya ke pengembang beserta jawaban:
   - Apakah ritmenya enak, terlalu lambat, atau terlalu cepat? Di skala berapa paling nyaman?
   - Apakah grafik terasa hidup? Apakah kamu ikut memperhatikan pergerakan harga?
   - Apakah jumlah event per bulan terasa pas, terlalu sering, atau terlalu jarang?
   - Apakah antrean pesanan saat bursa tutup mudah dipahami?
   - Apakah HP terasa panas atau baterai cepat habis?
   - Tipe HP yang dipakai.

## Kriteria keputusan (MVP bagian 3.1)

| Pertanyaan | Lanjut jika |
|---|---|
| Ritme enak? | Mayoritas tidak merasa menunggu terlalu lama atau kewalahan |
| Grafik hidup? | Pemain memperhatikan dan bereaksi terhadap pergerakan harga |
| Sesi singkat nyaman? | Pemain bisa jeda dan keluar kapan saja tanpa rugi |
| Baterai & performa aman? | Tidak ada panas atau lag berarti di HP kelas menengah |
| Skala waktu pas? | Pemain memakai campuran kecepatan; tidak hampir selalu 4x atau hampir selalu jeda |

Jika hasilnya buruk, game kembali ke sistem bulanan ditambah 4 slot hari (pagi, siang, sore, malam).
