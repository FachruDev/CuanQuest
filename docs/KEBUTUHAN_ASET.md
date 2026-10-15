# Kebutuhan Aset Cuan Quest

Rangkuman semua aset gambar, font, dan suara per versi: yang **sudah ada**, yang **dibutuhkan**, dan **di file mana** aset itu dipakai. Diperbarui setiap kali sebuah langkah membutuhkan aset baru.

- **Terakhir diperbarui:** 15 Oktober 2026 (v1.5d langkah 3: ikon bidang "Umum" untuk proyek sampingan; langkah 2 tanpa aset baru; potret tokoh langkah 1 masih lingkaran berwarna + inisial)
- **Rencana pembuatan:** pengembang membuat aset setelah **v2 selesai**. Sampai saat itu game memakai aset sementara (🔁), dan daftar di bawah terus diperbarui setiap langkah.
- **Tanda:** ✅ sudah ada · ⬜ dibutuhkan · 🔁 sementara memakai aset lain atau gambar pengganti sederhana (game tetap jalan)
- Tabel aset yang sudah ada dibuat otomatis dengan memindai `scenes/`, `scripts/`, `theme/`, dan `data/`.

## Ringkasan per Versi

| Versi | Aset baru | Status |
|:--|:--|:--|
| **v1 + Redesain "Senja Cuan"** | 79 aset: font, ilustrasi, ikon (dibuat pengembang) | ✅ |
| **v1.5-0** Giliran bulanan yang hidup | Tidak ada; memakai ulang lencana & ikon (confetti digambar lewat kode) | ✅ |
| **v1.5a** Realisme ekonomi | Tidak ada; memakai ulang `shield.svg`, `wallet.svg`, `trend_line.svg`, `warning_small.svg` | ✅ |
| **v1.5b** Pekerjaan & karier | 13 ikon (3 latar pendidikan, 6 bidang kerja, 1 navigasi Karier, 3 program kuliah) + 2 opsional | ⬜ 🔁 |
| **v1.5c** Utang, properti, hunian | 3 ikon (lencana popup Pinjaman, Kendaraan, Properti) + 11 ilustrasi Hunian & Kendaraan (latar, 7 tempat tinggal, 3 kendaraan) yang sekarang berupa gambar pengganti sederhana | ⬜ 🔁 |
| **v1.5d** Tokoh & konten | 6 potret tokoh (dipakai sekarang, sementara inisial berwarna) + 1 ikon bidang "Umum" (proyek sampingan); lencana pencapaian & kosmetik menyusul | ⬜ 🔁 |
| **v2** | Ikon instrumen lanjut, ilustrasi bab kehidupan | ⬜ (rencana) |
| **M7** Rilis Play Store | Ikon aplikasi adaptif, grafis & screenshot Play Store | ⬜ (rencana) |

## Aturan Umum

| Jenis | Format | Catatan |
|:--|:--|:--|
| Ikon | **SVG** | Satu warna/flat seperti ikon yang ada. Ukuran kanvas 24x24 atau 48x48; tanpa teks (ubah jadi path), tanpa filter/blur |
| Ilustrasi | **SVG** (utama) atau PNG 2x | Gaya "Senja Cuan": warna hangat senja, garis tebal tinta `#2B2147`, sudut membulat |
| Font | TTF/OTF lisensi **OFL** | Saat ini Fredoka (isi) & Lilita One (judul) |
| Efek suara / musik | WAV 16-bit / OGG | Saat ini efek suara dibuat lewat kode (`scripts/autoload/sfx.gd`); musik belum ada |

- Layar dasar **720 x 1280** (portrait). Gambar PNG dibuat 2x ukuran tampil.
- Nama file `snake_case`, tanpa spasi. Ikon yang dipilih lewat data (mis. bidang kerja) **harus** memakai id dari file data, misalnya `tracks/tech.svg` untuk bidang `tech`.
- Palet: tinta `#2B2147`, emas `#F6B93B`, teal `#23877B`, kertas `#FFF8EC`, hijau untung, merah rugi (lihat `scripts/ui/palette.gd`).
- Aset CC0/OFL dari luar: catat sumbernya di `assets/LICENSES.md`.

---

## v1.5b: Pekerjaan & Karier ⬜

Game sudah jalan memakai aset sementara (🔁). Begitu file baru ditaruh di path di bawah, sebagian langsung terpakai otomatis; sisanya cukup ubah satu baris (kolom "Cara memasang").

