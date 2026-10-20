# Rilis Play Store: Peninjauan Kebijakan & Persiapan

Hasil **Penutup v2** (rancangan: `MVP_Cuan_Quest_Revisi3.md` bagian 6.4). Dokumen ini menjadi pegangan saat mengisi Play Console di **M7**.

- **Ditinjau:** 19 Oktober 2026. Aturan Google Play dan pemerintah sering berubah: **periksa ulang bagian bertanda ⚠️ sesaat sebelum rilis.**
- **Langkah 1 (selesai):** peninjauan kebijakan & teknis, penyesuaian di dalam game, uji otomatis `test_policy`.
- **Langkah 2 (berikutnya):** draf lengkap isian Play Console (kuesioner rating, Data safety, target audiens, deklarasi) dan teks halaman toko (Indonesia & Inggris).
- **Bukan nasihat hukum.** Bagian regulasi Indonesia adalah ringkasan riset; untuk kepastian, tanyakan ke ahli hukum.

**Tanda:** ✅ sudah sesuai · 🔧 diubah di Penutup v2 · ⬜ dikerjakan di M7 · ⚠️ perlu dicek ulang / belum pasti

---

## 1. Kesimpulan

Cuan Quest **sesuai dengan kebijakan Google Play** untuk sebuah game simulasi edukasi: uang fiktif, tanpa transaksi uang asli, tanpa iklan, tanpa pembelian, tanpa akun, tanpa internet. Tidak ada fitur yang perlu dihapus. Yang perlu dijaga:

1. **Opsi biner dan penipuan lain tetap berupa cerita**, bukan permainan tebak harga yang bisa dimainkan. Jika ada permainan tebak naik/turun dengan imbalan tetap, game bisa dianggap memuat **simulasi judi**: rating naik ke 18+ di Indonesia (IGRS) dan R18+ di Australia.
2. **Konten Depresi tetap tanpa penggambaran menyakiti diri sendiri.** Pada April 2026 Google menurunkan game visual novel terkenal dari Play Store karena penggambaran menyakiti diri. Prinsip 2 di `docs/PEDOMAN_KONTEN_SENSITIF.md` adalah pengaman utamanya.
3. **Tanpa merek layanan keuangan nyata** (broker, bursa kripto, pinjol, bank) dan tanpa tautan ke layanan keuangan.
4. **Isian Play Console dijawab jujur** dan diperbarui setiap kali konten berubah (rating wajib diulang bila konten berubah).

Yang wajib dikerjakan di M7 (teknis): **export AAB lewat Gradle**, **upload keystore**, **uji tertutup 12 penguji selama 14 hari** (akun pengembang pribadi baru), ikon adaptif, grafis toko, dan kebijakan privasi di URL publik.

---

## 2. Kebijakan konten Google Play

