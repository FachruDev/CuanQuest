# Kebutuhan Suara Cuan Quest

Daftar semua musik, jingle, dan efek suara yang dibutuhkan game, lengkap dengan **kapan bunyi itu muncul**, **seperti apa bunyinya**, dan **aturan teknisnya**, supaya bisa langsung dibuat atau dicari tanpa menebak-nebak. Dokumen ini pasangan dari `docs/KEBUTUHAN_ASET.md` (gambar & font).

- **Terakhir diperbarui:** 21 Oktober 2026 (10 musik latar masuk `assets/audio/music/` sebagai OGG; sebelumnya: versi pertama)
- **Kondisi sekarang:** **10 musik latar sudah ada** (OGG, total ±21 MB) tetapi **belum diputar di game**: pemutar musik, bus audio, dan sakelar musik belum dibuat. Lima efek suara (`click`, `coin`, `success`, `fail`, `alert`) masih dibuat lewat kode dari gelombang sinus di `scripts/autoload/sfx.gd`; jingle & efek suara berkas belum ada.
- **Master WAV** disimpan di **luar repo**: `Documents/cuan-quest-audio-master/` (`latar/`, `jingle/`). Folder `all-music/` di proyek diabaikan git. File di `assets/audio/` adalah hasil konversi dari master itu.
- **Tanda:** ✅ sudah ada · ⬜ dibutuhkan · 🔁 sementara memakai bunyi sintetis (game tetap jalan) · ⛔ sengaja **tanpa bunyi**
- **Prioritas:** **P1** wajib untuk rilis pertama · **P2** disarankan · **P3** opsional (pemanis)

## Ringkasan

| Kelompok | Jumlah file | P1 | Status |
|:--|:--|:--|:--|
| Musik latar | 10 | 5 | ✅ 10/10 file (belum diputar di game) |
| Jingle (musik pendek 1-4 detik) | 16 | 7 | ⬜ |
| Efek suara antarmuka (UI) & kuis | 18 | 9 | 🔁 sebagian (klik, benar/salah) |
| Efek suara uang, aset & aktivitas | 16 | 5 | 🔁 sebagian (koin) |
| Efek suara event & peringatan | 8 | 3 | 🔁 sebagian (alert) |
| Suasana latar (ambience) | 4 | 0 | ⬜ opsional |
| **Total** | **72 file** | **29** | |

Target ukuran semua audio: **sekitar 15-20 MB** (APK sekarang ±32 MB). Musik mengambil hampir semuanya (±1,5 MB per lagu 2 menit); semua efek suara pendek totalnya cukup 1-2 MB.

---

## 1. Arah Suara: "Senja Cuan"

Suara harus terasa satu keluarga dengan tampilan: **hangat, santai, sedikit nostalgia, dengan bumbu Indonesia**.

| Aspek | Pilihan |
|:--|:--|
| Genre musik | **Lo-fi / city pop** yang hangat (tempo 70-100 BPM), instrumental tanpa vokal |
| Instrumen utama | Electric piano (Rhodes), gitar akustik/clean, bass lembut, drum brush atau beat lo-fi pelan |
| Bumbu Indonesia | **Sedikit saja**: ukulele ala keroncong (cak/cuk), denting mirip gamelan/bonang atau angklung, suling. Jadi warna, bukan pusat lagu |
| Palet efek suara | **Kayu & logam lembut**: marimba, kalimba, xylophone, bel kecil, koin, kertas, stempel. Semua efek suara memakai palet ini agar terdengar serumpun |
| Nada dasar | Pilih **satu kunci nada** untuk lagu tema (saran: **D mayor**) dan buat semua jingle di kunci yang sama, supaya jingle tidak "bertabrakan" dengan musik yang sedang main |

### Motif "Cuan" (melodi pengenal game)

Buat satu motif pendek 4 nada yang **bentuknya seperti grafik saham naik**: naik, turun sedikit, lalu naik lebih tinggi. Contoh dalam do-re-mi: **do - mi - re - sol** (1-3-2-5). Bentuk ini sama dengan jalur bukit berbentuk grafik di layar judul.

Motif ini dipakai berulang: di lagu tema, diaransemen ulang di tiap bab hidup, dan dimainkan penuh di jingle kemenangan. Pemain akan mengenalinya tanpa sadar, seperti "nada khas" sebuah merek.

### Aturan yang tidak boleh dilanggar