| File | Isi | Dipakai di | Sementara | Cara memasang |
|:--|:--|:--|:--|:--|
| `assets/icons/background_sma.svg` | Latar SMA/SMK (buku/tas sekolah) | `scripts/ui/new_game_screen.gd` (kartu latar di wizard Game Baru) | 🔁 `background_student.svg` | Ubah `"icon"` latar `sma` di `data/economy.json` menjadi `"sma"` |
| `assets/icons/background_d3.svg` | Latar D3 (laptop/alat praktik) | `scripts/ui/new_game_screen.gd` | 🔁 `background_freelancer.svg` | Ubah `"icon"` latar `d3` menjadi `"d3"` |
| `assets/icons/background_s1.svg` | Latar S1 (toga wisuda) | `scripts/ui/new_game_screen.gd` | 🔁 `background_employee.svg` | Ubah `"icon"` latar `s1` menjadi `"s1"` |
| `assets/icons/tracks/retail.svg` | Bidang Ritel & Layanan (keranjang/kasir) | `scripts/ui/ui_text.gd` (`track_icon`): tab Karier & kartu Karier di Beranda | 🔁 `wallet.svg` | Otomatis |
| `assets/icons/tracks/admin.svg` | Bidang Administrasi (map/dokumen) | `scripts/ui/ui_text.gd` | 🔁 `folder.svg` | Otomatis |
| `assets/icons/tracks/finance.svg` | Bidang Keuangan & Perbankan (gedung bank) | `scripts/ui/ui_text.gd` | 🔁 `classes/deposit.svg` | Otomatis |
| `assets/icons/tracks/tech.svg` | Bidang Teknologi (kode `</>`) | `scripts/ui/ui_text.gd` | 🔁 `search.svg` | Otomatis |
| `assets/icons/tracks/creative.svg` | Bidang Kreatif & Pemasaran (kuas/megafon) | `scripts/ui/ui_text.gd` | 🔁 `lightbulb.svg` | Otomatis |
| `assets/icons/tracks/gig.svg` | Kerja Lepas (helm/motor) | `scripts/ui/ui_text.gd` | 🔁 `activities/side_job.svg` | Otomatis |
| `assets/icons/nav_career.svg` | Navigasi tab Karier (koper) | `scenes/main.tscn` (tombol navigasi ke-4) | 🔁 `nav_activity.svg` | Ganti path `nav_activity.svg` di `scenes/main.tscn` (atau minta saya) |
| `assets/icons/badge_job.svg` (opsional) | Lencana popup Tawaran Kerja (koper + bintang) | `scenes/ui/offer_popup.tscn` | 🔁 `badge_star.svg` | Ganti path di `scenes/ui/offer_popup.tscn` |
| `assets/icons/education/d3.svg` | Program Kuliah D3 (buku + papan nama) | `scripts/ui/screens/activity_screen.gd` (kartu Pendidikan & Keahlian, tab Karier) | 🔁 `activities/course.svg` | Otomatis (nama file = id program di `data/education.json`) |
| `assets/icons/education/s1.svg` | Program Kuliah S1 (toga) | `scripts/ui/screens/activity_screen.gd` | 🔁 `activities/course.svg` | Otomatis |
| `assets/icons/education/s2.svg` | Program Kuliah S2 (toga + bintang) | `scripts/ui/screens/activity_screen.gd` | 🔁 `activities/course.svg` | Otomatis |
| `assets/icons/badge_graduation.svg` (opsional) | Lencana popup "Selamat Lulus!" (toga) | `scripts/ui/main.gd` (popup kelulusan memakai `InfoPopup`) | 🔁 `badge_star.svg` | Perlu sedikit kode (minta saya) |

---

## v1.5c: Utang, Properti, dan Hunian yang Tumbuh ⬜

**Sudah dipakai (langkah 1-3), sementara memakai aset lain:**

| File | Isi | Dipakai di | Sementara | Cara memasang |
|:--|:--|:--|:--|:--|
| `assets/icons/loan.svg` | Lencana popup Pinjaman (dokumen + koin) | `scenes/ui/loan_popup.tscn` (popup ajukan pinjaman & rincian pinjaman, dari kartu Utang & Kredit di Beranda) | 🔁 `wallet.svg` | Ganti path `wallet.svg` di `scenes/ui/loan_popup.tscn` (atau minta saya) |
| `assets/icons/vehicle.svg` | Lencana popup Kendaraan (motor/mobil + kunci) | `scenes/ui/vehicle_popup.tscn` (popup beli kendaraan & rincian/jual, dari kartu Kendaraan di Beranda) | 🔁 `activities/side_job.svg` | Ganti path `activities/side_job.svg` di `scenes/ui/vehicle_popup.tscn` (atau minta saya) |
| `assets/icons/property.svg` | Lencana popup Properti (rumah + kunci/papan "dijual") | `scenes/ui/property_popup.tscn` (daftar properti, beli tunai/KPR, rincian/jual, dari kartu Properti di Beranda) | 🔁 `nav_home.svg` | Ganti path `nav_home.svg` di `scenes/ui/property_popup.tscn` (atau minta saya) |

