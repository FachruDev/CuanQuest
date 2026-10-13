# Panduan Uji Prototipe Waktu (Cuan Proto Waktu)

APK `cuan-quest-proto-waktu.apk` berisi **dua prototipe** yang dipilih dari menu pembuka. Tujuannya membandingkan cara waktu berjalan sebelum game utama dirombak. Aplikasi ini terpisah dari game Cuan Quest, jadi simpanan game utama tidak terganggu.

| | A: Waktu per Jam | B: Hari Cepat |
|---|---|---|
| Kecepatan | 1 jam game = 2,5 detik (1 bulan sekitar 20 menit) | 1 hari game sekitar 1 detik (1 bulan sekitar 30 detik + keputusan) |
| Harga | Bergerak per jam; saham hanya di jam bursa | Bergerak sekali sehari |
| Waktu berhenti sendiri saat | Event, laporan, tengah malam, pingsan | Rencana awal bulan, gajian, event, laporan, harga bergerak besar |
| Yang dikerjakan selama berjalan | Beli/jual, tidur, lompat ke gajian/akhir bulan | Aktivitas berdurasi (pakai energi bulanan), 3 misi bulanan, menjaga kesehatan & kebahagiaan, reaksi saat harga anjlok/melonjak |

Di kedua prototipe: tombol **Jeda / 1x / 2x / 4x**, jeda otomatis saat aplikasi ditinggal atau 3 menit tanpa sentuhan, dan **Panel uji** di bagian paling bawah (ganti skala waktu, salin laporan, ganti prototipe).

## Yang diminta dari penguji

1. Mainkan **keduanya**, masing-masing minimal 2 sesi dalam beberapa hari. Sesi pendek (5-10 menit) juga boleh.
2. Bermainlah senatural mungkin.
3. Di akhir, buka **Panel uji** di masing-masing prototipe, tekan **Salin laporan**, lalu kirim kedua laporan ke pengembang beserta jawaban:
   - Mana yang lebih seru dimainkan, A atau B? Kenapa?
   - Apakah ada saat kamu merasa **hanya menunggu** tanpa ada yang bisa dilakukan? Di prototipe mana?
   - Di B: apakah waktu terlalu sering berhenti, pas, atau terlalu jarang? Skala mana yang paling nyaman (2 / 1 / 0,5 detik per hari)?
   - Apakah aktivitas dan misi bulanan membuatmu ingin terus bermain?
   - Apakah grafik terasa hidup? Apakah HP terasa panas atau baterai cepat habis?
   - Tipe HP yang dipakai.

## Kriteria keputusan

| Pertanyaan | Lanjut jika |
|---|---|
| Ritme enak? | Mayoritas tidak merasa menunggu terlalu lama atau kewalahan |
| Selalu ada yang dikerjakan? | Penguji jarang merasa "hanya menunggu" |
| Sesi singkat nyaman? | Pemain bisa jeda dan keluar kapan saja tanpa rugi |
| Baterai & performa aman? | Tidak ada panas atau lag berarti di HP kelas menengah |

Prototipe yang menang menjadi dasar implementasi v1.5-0 di game utama, dan dokumen MVP diperbarui sesuai hasilnya.