| Kebijakan | Berlaku untuk game ini? | Status | Catatan |
|:--|:--|:--|:--|
| **Layanan keuangan** (Financial Services) | Tidak, karena tidak ada layanan keuangan sungguhan. Bagian rawan: aplikasi yang "memungkinkan pengguna memperdagangkan opsi biner" dilarang | ✅ | Opsi biner hanya muncul di event penipuan (`binary_option_flex`) dengan hasil pasti rugi; tidak ada tombol tebak harga. Tanpa tautan ke broker/pinjol/bursa nyata. Izin hanya getar (alat bantu pinjaman dilarang meminta izin kontak/lokasi) |
| **Deklarasi fitur keuangan** (Financial features declaration) | **Wajib untuk semua aplikasi** | ⬜ | Jawaban: "Aplikasi saya tidak menyediakan fitur keuangan". Pilihan di formulir semuanya layanan nyata (perdagangan saham, bursa kripto, pinjaman, paylater). ⚠️ Google tidak punya panduan khusus untuk simulasi; dukung dengan kata "simulasi, uang fiktif" di halaman toko |
| **Judi uang asli / simulasi judi** | Tidak ada judi uang asli. Leverage di pasar simulasi = simulasi investasi, bukan taruhan kasino | ✅ | Kuesioner rating: "simulasi judi: tidak". Kata "judi" hanya muncul sebagai peringatan ("itu judi berkedok trading"). ⚠️ Jika kuesioner menanyakan **referensi** judi, jawab jujur "ya, sebagai peringatan" (bisa memberi PEGI 12) |
| **Kesehatan** (Health Content & Services) + **Deklarasi aplikasi kesehatan** | Deklarasi wajib untuk semua aplikasi; kebijakan isinya berlaku untuk aplikasi yang memakai data kesehatan atau berisi informasi kesehatan yang salah | ✅ | Jawaban deklarasi: "Aplikasi saya tidak menyediakan fitur kesehatan". Status kesehatan & Depresi adalah mekanik permainan. Teks kesehatan di game sesuai konsensus medis (pemeriksaan rutin, BPJS, istirahat, konseling) |
| **Kekerasan, menyakiti diri, bunuh diri** | Ya: tema kematian & depresi | ✅ | Tidak ada penggambaran menyakiti diri atau bunuh diri (diperiksa `test_content`: daftar kata terlarang). Kematian non-grafis, selalu didahului peringatan |
| **Peristiwa sensitif** (Sensitive Events) | Tidak, karena tidak ada tragedi nyata | ✅ | Bencana di event (banjir, DBD) bersifat umum dan edukatif |
| **Perilaku menipu & metadata** (Deceptive Behavior, Metadata) | Ya: game bertema uang | 🔧 | Tidak boleh ada klaim menyesatkan ("dapat uang", "pasti untung", "cuan beneran"), daftar kata kunci, peringkat "#1", atau logo OJK/BEI. Label "untuk hiburan" tidak membebaskan dari aturan ini. Disclaimer di game diperjelas (lihat bagian 5) |
| **Peniruan identitas & HKI** (Impersonation) | Ya: menyebut lembaga resmi | ✅ | Lembaga (OJK, BI, LPS, BPJS, BEI, Kemenkes) disebut untuk edukasi + klausul "tidak berafiliasi". Semua perusahaan, koin, dan tokoh fiktif. WhatsApp hanya disebut sebagai sarana komunikasi dalam cerita penipuan |
| **Konten blockchain** | Tidak, karena koin fiktif tanpa blockchain | ✅ | Tetap ikuti semangatnya: tidak mengagungkan "cuan dari trading" |
| **Kebijakan keluarga** (Families) | Hanya jika target audiens mencakup anak di bawah 13 | ✅ | Usulan target audiens 16+ (lihat bagian 3). Gaya gambar "Senja Cuan" tidak kekanak-kanakan |
| **Data pengguna & kebijakan privasi** | Wajib untuk semua aplikasi | ⬜ | Kebijakan privasi di URL publik (M7). Data safety: tidak ada data yang dikumpulkan atau dibagikan |

---

## 3. Isian Play Console (ringkas; draf lengkap di langkah 2)

| Isian | Jawaban usulan | Alasan |
|:--|:--|:--|
| Kebijakan privasi | URL publik dari `docs/kebijakan-privasi.md` | Wajib walau tidak mengumpulkan data |
| Iklan | Tidak ada iklan | Keputusan tanpa monetisasi |
| Akses aplikasi | Semua fitur bisa dipakai tanpa login | Tidak ada akun |
| Rating konten (IARC) | Lihat tabel di bawah | |
| Target audiens | **16-17 dan 18+** | Produk seperti leverage, kredit, dan kripto di dunia nyata untuk orang dewasa; menghindari kelompok 13-15 yang "dapat dianggap anak" di sebagian negara; selaras dengan perhatian PP Tunas pada anak di bawah 16 tahun. Tambahkan 13-15 hanya jika siswa SMP memang sasaran |
| Data safety | Tidak mengumpulkan & tidak membagikan data | Semua data lokal (SQLite di HP), tanpa internet. "Mengumpulkan" = mengirim data keluar dari perangkat |
| Fitur keuangan | Tidak menyediakan fitur keuangan | Simulasi, uang fiktif |
| Aplikasi kesehatan | Tidak menyediakan fitur kesehatan | Mekanik permainan, bukan layanan kesehatan |
| Aplikasi berita / pemerintah | Bukan | |

**Perkiraan jawaban kuesioner rating (IARC)** ⚠️ perkiraan, hasil akhir ditentukan sistem IARC:

| Topik | Jawaban | Isi game |
|:--|:--|:--|
| Kekerasan / darah | Tidak | Tidak ada adegan kekerasan ("darah" hanya di "demam berdarah" dan "tekanan darah") |
| Rasa takut / horor | Tidak | |
| Kematian | Ya, non-grafis | Karakter pemain meninggal karena usia lanjut atau sakit, dengan teks tenang tanpa gambar |
| Seksualitas | Tidak | |
| Simulasi judi | **Tidak** | Leverage = simulasi investasi; opsi biner hanya cerita peringatan |
| Referensi judi | Jawab jujur sesuai pertanyaan | Kata "judi" muncul sebagai peringatan di event penipuan & syarat penggunaan |
| Rokok, alkohol, narkoba | Tidak | Diperiksa `test_policy` |
| Bahasa kasar / humor kasar | Tidak | |
| Interaksi pengguna, berbagi lokasi, internet bebas | Tidak | Offline, tanpa akun |
| Pembelian digital | Tidak | |