**Ilustrasi Hunian & Kendaraan (langkah 4), sekarang gambar pengganti sederhana:**

Dipakai kartu **Hunian & Kendaraan** di Beranda (`scripts/ui/home_scene.gd`, dipasang oleh `scripts/ui/screens/home_screen.gd`). Tiga lapis ditumpuk: latar → tempat tinggal → kendaraan. **Aturan kanvas:** semua file **624 x 260** (rasio 2,4 : 1), latar penuh dengan sudut membulat 18, lapisan lain **transparan**; tempat tinggal di sisi kiri-tengah (x 40-410) berdiri di garis tanah y ±218; kendaraan di sisi kanan (x 400-610) dengan roda di y ±246. Gaya "Senja Cuan": garis tinta `#2B2147` tebal 4, bayangan tinta bergeser 6-8 px ke bawah. **Cara memasang: timpa file dengan nama yang sama** (impor SVG skala 2.0 seperti ilustrasi lain), tanpa mengubah kode.

| File | Isi | Kapan tampil | Status |
|:--|:--|:--|:--|
| `assets/illustrations/home/bg.svg` | Latar: langit senja, matahari, awan, bukit, rumput, trotoar | Selalu | 🔁 pengganti |
| `assets/illustrations/home/family.svg` | Rumah keluarga (menumpang) | Tempat tinggal Menumpang | 🔁 pengganti |
| `assets/illustrations/home/kos.svg` | Bangunan kos 2 lantai, deretan pintu kamar, toren air | Kos | 🔁 pengganti |
| `assets/illustrations/home/kontrakan.svg` | Rumah petak 3 unit berderet, unit tengah milik pemain | Kontrakan | 🔁 pengganti |
| `assets/illustrations/home/apartment.svg` | Menara apartemen | Apartemen sewa; juga Apartemen Studio milik sendiri | 🔁 pengganti |
| `assets/illustrations/home/subsidi.svg` | Rumah tipe 36 kecil berpagar | Menghuni Rumah Subsidi | 🔁 pengganti |
| `assets/illustrations/home/house45.svg` | Rumah tipe 45 dengan carport | Menghuni Rumah Tipe 45 | 🔁 pengganti |
| `assets/illustrations/home/house90.svg` | Rumah besar 2 lantai dengan balkon & pohon | Menghuni Rumah Besar | 🔁 pengganti |
| `assets/illustrations/home/studio.svg` (opsional) | Apartemen studio milik sendiri (beda dari apartemen sewa) | Menghuni Apartemen Studio | ⬜ (sementara memakai `apartment.svg`) |
| `assets/illustrations/vehicle/walk.svg` | Halte bus + bangku (jalan kaki & angkutan umum) | Belum punya kendaraan | 🔁 pengganti |
| `assets/illustrations/vehicle/motor.svg` | Motor matic | Kendaraan utama motor | 🔁 pengganti |
| `assets/illustrations/vehicle/car.svg` | Mobil keluarga | Kendaraan utama mobil (punya mobil & motor = mobil) | 🔁 pengganti |

Nama file = id di data: tempat tinggal sewa memakai id `housing` di `data/economy.json`, rumah sendiri memakai id properti di `data/properties.json`, kendaraan memakai id di `data/vehicles.json`. Properti baru tanpa gambar memakai gambar pengganti di `HOME_FALLBACK` (`scripts/ui/home_scene.gd`).

**Rencana (opsional):**

| File | Isi | Akan dipakai di |
|:--|:--|:--|
| `assets/icons/credit_score.svg` | Ikon skor kredit | Kartu Utang & Kredit di Beranda, kartu Neraca di tab Portofolio |

## v1.5d: Tokoh, Riset, Kontrak, Konten ⬜

**Sudah dipakai (langkah 1), sementara lingkaran berwarna + inisial nama (digambar kode):**