1. **Bukan kasino.** Untung trading atau dapat uang **tidak boleh** berbunyi seperti jackpot, mesin slot, atau hujan koin. Ini penting karena game punya leverage, valas, dan contoh penipuan opsi biner. Kalau suara untung terasa seperti menang judi, game bisa terkesan mendorong judi, dan itu bisa jadi masalah di peninjauan Google Play (lihat `docs/RILIS_PLAY_STORE.md`).
2. **Rugi tidak diejek.** Tidak ada bunyi "wah-wah-wah" terompet, buzzer kuis TV, atau tawa. Rugi adalah bagian dari belajar; bunyinya cukup turun dan lembut.
3. **Pasar anjlok, musik tetap tenang.** Musik tidak berubah tegang saat harga jatuh. Pesan tersiratnya: jangan panik jual.
4. **Konten sensitif mengikuti `docs/PEDOMAN_KONTEN_SENSITIF.md`** (lihat bagian 7): kematian karakter **tanpa bunyi dan tanpa getar**, event kesehatan mental tampil tenang tanpa bunyi peringatan.
5. **Tidak melelahkan.** Bunyi yang sering muncul (klik tombol, ganti tab) harus paling pelan dan paling pendek. Pemain bisa menekan ratusan tombol per sesi.

---

## 2. Aturan Teknis

| Jenis | Format | Sample rate | Kanal | Durasi | Kekerasan (loudness) |
|:--|:--|:--|:--|:--|:--|
| Efek suara | **WAV 16-bit** (atau OGG bila >1 detik) | 44,1 kHz | **Mono** | 0,03-1 detik | Puncak maksimal -3 dBFS, tanpa clipping |
| Jingle | **OGG Vorbis** | 44,1 kHz | Stereo | 1-4 detik | Setara musik, boleh sedikit lebih menonjol |
| Musik latar | **OGG Vorbis** kualitas ±96-112 kbps | 44,1 atau 48 kHz | Stereo | 1,5-3 menit per lagu | Sekitar -18 LUFS, puncak maksimal -1 dBFS |
| Suasana latar | OGG Vorbis | 44,1 kHz | Stereo | 30-60 detik per loop | Sangat pelan, di bawah musik |

**Format lain:**
- **M4A/AAC tidak bisa dipakai**: Godot tidak bisa mengimpornya. Ubah dulu ke OGG atau WAV (Audacity bisa membuka M4A setelah memasang pustaka FFmpeg yang ditawarkannya).
- **MP3 bisa dipakai, tapi pilihan kedua**: biasanya ada hening sangat pendek di awal dan akhir file. Akibatnya efek suara terasa sedikit telat, dan musik bisa "tersendat" di titik loop. Jika sumbernya hanya MP3 (misalnya unduhan atau hasil musik AI), boleh dipakai untuk musik/jingle pada 128-192 kbps, tapi dengarkan titik loop-nya di Godot. Lebih baik ubah sekali ke OGG.
- Simpan **master WAV** (kualitas penuh) dari setiap lagu dan efek suara buatan sendiri, lalu ekspor OGG dari master itu. Hindari konversi berulang antarformat terkompresi (MP3 → OGG → ...), karena kualitasnya turun setiap kali.
- Ekspor OGG dari Audacity: kualitas **3-4** (sekitar 112-128 kbps) untuk musik.

**Detail penting:**

- **Efek suara langsung mulai.** Potong hening di awal file (maksimal 10 ms) supaya terasa responsif saat tombol ditekan. Ekor bunyi diberi fade-out pendek agar tidak terdengar "klik" di akhir.
- **Musik boleh berupa lagu utuh** (dengan intro dan fade-out di akhir), seperti 10 lagu yang sudah ada. Lagu-lagu ini diputar sebagai **playlist dengan crossfade**, bukan diulang satu per satu, jadi tidak perlu dibuat seamless loop. Yang penting: potong hening di awal dan akhir. Hanya lagu yang memang diputar sendirian terus-menerus yang perlu seamless loop (ujung menyambung ke awal tanpa jeda; bila ada intro, catat detik awal bagian loop untuk pengaturan impor `loop_offset` Godot).
- **Cek di speaker HP**, bukan hanya headphone. Speaker HP hampir tidak bisa memutar nada sangat rendah (bass di bawah ±150 Hz), jadi bunyi penting jangan hanya mengandalkan bass.
- **Semua instrumental, tanpa vokal atau lirik.** Vokal mengganggu saat pemain membaca teks dan tidak perlu diterjemahkan.
- **Variasi untuk bunyi yang sering muncul.** Bunyi klik dibuat 3 versi yang sedikit berbeda; game akan memilih acak supaya tidak terdengar seperti mesin.

### Lokasi & nama file

```
assets/audio/
  music/      title_theme.ogg, chapter_early_1.ogg, ...
  jingles/    jingle_goal.ogg, jingle_dream.ogg, ...
  sfx/        ui_click_1.wav, trade_buy.wav, ...
  ambience/   amb_kos.ogg, ...
```

- Nama file **persis** seperti kolom **ID** di tabel bawah, huruf kecil `snake_case`. Kode akan mencari file dengan nama ini; kalau belum ada, game memakai bunyi sintetis yang sekarang (🔁), jadi file boleh dibuat bertahap.
- Catat sumber dan lisensi setiap file dari luar di `assets/LICENSES.md`. Jika lisensinya **CC BY** (wajib mencantumkan nama), nama pembuat juga harus ditambahkan ke **Lisensi Pihak Ketiga** di `data/legal.json`.

---

## 3. Musik Latar