Perkiraan hasil: ESRB E atau E10+, PEGI 3-7 (12 jika referensi judi atau kuota kuis mingguan dihitung), IARC umum 3+ atau 7+. ⚠️ Kriteria PEGI baru (Juni 2026): mekanik "kembali secara berkala untuk hadiah" bisa memberi PEGI 7, atau 12 jika hadiah hilang saat tidak kembali; kuota kuis 6 soal per minggu mungkin dihitung.

---

## 4. Teknis

| Syarat | Status | Rincian |
|:--|:--|:--|
| **Target API** (aplikasi baru wajib Android 16 / API 36 sejak 31 Agustus 2026) | ✅ | APK sekarang: target SDK 36, min SDK 24 (dicek dengan `aapt2 dump badging`). Bawaan Godot 4.7 sudah 36. ⚠️ Batas berikutnya kemungkinan API 37 sekitar Agustus 2027 |
| **Halaman memori 16 KB** (wajib untuk aplikasi target Android 15+) | ✅ | Semua library 64-bit selaras 16 KB (segmen PT_LOAD `align 0x4000`): `libgodot_android.so`, `libc++_shared.so`, `libgdsqlite...arm64.so` (godot-sqlite memperbaikinya sejak v4.6). Library di dalam APK juga rata 16 KB |
| **Izin** | ✅ | Hanya `VIBRATE`. Godot tidak menambah `INTERNET` di export rilis (hanya untuk deploy satu klik/debug jarak jauh). Dijaga `test_policy` |
| **Format AAB** (wajib untuk aplikasi baru) | ⬜ M7 | Godot hanya bisa membuat AAB dengan **Use Gradle Build**: pasang JDK 17 (editor sekarang memakai JDK 21; ⚠️ cek kecocokan), Android SDK (build-tools 36.1.0 & platform 36 sudah ada), lalu **Project > Install Android Build Template** (folder `android/` sudah di `.gitignore`), aktifkan Gradle, pilih format AAB. Build pertama butuh internet (Gradle mengunduh dependensi). godot-sqlite ikut otomatis lewat `.gdextension` |
| **Upload keystore** & Play App Signing | ⬜ M7 | Buat keystore unggah sendiri (RSA 2048, simpan di luar repo, misalnya `%USERPROFILE%\keys\`, dan cadangkan). Password keystore & kunci harus sama (aturan Godot). Godot menyimpan password di `.godot/export_credentials.cfg` (sudah diabaikan git). Tambahkan `*.keystore`, `*.jks` ke `.gitignore`. Google membuat kunci penandatanganan aplikasi sendiri |
| **Uji tertutup akun pribadi baru** | ⬜ M7 | Minimal **12 penguji** ikut terus-menerus selama **14 hari**, lalu ajukan akses produksi (tinjauan ±7 hari). Siapkan minimal 3 minggu |
| **Verifikasi pengembang** | ⬜ M7 | Verifikasi identitas + perangkat (aplikasi Play Console di HP Android 10+). Aturan verifikasi pengembang untuk sideload berlaku di Indonesia sejak 30 September 2026; aplikasi yang didistribusikan lewat Play otomatis terdaftar. ⚠️ Membagikan APK di luar Play ke teman bisa terdampak |
| **Ikon adaptif** | ✅ | Pilihan A "Koin Rp": `assets/branding/icon_fg_432.png`, `icon_bg_432.png`, `icon_mono_432.png` (Android 13), `icon_192.png`, sudah dipasang di `export_presets.cfg`; boot splash `assets/branding/boot_splash.png` di latar #FDE3BF. Lihat `docs/KEBUTUHAN_ASET.md` bagian M7. |
| **Grafis toko** | ✅ | Semua di `assets/branding/source/` (folder ber-`.gdignore`, tidak ikut ke game): ikon 512x512 `play_store_512.png`; `store/feature_graphic_1024x500.png` (PNG 24-bit tanpa transparansi); 8 screenshot `store/screenshot_1..8_*.png` 1080x1920 PNG 24-bit, isi game sungguhan dengan judul singkat (urutan unggah = nomor file). |

---

## 5. Yang diubah di dalam game (Penutup v2 langkah 1) 🔧

| Bagian | Perubahan | Alasan |
|:--|:--|:--|
| **Pesan dukungan** (popup Depresi pertama & Profil > Bantuan & Dukungan) | Menyebut layanan **Healing119** Kementerian Kesehatan: 119 ekstensi 8 atau healing119.id (gratis, 24 jam). Versi Inggris mengarahkan ke **nomor darurat setempat** atau layanan krisis di negara pemain, lalu menyebut layanan Indonesia | Pedoman meminta nomor diverifikasi sebelum rilis. Versi Inggris sebelumnya hanya "hubungi 119", padahal di negara lain nomor itu bisa berbeda |
| **Disclaimer** (layar judul, Pasar, Profil) | "Simulasi edukasi, bukan saran keuangan. Uang, harga & perusahaan fiktif; aturan disederhanakan." Teks layar judul kini bisa turun ke baris kedua | Menegaskan semua isi fiktif. Teks lama di layar judul satu baris panjang yang membuat panel melebar |
| **Syarat Penggunaan** | Bagian baru: Instrumen berisiko tinggi (leverage, valas, kripto, komoditas; cek izin OJK/Bappebti), Dana kelolaan (di dunia nyata wajib izin OJK; ujian WMI di game bukan sertifikasi resmi), Kesehatan, penuaan, dan kematian (bukan saran medis + Healing119); "Bukan perjudian" menyebut opsi biner sebagai contoh penipuan; Kontak OJK 157 untuk cek legalitas; BEI & Kemenkes di daftar "tidak berafiliasi" | Fitur v2 (leverage, valas, dana kelolaan, kematian, depresi) belum tercakup di syarat versi v1.5 |
| **Kebijakan Privasi** (game & `docs/kebijakan-privasi.md`) | Tanggal 19 Oktober 2026, menyebut rekor skor warisan; versi Play Store menambah catatan instrumen berisiko & tema kesehatan | Data pemain baru di v2b (rekor skor warisan) |
| **Teks lama "usia 60"** | Layar judul: "Dari gaji pertama sampai masa tua". Petunjuk tujuan di Profil: bisa terus bermain sampai masa tua untuk mengejar skor warisan | Sejak v2b hidup berlanjut setelah pensiun; teks lama menyebut permainan berakhir di usia 60 |
| **Soal kuis** | Penjelasan "Short berarti bertaruh harga turun" → "mengambil posisi yang untung jika harga turun" | Menjaga konten bebas istilah taruhan |

**Uji otomatis `test_policy`** (38 pemeriksaan) menjaga agar jawaban isian di atas tetap benar saat konten bertambah:
- tanpa merek layanan keuangan nyata, tanpa simulasi judi (kasino, lotre, taruhan), tanpa rokok/alkohol/narkoba, tanpa tautan luar selain healing119.id dan lisensi;
- event penipuan: ikut dengan membayar tidak pernah untung bersih, uang yang langsung cair (mis. pinjol ilegal) selalu disusul akibatnya, selalu ada pilihan aman; opsi biner tanpa undian hasil;
- disclaimer, pesan dukungan (id & en), peringatan leverage, catatan izin OJK di dana kelolaan;
- isi Syarat Penggunaan, tanggal syarat & privasi (game dan Play Store) sama;
- izin export hanya getar, tanpa izin kustom, arm64 saja.

---

## 6. Regulasi Indonesia ⚠️

| Aturan | Isi | Dampak untuk Cuan Quest | Usulan |
|:--|:--|:--|:--|
| **PSE Lingkup Privat** (Permenkominfo 5/2020) | Penyelenggara aplikasi daring (termasuk game) wajib mendaftar sebelum layanan dipakai | Game sepenuhnya offline, jadi bisa dianggap di luar cakupan. Namun aturan klasifikasi game (di bawah) meminta penerbit terdaftar sebagai PSE lewat OSS. Google Play tidak memintanya | Risiko langsung rendah. Pertimbangkan NIB (OSS) + tanda daftar PSE (tanpa biaya) sebelum menambah iklan/pembelian di v3 |
| **IGRS, klasifikasi game** (Permenkominfo 2/2024) | Penerbit wajib mengklasifikasi game sendiri (3+, 7+, 13+, 15+, 18+) dan menampilkannya; batas penyesuaian ±Januari 2026 | **Ditangguhkan sejak April 2026**; selama penangguhan Komdigi tidak memblokir game tanpa rating. Reaktivasi ditargetkan 2026, tanggal belum diumumkan. IGRS anggota IARC | Isi kuesioner IARC dengan jujur; pantau igrs.id. Hindari simulasi judi (otomatis 18+) |
| **OJK** | Mengatur penyedia layanan keuangan nyata | Tidak ada aturan yang mewajibkan izin untuk konten edukasi fiktif. Yang perlu dihindari: kesan didukung OJK, meniru broker/pinjol nyata, rekomendasi efek nyata | Sudah dipenuhi (klausul tidak berafiliasi, semua fiktif). Opsi biner hanya digambarkan negatif |
| **PP Tunas** (PP 17/2025, berlaku penuh 28 Maret 2026) | PSE yang dapat diakses anak wajib menilai profil risikonya | Belum jelas berlaku untuk game offline kecil | Target audiens 16+ mengurangi risiko |

---

## 7. Sumber

Google Play & Android:
- Layanan keuangan: https://support.google.com/googleplay/android-developer/answer/9876821
- Deklarasi fitur keuangan: https://support.google.com/googleplay/android-developer/answer/13849271
- Deklarasi aplikasi kesehatan: https://support.google.com/googleplay/android-developer/answer/14738291
- Konten & layanan kesehatan: https://support.google.com/googleplay/android-developer/answer/16679511
- Kekerasan & peristiwa sensitif: https://support.google.com/googleplay/android-developer/answer/9878810
- Judi uang asli & simulasi: https://support.google.com/googleplay/android-developer/answer/9877032
- Rating konten (IARC): https://support.google.com/googleplay/android-developer/answer/188189 , https://support.google.com/googleplay/android-developer/answer/9898843
- Target audiens & kebijakan keluarga: https://support.google.com/googleplay/android-developer/answer/9867159 , https://support.google.com/googleplay/android-developer/answer/9893335
- Metadata & perilaku menipu: https://support.google.com/googleplay/android-developer/answer/9898842 , https://support.google.com/googleplay/android-developer/answer/9888077
- Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Target API: https://developer.android.com/google/play/requirements/target-sdk
- Halaman memori 16 KB: https://developer.android.com/guide/practices/page-sizes
- Uji tertutup akun pribadi baru: https://support.google.com/googleplay/android-developer/answer/14151465
- Verifikasi pengembang: https://developer.android.com/developer-verification/guides
- Play App Signing: https://support.google.com/googleplay/android-developer/answer/9842756
- Grafis toko: https://support.google.com/googleplay/android-developer/answer/9866151
- Export Android & Gradle di Godot 4.7: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html , https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html
- godot-sqlite 16 KB: https://github.com/2shady4u/godot-sqlite/issues/219

Rating:
- ESRB: https://www.esrb.org/ratings-guide/ · PEGI: https://pegi.info/what-do-the-labels-mean · Australia (simulasi judi R18+): https://www.classification.gov.au/about-us/media-and-news/news/new-mandatory-minimum-classifications-gambling-games-content
- Contoh penegakan (game diturunkan April 2026): https://gamedeveloper.com/business/doki-doki-literature-club-removed-from-google-play-over-depiction-of-sensitive-themes

Indonesia:
- Healing119 (Kemenkes): https://kesprimkom.kemkes.go.id/assets/uploads/contents/others/FAQ_Cegah_Bunuh_Diri%2C_Dukung_Kesehatan_Jiwa__Kenali_Layanan_Healing119.id.pdf , https://infopublik.id/kategori/layanan-publik/952502/healing119id-layanan-kesehatan-mental-24-jam-teman-bicara-yang-siap-mendengar
- Permenkominfo 5/2020 (PSE): https://api-law.crpg.info/peraturan/permenkominfo/5/2020/pasal/2
- Permenkominfo 2/2024 (klasifikasi game): https://api-law.crpg.info/peraturan/permenkominfo/2/2024/pasal/4
- Penangguhan & reaktivasi IGRS: https://www.antaranews.com/berita/5686135/kemkomdigi-pastikan-reaktivasi-igrs-ditargetkan-rampung-2026
- OJK tentang opsi biner: https://www.ojk.go.id/id/berita-dan-kegiatan/siaran-pers/Pages/SWI-Minta-Masyarakat-Waspadai-Penawaran-Binary-Option-dan-Broker-Ilegal.aspx
- PP Tunas: https://selular.id/2026/04/dalam-3-bulan-platform-media-sosial-dan-gim-wajib-patuhi-pp-tunas/