Dipakai `scripts/ui/character_portrait.gd` di popup event (baris tokoh di bawah judul) dan kartu **Orang Terdekat** di tab Profil. Potret **bulat**, kanvas persegi 256 x 256 (lingkaran penuh, garis tinta `#2B2147`), gaya sama dengan avatar pemain. **Cara memasang: otomatis** begitu file ada (nama file = id tokoh di `data/characters.json`).

| File | Tokoh | Kesan visual | Sementara |
|:--|:--|:--|:--|
| `assets/illustrations/characters/bima.svg` | Bima, sahabat | Pria muda santai, kaos & topi terbalik, ceria-impulsif | 🔁 lingkaran oranye "B" |
| `assets/illustrations/characters/ibu.svg` | Ibu | Ibu paruh baya berkerudung, hangat | 🔁 lingkaran teal "I" |
| `assets/illustrations/characters/wulan.svg` | Kak Wulan, mentor keuangan | Wanita ±30 tahun, blazer, rapi & percaya diri | 🔁 lingkaran biru "W" |
| `assets/illustrations/characters/ratna.svg` | Bu Ratna, tetangga | Ibu-ibu ramah berdaster, suka bercerita | 🔁 lingkaran ungu "R" |
| `assets/illustrations/characters/boss.svg` | Atasan (nama berganti per perusahaan, pria/wanita) | Netral gender, kemeja kantor & kacamata | 🔁 lingkaran tinta + inisial nama |
| `assets/illustrations/characters/coworker.svg` | Rekan kerja (nama berganti per perusahaan) | Netral gender, kartu identitas karyawan | 🔁 lingkaran emas + inisial nama |

**Langkah 3 (proyek sampingan), sementara memakai ikon lain:**

Kartu proyek di tab Karier memakai ikon bidang kerja yang sama dengan lowongan (`assets/icons/tracks/<bidang>.svg`, lihat v1.5b). Proyek bidang **Umum** (les privat, penerjemahan) butuh satu ikon baru:

| File | Isi | Dipakai di | Sementara | Cara memasang |
|:--|:--|:--|:--|:--|
| `assets/icons/tracks/general.svg` | Bidang Umum (buku + pena) | `scripts/ui/ui_text.gd` (`track_icon`): kartu Proyek Sampingan di tab Karier | 🔁 `book.svg` | Otomatis |

**Langkah 2 (rumor & riset):** tidak butuh aset baru. Kartu **Kabar Burung** di tab Pasar, bagian Rumor & Riset di laporan bulanan, dan kartu Rekam Jejak Riset di Profil memakai gaya kartu, chip, dan tombol yang sudah ada.

**Rencana (langkah berikutnya):**

| File | Isi | Akan dipakai di |
|:--|:--|:--|
| `assets/icons/achievements/<id>.svg` (15+) | Lencana pencapaian | Tab Profil (`scenes/screens/profile_screen.tscn`) |
| Tema & avatar tambahan | Kosmetik yang dibuka lewat pencapaian | `theme/`, `assets/illustrations/avatar_*.svg` |

## v2 ⬜ (rencana)

| File | Isi | Akan dipakai di |
|:--|:--|:--|
| `assets/icons/classes/commodity.svg`, `forex.svg` | Kelas instrumen lanjut | Tab Pasar & Portofolio (`scripts/ui/ui_text.gd`, dinamis per kelas) |
| `assets/illustrations/chapters/<bab>.svg` | Ilustrasi bab kehidupan (awal karier, membangun, puncak, pensiun) | Popup pergantian bab (rencana) |

## M7: Rilis Play Store ⬜ (rencana)

| File | Isi | Dipakai di |
|:--|:--|:--|
| `assets/branding/icon_foreground.png`, `icon_background.png` (432x432) | Ikon aplikasi adaptif Android | `export_presets.cfg` (preset Android) |
| `assets/branding/feature_graphic.png` (1024x500) | Grafis fitur Play Store | Halaman Play Store |
| Screenshot 1080x1920 (4-8) | Tangkapan layar game | Halaman Play Store |

---

## v1 + Redesain "Senja Cuan": Aset yang Sudah Ada ✅

#### Font (2)

| File | Dipakai di |
|:--|:--|
| `assets/fonts/Fredoka.ttf` | `theme/fonts/fredoka_bold.tres`<br>`theme/fonts/fredoka_caps.tres`<br>`theme/fonts/fredoka_medium.tres`<br>`theme/fonts/fredoka_regular.tres`<br>`theme/fonts/fredoka_semibold.tres` |
| `assets/fonts/LilitaOne-Regular.ttf` | `theme/fonts/lilita.tres`<br>`theme/fonts/lilita_spaced.tres` |