Musik berganti mengikuti **bab hidup** pemain (`data/life.json`: `early`, `build`, `peak`, `retire`). Semua lagu bab adalah **variasi dari lagu tema** (motif "Cuan" yang sama, aransemen berbeda), jadi game terasa satu cerita yang ikut menua bersama karakter. Tiap bab punya 2 lagu yang diputar bergantian agar tidak bosan; lagu kedua (P2) boleh menyusul.

| ID | Kapan diputar | Tempo | Seperti apa | Prio |
|:--|:--|:--|:--|:--|
| `title_theme` | Layar judul, Game Baru, Tutorial | 90-96 BPM | **Lagu tema.** City pop senja: Rhodes hangat, gitar clean berirama funky ringan, bass bergerak, drum santai. Motif "Cuan" dimainkan jelas di awal (misalnya oleh synth lead lembut atau suling). Perasaan: "sore yang cerah, masa depan menunggu". | P1 |
| `chapter_early_1` | Bab **Awal Karier** (usia 22-29) | 96-100 BPM | **Ceria dan ringan, sedikit sederhana**: gitar akustik + ukulele ala keroncong, perkusi tangan (shaker, cajon), melodi motif dengan suling atau glockenspiel. Terasa seperti anak kos yang baru mulai kerja: semangat, uang pas-pasan, tapi optimis. Aransemen tipis, tidak ramai. | P1 |
| `chapter_early_2` | Bab Awal Karier, bergantian | 96-100 BPM | Varian lagu di atas dengan bagian berbeda (misalnya lebih banyak kalimba). | P2 |
| `chapter_build_1` | Bab **Membangun** (30-44) | 90-95 BPM | **Penuh dan percaya diri**: band city pop lengkap, Rhodes + bass + drum, sedikit brass/synth pad. Motif muncul di tengah lagu. Perasaan: "sibuk membangun hidup, kerja, keluarga, rumah". | P1 |
| `chapter_build_2` | Bab Membangun, bergantian | 90-95 BPM | Varian: lebih banyak gitar, groove sedikit berbeda. | P2 |
| `chapter_peak_1` | Bab **Puncak** (45-59) | 82-88 BPM | **Hangat dan matang**: tempo sedikit turun, aransemen kaya (strings lembut, saksofon atau flugelhorn, piano). Perasaan: "golden hour, hasil kerja keras mulai terasa". | P1 |
| `chapter_peak_2` | Bab Puncak, bergantian | 82-88 BPM | Varian: lebih jazzy. | P2 |
| `chapter_retire_1` | Bab **Pensiun** (60+) | 68-75 BPM | **Pelan dan nostalgia**: piano akustik solo atau piano + gitar nilon, sedikit strings, bunyi denting bel/gamelan sangat lembut. Motif dimainkan pelan seperti mengenang. Perasaan: "malam tenang di teras rumah, melihat ke belakang dengan bangga". | P1 |
| `chapter_retire_2` | Bab Pensiun, bergantian | 68-75 BPM | Varian: lebih sederhana (gitar nilon solo). | P2 |
| `end_theme` | Layar akhir saat **bangkrut** (dan **menang** jika pemain memilih "Selesai sekarang") | 70-80 BPM | Versi pelan dan reflektif dari lagu tema (piano + pad), tidak sedih berlebihan, berakhir dengan nada yang memberi harapan ("coba lagi"). Boleh tidak loop (sekitar 60-90 detik, lalu hening). Untuk akhir hidup karakter lihat bagian 7. | P2 |

**Perilaku musik (untuk implementasi):**
- Lagu tiap bab diputar sebagai **playlist** (lagu 1 → lagu 2 → lagu 1 ...) dengan **crossfade 2-3 detik**, sehingga fade-out di akhir tiap lagu menjadi transisi. `title_theme` dan `end_theme` diulang sendiri dengan crossfade dari ujung ke awal. Ganti lagu juga dengan crossfade, tidak berhenti mendadak.
- Saat ganti bab, lagu bab lama memudar, jingle bab baru (`jingle_chapter`) bermain, lalu lagu bab baru masuk.
- Saat popup tenang atau momen sensitif muncul, musik **diredam** (turun sekitar 8-10 dB), lalu naik lagi setelah popup ditutup.
- Musik berhenti saat aplikasi masuk ke latar belakang dan lanjut saat kembali.
- Pengaturan baru: **sakelar musik + volume musik** terpisah dari efek suara.

---

## 4. Jingle (Musik Pendek)

Jingle adalah "stempel musik" 1-4 detik untuk momen penting. Buat di **kunci nada yang sama** dengan lagu tema, dan sebisa mungkin pakai potongan motif "Cuan". Saat jingle bermain, musik latar diredam sebentar.