#### Ilustrasi (20)

| File | Dipakai di |
|:--|:--|
| `assets/illustrations/end_bg.svg` | `scenes/end_screen.tscn` |
| `assets/illustrations/header_bg.svg` | `scenes/new_game.tscn` |
| `assets/illustrations/title_bg.svg` | `scenes/title.tscn` |
| `assets/illustrations/title_coin.svg` | `scenes/title.tscn` |
| `assets/illustrations/topbar_bg.svg` | `scenes/main.tscn` |
| `assets/illustrations/avatar_{0,1,2,3,4,5,6,7,8,9}.svg` | `scripts/ui/avatar_view.gd (dinamis: avatar_%d.svg)` |
| `assets/illustrations/tutorial_{1,2,3,4,5}.svg` | `scripts/ui/tutorial_screen.gd (dinamis: tutorial_%d.svg)` |

#### Ikon kelas aset (5)

| File | Dipakai di |
|:--|:--|
| `assets/icons/classes/crypto.svg` | `scripts/ui/ui_text.gd (dinamis: %s.svg)` |
| `assets/icons/classes/deposit.svg` | `scripts/ui/ui_text.gd`<br>`scripts/ui/ui_text.gd (dinamis: %s.svg)` |
| `assets/icons/classes/mutual_fund.svg` | `scripts/ui/ui_text.gd (dinamis: %s.svg)` |
| `assets/icons/classes/savings.svg` | `scripts/ui/ui_text.gd (dinamis: %s.svg)` |
| `assets/icons/classes/stock.svg` | `scripts/ui/ui_text.gd (dinamis: %s.svg)` |

#### Ikon aktivitas (6)

| File | Dipakai di |
|:--|:--|
| `assets/icons/activities/course.svg` | `scripts/ui/screens/activity_screen.gd (dinamis: %s.svg)` |
| `assets/icons/activities/exercise.svg` | `scripts/ui/screens/activity_screen.gd (dinamis: %s.svg)` |
| `assets/icons/activities/hangout.svg` | `scripts/ui/screens/activity_screen.gd (dinamis: %s.svg)` |
| `assets/icons/activities/rest.svg` | `scripts/ui/screens/activity_screen.gd (dinamis: %s.svg)` |
| `assets/icons/activities/self_study.svg` | `scripts/ui/screens/activity_screen.gd (dinamis: %s.svg)` |
| `assets/icons/activities/side_job.svg` | `scenes/ui/vehicle_popup.tscn`<br>`scripts/ui/screens/activity_screen.gd (dinamis: %s.svg)`<br>`scripts/ui/ui_text.gd` |

#### Ikon navigasi bawah (5)

| File | Dipakai di |
|:--|:--|
| `assets/icons/nav_activity.svg` | `scenes/main.tscn` |
| `assets/icons/nav_home.svg` | `scenes/main.tscn`<br>`scenes/ui/property_popup.tscn`<br>`scripts/ui/screens/profile_screen.gd` |
| `assets/icons/nav_market.svg` | `scenes/main.tscn` |
| `assets/icons/nav_portfolio.svg` | `scenes/main.tscn` |
| `assets/icons/nav_profile.svg` | `scenes/main.tscn` |

#### Lencana popup (badge) (5)

| File | Dipakai di |
|:--|:--|
| `assets/icons/badge_calendar.svg` | `scenes/ui/month_summary_popup.tscn` |
| `assets/icons/badge_lose.svg` | `scripts/ui/end_screen.gd` |
| `assets/icons/badge_retire.svg` | `scripts/ui/end_screen.gd` |
| `assets/icons/badge_star.svg` | `scenes/ui/dream_picker_popup.tscn`<br>`scenes/ui/info_popup.tscn`<br>`scenes/ui/offer_popup.tscn` |
| `assets/icons/badge_trophy.svg` | `scenes/end_screen.tscn`<br>`scenes/ui/dream_popup.tscn`<br>`scripts/ui/end_screen.gd` |

#### Ikon latar belakang (3)

| File | Dipakai di |
|:--|:--|
| `assets/icons/background_employee.svg` | `scripts/ui/new_game_screen.gd (dinamis: background_%s.svg)` |
| `assets/icons/background_freelancer.svg` | `scripts/ui/new_game_screen.gd (dinamis: background_%s.svg)` |
| `assets/icons/background_student.svg` | `scripts/ui/new_game_screen.gd (dinamis: background_%s.svg)` |