| ID | Kapan | Durasi | Seperti apa | Prio |
|:--|:--|:--|:--|:--|
| `jingle_goal` | **Tujuan besar tercapai**: kekayaan Rp1 miliar atau bebas finansial (popup + confetti) | 3-4 dtk | **Jingle terbesar di game.** Motif "Cuan" lengkap dimainkan meriah: brass hangat atau synth cerah + drum fill + denting bel di akhir. Megah tapi tetap senada lo-fi, bukan fanfare orkestra perang. Bukan bunyi jackpot. | P1 |
| `jingle_dream` | **Impian tercapai** (motor, rumah, umrah, dll.) | 2-3 dtk | Hangat dan menyentuh: arpeggio kalimba/marimba naik + akor piano lembut. Perasaan: "akhirnya kesampaian". | P1 |
| `jingle_level_up` | Naik level XP (toast) | 1-1,5 dtk | Tiga nada naik cepat (glockenspiel/marimba) + sedikit kilau. Ringan, karena cukup sering. | P1 |
| `jingle_unlock` | **Instrumen baru terbuka** (tahap 2-7) | 2 dtk | Bunyi "pintu terbuka": glissando harpa/kalimba naik + akor terbuka. Kesan: dunia baru tersedia. | P1 |
| `jingle_month_up` | Laporan bulanan: kekayaan **naik** (setelah grafik selesai digambar) | 1-1,5 dtk | Dua-tiga nada naik, lembut (marimba). Puas, tidak heboh. Muncul **setiap bulan**, jadi harus sangat enak didengar berulang. | P1 |
| `jingle_month_down` | Laporan bulanan: kekayaan **turun** | 1-1,5 dtk | Dua nada **netral** (misalnya turun lalu kembali ke nada tengah). Bukan sedih, bukan gagal: "tidak apa-apa, lanjut". | P1 |
| `jingle_job` | Tawaran kerja datang / diterima kerja | 1,5-2 dtk | Ceria dan ringan: gitar + bel kecil. | P2 |
| `jingle_promotion` | Naik jabatan (toast) | 1,5-2 dtk | Seperti `jingle_job` tapi sedikit lebih megah (tambah brass kecil). | P2 |
| `jingle_graduate` | Lulus kuliah (D3/S1/S2) | 2 dtk | Bel/chime + akor cerah. Sedikit seremonial. | P2 |
| `jingle_achievement` | Pencapaian (lencana) terbuka | 1,5 dtk | Kilau "sparkle" + dua nada bel. Terasa seperti stiker ditempel. | P2 |
| `jingle_chapter_build` / `jingle_chapter_peak` | **Bab hidup baru** dimulai: Membangun (usia 30) / Puncak (usia 45) | 3 dtk | Motif "Cuan" dimainkan **dengan instrumen bab baru** (band city pop untuk Membangun, strings + saksofon untuk Puncak). Menjembatani lagu bab lama ke lagu bab baru. Bab Pensiun memakai `jingle_retire`. | P2 |
| `jingle_retire` | **Pensiun** (usia 60) | 3-4 dtk | Hangat, haru, bangga: piano + strings lembut memainkan motif pelan. Seperti akhir film keluarga. Bukan meriah. | P2 |
| `jingle_annual` | Laporan tahunan (setiap Januari) | 1,5-2 dtk | Bunyi buku dibuka + dua nada lembut. Netral, seperti membuka rapor. | P3 |
| `jingle_win` | Layar akhir **menang** (pemain memilih "Selesai sekarang" setelah tujuan tercapai) | 3-4 dtk | Versi lebih panjang dan tenang dari `jingle_goal`, ditutup akor penuh. | P2 |
| `jingle_bankrupt` | Layar akhir **bangkrut** (permainan berakhir) | 2-3 dtk | **Serius tapi tidak mengejek**: 3-4 nada turun pelan (piano), lalu **satu nada terakhir yang naik sedikit** sebagai tanda harapan ("bisa mulai lagi"). Tetap disertai getar 300 ms seperti sekarang. Tidak ada efek "game over" arkade. | P1 |

---

## 5. Efek Suara Antarmuka (UI)

| ID | Kapan | Durasi | Seperti apa | Prio |
|:--|:--|:--|:--|:--|
| `ui_click_1` / `_2` / `_3` | **Setiap tombol** ditekan (otomatis untuk semua tombol) | 30-60 ms | Ketukan kayu lembut, seperti ujung pensil mengetuk meja kayu atau satu nada marimba sangat pendek. Ketiga versi beda tipis tinggi nadanya. **Bunyi paling pelan di game.** Menggantikan `click` 🔁. | P1 |
| `ui_tab` | Pindah tab bawah (Beranda, Pasar, Portofolio, Karier, Profil) dan segmen dalam layar | 80-120 ms | Bunyi kertas dibalik halus / "swish" kecil. Dipakai menggantikan klik untuk tombol tab. | P2 |
| `ui_popup_open` | Popup biasa muncul (mengiringi animasi pop-in) | 100-150 ms | "Pop" lembut seperti tutup toples kecil atau gelembung. Netral. | P1 |
| `ui_popup_close` | Popup ditutup | 80-120 ms | Versi terbalik/turun dari `ui_popup_open`, lebih pelan. | P2 |
| `ui_confirm` | Popup **konfirmasi** (berhenti kerja, daftar kuliah, jual aset, berhenti kuliah) | 150 ms | Ketukan netral dua kali, sedikit "bertanya". **Catatan:** sekarang popup konfirmasi ikut berbunyi `success`, padahal "Yakin berhenti kerja?" bukan kabar gembira. | P1 |
| `ui_denied` | Aksi ditolak: energi kurang, riset gagal, syarat belum terpenuhi, save gagal dimuat | 150-250 ms | "Bonk" kayu rendah yang lembut, dua nada turun pendek. Menggantikan `fail` 🔁 untuk penolakan. Bukan buzzer. | P1 |
| `ui_toggle_on` / `ui_toggle_off` | Sakelar pengaturan (suara, getar, format angka) | 80 ms | "Klik" mekanis kecil; versi on sedikit lebih tinggi daripada off. | P3 |
| `ui_stepper_up` / `ui_stepper_down` | Tombol −/+ 5% di Rencana Gaji, pilihan nominal | 40-60 ms | Tik kecil; yang naik sedikit lebih tinggi nadanya. Karena bisa ditekan cepat berkali-kali, harus sangat pendek. | P2 |
| `toast` | Notifikasi pita di atas (target selesai, naik jabatan, beli kendaraan, dll.) | 300-400 ms | Dua nada bel kecil "ting-ting". Menggantikan `success` 🔁 pada toast. | P1 |
| `quiz_correct` | Jawaban kuis **benar** | 400-500 ms | Dua nada naik cerah (marimba + bel), seperti "ting-tong!". Menggantikan `success` 🔁 di kuis. | P1 |
| `quiz_wrong` | Jawaban kuis **salah** | 400 ms | Dua nada turun lembut (kayu), **bukan buzzer** acara kuis TV. Kesannya "coba lagi minggu depan". Menggantikan `fail` 🔁 di kuis. | P1 |
| `confetti_pop` | Saat confetti meledak (perayaan) | 300-500 ms | Party popper yang **lembut** + kertas beterbangan. Dimainkan bersama jingle perayaan. | P2 |
| `counter_tick` | Angka kekayaan berputar di laporan bulanan | 20-30 ms (diulang) | Tik halus seperti roda angka/odometer. Game memutarnya berulang selama angka berputar (±1,5 detik), jadi harus sangat pelan. | P3 |
| `chart_draw` | Grafik kekayaan digambar di laporan bulanan | 1,5 dtk | "Swish" naik halus seperti pensil menggores kertas. Dimainkan sekali saat animasi grafik. | P3 |

---

## 6. Efek Suara Uang, Aset & Aktivitas

| ID | Kapan | Durasi | Seperti apa | Prio |
|:--|:--|:--|:--|:--|
| `next_month` | Tombol **Lanjut** (ganti bulan) dan **+1 Tahun** saat pensiun | 300-500 ms | Bunyi **halaman kalender disobek/dibalik** + satu denting koin kecil. Tombol yang paling sering ditekan setelah klik biasa, jadi harus enak dan tidak keras. Menggantikan `coin` 🔁. | P1 |
| `trade_buy` | Beli aset (saham, reksa dana, kripto, emas, valas) dikonfirmasi | 250-400 ms | Satu-dua koin masuk ke dompet/celengan + "klik" stempel kecil. **Tenang**, tidak berdenting heboh. | P1 |
| `trade_sell` | Jual aset dikonfirmasi | 250-400 ms | Lembaran uang kertas dihitung singkat + klik. Bunyinya **sama saja** baik saat untung maupun rugi (angkanya sudah memberi tahu). | P1 |
| `order_set` | Stop loss / take profit disimpan | 200 ms | Klik "terkunci" seperti gembok kecil ditutup. | P3 |
| `research_done` | Riset rumor selesai (dasar/mendalam) | 400-600 ms | Halaman buku dibalik + "ting" kecil seperti ide muncul. Menggantikan `success` 🔁 di riset. | P2 |
| `activity_done` | Aktivitas bulanan berhasil (olahraga, kursus, kerja sampingan, dll.) | 300 ms | Centang yang memuaskan: satu nada marimba naik. Menggantikan `success` 🔁 di aktivitas. | P1 |
| `plan_saved` | Rencana gaji disimpan | 300 ms | Bunyi map/dokumen ditutup + nada lembut. | P2 |
| `dream_added` | Memilih impian baru | 400 ms | Kilau kecil "sparkle" seperti bintang. | P2 |
| `dream_deposit` | Menabung ke dana impian | 200-300 ms | Koin masuk celengan (satu koin). Menggantikan `coin` 🔁. | P2 |
| `loan_signed` | Pinjaman / kredit disetujui dan diambil | 400-600 ms | **Stempel kertas "dok!"** + pena menandatangani. Netral dan sedikit berat, agar terasa sebagai komitmen, bukan hadiah. Menggantikan `coin` 🔁 (koin membuat utang terasa seperti untung). | P1 |
| `loan_paid_off` | Pinjaman lunas | 600-800 ms | Stempel "LUNAS" + akor lega (dua nada naik). Memuaskan. | P2 |
| `buy_vehicle_motor` / `buy_vehicle_car` | Membeli motor / mobil | 0,8-1,2 dtk | Mesin dinyalakan singkat (starter + sedikit gas). Motor lebih ringan dan tinggi, mobil lebih berat. Pendek, tidak meraung. | P2 |
| `buy_property` | Membeli rumah/tanah | 0,8-1 dtk | Gemerincing kunci + pintu dibuka pelan. | P2 |
| `asset_sold` | Kendaraan terjual / properti dipasang dijual | 300-500 ms | Lembaran uang + klik, mirip `trade_sell` tapi sedikit lebih panjang. | P3 |
| `insurance_bought` | Membeli/ganti polis asuransi | 400 ms | Denting lembut seperti perisai kecil (bel kristal pelan). | P3 |