#### Ikon UI lainnya (33)

| File | Dipakai di |
|:--|:--|
| `assets/icons/arrow_badge.svg` | `scenes/new_game.tscn`<br>`scenes/tutorial.tscn`<br>`scripts/ui/new_game_screen.gd`<br>`scripts/ui/tutorial_screen.gd` |
| `assets/icons/bolt.svg` | `scripts/ui/main.gd`<br>`scripts/ui/screens/activity_screen.gd` |
| `assets/icons/book.svg` | `scenes/ui/glossary_popup.tscn`<br>`scripts/ui/screens/profile_screen.gd` |
| `assets/icons/calendar_badge.svg` | `scenes/main.tscn` |
| `assets/icons/check_badge.svg` | `scripts/ui/new_game_screen.gd` |
| `assets/icons/chevron_left.svg` | `scenes/new_game.tscn`<br>`scenes/screens/market_screen.tscn` |
| `assets/icons/chevron_right.svg` | `scenes/ui/save_slot_button.tscn`<br>`scripts/ui/screens/profile_screen.gd` |
| `assets/icons/close.svg` | `scenes/title.tscn`<br>`scenes/ui/glossary_popup.tscn` |
| `assets/icons/folder.svg` | `scenes/title.tscn`<br>`scripts/ui/ui_text.gd` |
| `assets/icons/heart.svg` | `scenes/screens/home_screen.tscn` |
| `assets/icons/info.svg` | `scenes/new_game.tscn`<br>`scenes/title.tscn` |
| `assets/icons/lightbulb.svg` | `scenes/tutorial.tscn`<br>`scripts/ui/end_screen.gd`<br>`scripts/ui/screens/profile_screen.gd`<br>`scripts/ui/ui_text.gd` |
| `assets/icons/lock.svg` | `scripts/ui/title_screen.gd` |
| `assets/icons/news.svg` | `scenes/screens/market_screen.tscn`<br>`scripts/ui/screens/profile_screen.gd` |
| `assets/icons/play_badge.svg` | `scenes/end_screen.tscn`<br>`scenes/title.tscn`<br>`scripts/ui/new_game_screen.gd`<br>`scripts/ui/tutorial_screen.gd` |
| `assets/icons/plus.svg` | `scenes/title.tscn` |
| `assets/icons/plus_badge.svg` | `scenes/title.tscn` |
| `assets/icons/radio_off.svg` | `scripts/ui/new_game_screen.gd` |
| `assets/icons/radio_on.svg` | `scripts/ui/new_game_screen.gd` |
| `assets/icons/save.svg` | `scenes/title.tscn` |
| `assets/icons/search.svg` | `scenes/ui/glossary_popup.tscn`<br>`scripts/ui/ui_text.gd` |
| `assets/icons/shield.svg` | `scenes/ui/insurance_popup.tscn`<br>`scenes/ui/text_popup.tscn`<br>`scripts/ui/screens/profile_screen.gd` |
| `assets/icons/skip.svg` | `scenes/tutorial.tscn` |
| `assets/icons/smile.svg` | `scenes/screens/home_screen.tscn` |
| `assets/icons/switch_off.svg` | `theme/senja_theme.tres` |
| `assets/icons/switch_on.svg` | `theme/senja_theme.tres` |
| `assets/icons/trend_down.svg` | `scripts/ui/end_screen.gd`<br>`scripts/ui/title_screen.gd` |
| `assets/icons/trend_line.svg` | `scenes/main.tscn`<br>`scenes/ui/order_popup.tscn` |
| `assets/icons/trend_up.svg` | `scenes/title.tscn`<br>`scripts/ui/end_screen.gd` |
| `assets/icons/wallet.svg` | `scenes/main.tscn`<br>`scenes/ui/loan_popup.tscn`<br>`scenes/ui/plan_popup.tscn`<br>`scenes/ui/trade_confirm_popup.tscn`<br>`scripts/ui/ui_text.gd` |
| `assets/icons/warning.svg` | `scenes/title.tscn` |
| `assets/icons/warning_small.svg` | `scenes/screens/market_screen.tscn`<br>`scenes/screens/portfolio_screen.tscn`<br>`scripts/ui/trade_confirm_popup.gd` |
| `assets/icons/welcome.svg` | `scenes/title.tscn` |