---

## 7. Event, Peringatan & Momen Sensitif

### Event kehidupan (126 event di `data/events/`)

Sekarang semua event (kecuali yang tenang) berbunyi `alert` + getar. Usulannya dibedakan menurut sifat event:

| ID | Kapan | Durasi | Seperti apa | Prio |
|:--|:--|:--|:--|:--|
| `event_open` | Event **biasa** muncul (tanpa `"bad": true`): sosial, karier, keuangan | 400-600 ms | "Ding-dong" lembut seperti notifikasi pesan atau bel pintu kecil. Mengundang, bukan mengagetkan. | P1 |
| `event_bad` | Event **buruk** (`"bad": true`, 39 event: sakit, kecelakaan, PHK, dll.) | 500-700 ms | Dua nada bel turun yang **serius tapi tidak panik** + getar pendek (seperti sekarang). Bukan sirene. Menggantikan `alert` 🔁. | P1 |
| `event_scam` | Event **penipuan** (kategori `scam`, 16 event) | 500-700 ms | Sama sifatnya dengan `event_open` tapi sedikit "janggal" (nada agak sumbang/miring), sebagai petunjuk halus "hati-hati". **Jangan lucu** dan jangan terlalu jelas, supaya pemain tetap belajar menilai sendiri. | P3 |
| `event_result_good` / `event_result_bad` | Hasil pilihan event ditampilkan | 300 ms | Satu nada naik (baik) / satu nada turun lembut (buruk). Sangat pelan. | P3 |
| ⛔ event tenang | Event `"quiet": true` (dukungan kesehatan mental) | — | **Tanpa bunyi dan tanpa getar** (pedoman, sudah berlaku sekarang). Musik diredam. | — |

### Peringatan

| ID | Kapan | Durasi | Seperti apa | Prio |
|:--|:--|:--|:--|:--|
| `warning` | Peringatan risiko: sebelum leverage pertama, **margin call**, peringatan dana kelolaan | 500-700 ms | Dua nada bel sedang, berulang sekali ("ting-ting... ting-ting"), seperti pengingat penting di HP. Tegas, bukan alarm. Menggantikan `alert` 🔁. | P1 |
| `warning_soft` | Tenggat impian terlewat, kas mulai menipis | 400 ms | Versi lebih pelan dan pendek dari `warning`. | P2 |
| `liquidation` | Posisi leverage **dilikuidasi** (di laporan bulanan) | 400-600 ms | "Dug" berat yang teredam (seperti pintu brankas ditutup) + nada rendah. Serius, agar risiko leverage terasa. Tidak dramatis. | P2 |

### Momen sensitif (wajib mengikuti `docs/PEDOMAN_KONTEN_SENSITIF.md`)

| Momen | Bunyi | Musik | Getar |
|:--|:--|:--|:--|
| **Karakter meninggal** (popup perpisahan + layar akhir "Perjalanan Hidup Selesai") | ⛔ **Tanpa bunyi** (pedoman prinsip 7, sudah berlaku sekarang) | Musik **memudar perlahan sampai hening** (±3 detik) saat popup perpisahan muncul; layar akhir hening | ⛔ Tidak ada |
| **Masa senja** (pemberitahuan usia 70+) | ⛔ Tanpa bunyi (popup tenang) | Diredam | Tidak ada |
| **Depresi** dimulai / event dukungan mental | ⛔ Tanpa bunyi (popup tenang) | Diredam | Tidak ada |
| **Kondisi kritis** (kesehatan di bawah 20) | `warning_soft` (bukan sirene, bukan detak jantung) | Diredam | Tidak ada |
| **Bertambah usia** (popup "Usia N Tahun") | `ui_popup_open` saja | Normal | Tidak ada |
| **Bangkrut** (game berakhir) | `jingle_bankrupt` | `end_theme` (P2) | 300 ms (seperti sekarang) |

> **Keputusan untuk kamu:** pedoman sekarang membuat layar akhir kematian **benar-benar hening**. Ada alternatif: memutar `end_theme` versi piano sangat pelan (tanpa jingle) di layar akhir kematian, agar terasa seperti penghormatan, bukan kekosongan. Ini mengubah pedoman prinsip 7, jadi **default dokumen ini tetap hening** sampai kamu memutuskan lain.

---

## 8. Suasana Latar (Opsional, P3)

Bunyi lingkungan yang sangat pelan di Beranda, mengikuti ilustrasi hunian. Hanya dibuat jika semua P1-P2 sudah selesai.

| ID | Hunian | Seperti apa |
|:--|:--|:--|
| `amb_kos` | Menumpang, Kos | Jalan kota sore: motor lewat sesekali dari jauh, suara anak-anak samar |
| `amb_city` | Kontrakan, Apartemen, Studio | Kota di sore hari dari balik jendela, AC berdengung halus |
| `amb_house` | Rumah sendiri | Burung sore, angin di pohon, sesekali tukang bakso lewat dari jauh (bumbu lokal, opsional) |
| `amb_retire` | Bab Pensiun | Malam tenang: jangkrik, angin pelan |

---

## 9. Getar (Sudah Ada)

Getar tetap dipakai seperti sekarang dan mengikuti sakelar Getar di Pengaturan:

| Momen | Durasi |
|:--|:--|
| Event biasa & buruk (bukan event tenang) | 80 ms |
| Perayaan (impian, tujuan, bab baru, lulus, tawaran kerja, tahap baru) | 80 ms |
| Bangkrut | 300 ms |
| Kematian, event tenang, masa senja | ⛔ Tidak ada |

---

## 10. Cara Membuat atau Mencari Suara

### Membuat sendiri (gratis)

| Alat | Untuk apa |
|:--|:--|
| **Audacity** (gratis) | Memotong, menormalkan kekerasan, fade-out, ekspor WAV/OGG |
| **Rekaman HP** | Banyak efek suara terbaik justru benda sungguhan: koin, kertas dibalik, kalender disobek, stempel, kunci, ketukan sendok kayu. Rekam di ruangan sunyi, lalu bersihkan di Audacity |
| **Spitfire LABS** (plugin gratis) | Piano lembut, strings, dan instrumen hangat untuk musik/jingle |
| DAW apa saja (BandLab, LMMS, Reaper versi uji, FL Studio, dll.) | Menyusun musik dan jingle |
| jsfxr / ChipTone | Efek suara cepat, **tapi gayanya 8-bit**; tidak cocok untuk "Senja Cuan" kecuali sebagai bahan yang diolah lagi |

### Sumber gratis/bebas royalti

| Sumber | Lisensi | Catatan |
|:--|:--|:--|
| **Kenney** (Interface Sounds, UI Audio, Music Jingles, Impact Sounds) | CC0 | Paling cocok untuk efek suara UI dan jingle sementara. **Hindari paket "Casino"** (aturan nomor 1) |
| **Sonniss GDC Game Audio Bundle** | Bebas royalti, boleh komersial | Ribuan efek suara berkualitas tinggi (kertas, koin, mesin, pintu) |
| **freesound.org** | Campuran | Pakai filter **CC0**. CC BY boleh (catat nama pembuat). **CC BY-NC tidak boleh** (game ini bisa jadi komersial) |
| **OpenGameArt** | Campuran | Filter CC0 |
| Pixabay Music / Sound Effects | Lisensi Pixabay | Boleh komersial tanpa atribusi, tapi bukan CC0; baca syaratnya |
| Komposer lokal Indonesia | Sesuai kontrak | Pilihan terbaik untuk lagu tema; minta hak pakai di game termasuk versi komersial |
| Musik AI (Suno, Udio) | Sesuai paket | Hak komersial biasanya hanya di paket berbayar; cek syaratnya sebelum dipakai di versi Play Store |

**Hindari** lagu "no copyright lofi" dari YouTube yang asal-usulnya tidak jelas.

### Contoh brief siap pakai

Bisa dikirim ke komposer atau dipakai sebagai bahan prompt:

> **title_theme** — Instrumental city pop / lo-fi, 92 BPM, D major, 2 minutes, seamless loop, no vocals. Warm Rhodes electric piano, clean funky guitar, round bass, laid-back drums. Light Indonesian touch: a soft suling (bamboo flute) or gamelan-like bell plays the main 4-note motif "do-mi-re-sol". Mood: sunny late afternoon in Jakarta, hopeful, cozy, nostalgic. Mobile game menu music, must not be tiring on repeat.

> **chapter_retire_1** — Instrumental, 72 BPM, D major, 2 minutes, seamless loop, no vocals. Solo acoustic piano with soft nylon guitar and very quiet strings, a faint gamelan-like bell. Plays the 4-note motif "do-mi-re-sol" slowly, like a memory. Mood: calm night on a family home's porch, proud and grateful, gentle, not sad.

> **jingle_goal** — 3.5-second celebratory jingle in D major, warm brass or bright synth plus a short drum fill, ending on a sparkling bell. Plays the motif "do-mi-re-sol" fully. Joyful and proud, NOT a casino or slot-machine jackpot sound.

---

## 11. Urutan Pengerjaan yang Disarankan

1. **Tahap 1 (P1, 29 file):** 5 musik (`title_theme` + lagu pertama tiap bab), 7 jingle, 9 efek suara UI & kuis, 5 efek suara uang/aktivitas, 3 event & peringatan. Ini sudah cukup untuk rilis.
2. **Tahap 2 (P2):** lagu bab kedua, `end_theme`, jingle karier/lulus/pencapaian/bab/pensiun, efek kendaraan & properti, `liquidation`.
3. **Tahap 3 (P3):** pemanis (`counter_tick`, `chart_draw`, `event_scam`, suasana latar).

File boleh masuk satu per satu: begitu file dengan nama yang benar ada di `assets/audio/`, game langsung memakainya, dan bunyi sintetis lama tetap menjadi cadangan untuk file yang belum ada.

---

## 12. Catatan Implementasi (untuk pengembang)

Belum dikerjakan; ditulis agar file suara yang dibuat sekarang langsung cocok nanti.

- **Bus audio:** `Master` → `Music`, `Sfx`, `Ambience`. Volume dan sakelar Musik & Efek Suara terpisah di Pengaturan (sekarang baru ada `Settings.sfx_enabled`).
- **`Sfx.play(id)`** tetap dipakai seperti sekarang. Kode mencari `assets/audio/sfx/<id>.wav` atau `jingles/<id>.ogg`; kalau tidak ada, memakai bunyi sintetis lama (`click`, `coin`, `success`, `fail`, `alert`) sebagai cadangan. Bunyi yang punya varian (`ui_click_1..3`) dipilih acak.
- **Autoload musik baru** (mis. `Music`) memakai `AudioStreamPlaylist` (2 lagu per bab bergantian) dan crossfade; mendengar `GameState.chapter_changed` untuk ganti bab; meredam musik saat popup `quiet`/`warning`/jingle; berhenti di `NOTIFICATION_APPLICATION_PAUSED`.
- **Peta pemicu yang sekarang ada di kode → ID baru:**

| Lokasi sekarang | Bunyi sekarang | Ganti dengan |
|:--|:--|:--|
| `sfx.gd` semua tombol | `click` | `ui_click_1..3` (`ui_tab` untuk tab) |
| `main.gd` tombol Lanjut & +1 Tahun | `coin` | `next_month` |
| `main.gd` `_show_toast` | `success` | `toast` (atau jingle sesuai toast: naik jabatan, level) |
| `main.gd` `_celebrating` | getar + confetti | + `confetti_pop` + jingle sesuai momen |
| `info_popup.gd` `open` / `open_rich` normal | `success` | `ui_popup_open`, atau `ui_confirm` bila ada tombol kedua (konfirmasi) |
| `info_popup.gd` `open_warning` / `open_rich` warning | `alert` | `warning` (`warning_soft` untuk kondisi kritis) |
| `info_popup.gd` `open_quiet` / quiet | — | ⛔ tetap tanpa bunyi + redam musik |
| `event_popup.gd` event tidak tenang | `alert` + getar | `event_open` / `event_bad` / `event_scam` |
| `quiz_popup.gd` | `success` / `fail` | `quiz_correct` / `quiz_wrong` |
| `market_screen.gd` riset | `success` / `fail` | `research_done` / `ui_denied` |
| `activity_screen.gd` aktivitas berhasil | `success` | `activity_done` |
| `loan_popup.gd` ambil / lunasi | `coin` / `success` | `loan_signed` / `loan_paid_off` |
| `vehicle_popup.gd` beli / jual | `coin` | `buy_vehicle_motor`/`_car` / `asset_sold` |
| `property_popup.gd` beli | `coin` | `buy_property` |
| `dream_picker_popup.gd` / `dream_popup.gd` | `success` / `coin` / `alert` | `dream_added` / `dream_deposit` / `warning_soft` |
| `offer_popup.gd` | `success` | `jingle_job` |
| `plan_popup.gd` simpan | `success` | `plan_saved` |
| `achievement_popup.gd` | `coin` / `click` | `jingle_achievement` (terbuka) / `ui_popup_open` |
| `title_screen.gd` gagal muat | `fail` | `ui_denied` |
| `end_screen.gd` | `fail` / `success`, tanpa bunyi untuk kematian | `jingle_bankrupt` / `jingle_win`, ⛔ kematian |
| `month_summary_popup.gd` | — | `chart_draw` + `counter_tick` lalu `jingle_month_up` / `_down` |
| `main.gd` `chapter_changed` / `retirement_started` | getar + confetti | `jingle_chapter_build` / `_peak`, `jingle_retire` + ganti lagu bab |
| `main.gd` `stage_unlocked` / `goal_reached` / `dream_achieved` / `graduated` | `success` + getar + confetti | `jingle_unlock` / `jingle_goal` / `jingle_dream` / `jingle_graduate` |
