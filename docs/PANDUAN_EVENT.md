# Panduan Menambah Event

Event hidup (sakit, THR, penipuan, promosi, beasiswa, ...) ditulis sebagai **data JSON**, bukan kode. Untuk event biasa kamu cukup menambah satu objek JSON. Kode hanya perlu disentuh jika butuh **efek**, **syarat**, atau **isian teks** yang benar-benar baru.

Analogi web: event adalah *content entry* di CMS; efek adalah *action handler*; syarat adalah *guard*.

## Di mana event disimpan

| File | Isi |
|:--|:--|
| `data/events/finance.json` | Keuangan sehari-hari: kerusakan, tagihan, THR, belanja, rezeki, asuransi |
| `data/events/work.json` | Pekerjaan & karier: PHK, wawancara, promosi, lembur, proyek, headhunter |
| `data/events/education.json` | Pendidikan: sertifikasi, beasiswa, ujian |
| `data/events/health.json` | Kesehatan: sakit, rawat inap, olahraga, burnout |
| `data/events/social.json` | Sosial & keluarga |
| `data/events/market.json` | Pasar & investasi |
| `data/events/scam.json` | Waspada penipuan (beserta rantai lanjutannya) |

Semua file dimuat oleh `EventManager.load_defs()` (`scripts/core/event_manager.gd`) sesuai urutan `CATEGORIES`. Nilai `"category"` sebuah event **harus sama** dengan nama filenya; jika berbeda, Godot menampilkan peringatan. Kategori baru = tambah file, tambah nama di `CATEGORIES`, dan tambah teks `EVENT_CAT_<KATEGORI>` di `localization/strings.csv`.

## Langkah menambah event biasa

1. Pilih file kategori yang cocok, lalu salin event yang mirip (misalnya `found_money` di `finance.json`).
2. Ganti `id` dengan id unik (huruf kecil + garis bawah), lalu ubah `title`, `text`, dan `choices`.
3. Angka uang di teks **wajib** memakai token `{rp:3000000}` (harga awal permainan); game menggantinya dengan nominal hari ini, misalnya "Rp3,1 juta".
4. Atur kapan event boleh muncul: `weight`, `min_month`, `cooldown`, `max_times`, `requires`, `context`.
5. Jalankan game atau simulator (`tools/balance`) untuk melihat event muncul dan dampaknya.

```json
{
	"id": "laptop_rusak", "bad": true, "category": "finance", "weight": 2, "min_month": 6, "cooldown": 18,
	"title": "Laptop Rusak", "text": "Laptopmu mati total padahal ada pekerjaan penting.",
	"choices": [
		{ "label": "Servis resmi", "cost": 1500000, "effects": { "performance": 2 }, "result": "Laptop kembali normal." },
		{ "label": "Pinjam laptop teman", "outcomes": [
			{ "chance": 0.7, "effects": { "happiness": -2 }, "result": "Pekerjaan beres walau repot." },
			{ "chance": 0.3, "effects": { "performance": -5 }, "result": "Pekerjaan terlambat dan atasan kecewa." }
		] }
	]
}
```

## Field event

| Field | Wajib | Arti |
|:--|:--|:--|
| `id` | ya | Id unik (dipakai di save, rantai event, dan riwayat) |
| `category` | ya | Sama dengan nama file |
| `title`, `text` | ya | Judul & cerita (boleh berisi token `{rp:N}` dan isian seperti `{job}`) |
| `choices` | ya | 1-3 pilihan (lihat di bawah) |
| `weight` | ya | Bobot peluang terpilih (relatif terhadap event lain) |
| `bad` | - | `true` = event merugikan; bobotnya dikali `bad_event_mult` tingkat kesulitan dan lebih jarang setelah event buruk |
| `min_month` | - | Paling cepat muncul di bulan ke-N |
| `cooldown` | - | Jeda bulan sebelum boleh muncul lagi (default 12) |
| `max_times` | - | Maksimal muncul sepanjang permainan |
| `month_of_year` | - | Hanya di bulan tertentu (0 = Januari) |
| `guaranteed` | - | Selalu muncul jika syarat terpenuhi (mis. THR), di luar jatah acak |
| `requires` | - | Syarat kondisi pemain (lihat tabel syarat) |
| `context` | - | Pengali bobot saat kondisi aktif, mis. `{ "cash_rich": 3 }` |
| `chain_only` | - | Tidak pernah acak: hanya lewat efek `chain` atau dijadwalkan sistem (wawancara, promosi, PHK) |
| `critical` | - | Penyakit kritis: asuransi jiwa membayar uang pertanggungan |

**Pilihan (`choices`):** `label`, `result`, lalu salah satu dari `effects` atau `outcomes` (`[{chance, effects, result}]`, peluangnya dijumlah 1). Opsional: `cost` (dibayar di muka; pilihan nonaktif jika kas kurang), `cost_vehicle` (persen nilai pasar kendaraan utama, mis. biaya perbaikan), `claim` (`medical` / `vehicle`, biaya ditanggung asuransi aktif).

## Efek (`effects`) dan modul yang menjalankannya

`GameState.apply_effects()` menjalankan kas, kesehatan, dan kebahagiaan; kunci lain dijalankan oleh `apply_effects()` di modul pemiliknya (`scripts/game/`).

| Kunci | Modul | Arti |
|:--|:--|:--|
| `cash`, `cash_salary`, `health`, `happiness` | GameState | Kas (harga awal, ikut inflasi), kas x gaji, kesehatan, kebahagiaan |
| `xp` | Progress | Tambah XP |
| `salary_pct`, `unpaid_months`, `skill`, `performance` | Career | Gaji naik/turun, cuti tanpa gaji, keahlian, kinerja |
| `lose_job`, `layoff`, `promote` | Career | Berhenti tanpa pesangon, PHK + pesangon, naik jabatan |
| `offer_raise`, `headhunter` | Career | Naikkan tawaran yang diwawancarai, tambah tawaran headhunter |
| `scholarship`, `sponsored_study`, `study_delay` | Education | Beasiswa kampus, beasiswa kantor, kuliah mundur |
| `delayed` `{months, chance, effects, text, fail_text}` | LifeEvents | Efek tertunda beberapa bulan |
| `chain` `{event, months: [min, max]}` | LifeEvents | Jadwalkan event lanjutan (`chain_only`) |
| `sell_all` | Portfolio | Jual semua investasi karena panik |
| `credit_score` | Debt | Skor kredit naik/turun (0-100), mis. `-10` saat telat bayar tagihan (v1.5c) |

**Menambah efek baru:** tentukan modul pemiliknya, tambahkan penanganannya di `apply_effects()` modul itu, lalu catat di tabel ini. Contoh: efek baru untuk asuransi ditulis di `scripts/game/insurance.gd`.

## Syarat (`requires`)

Didefinisikan di `EventManager.requires_met()`. Event yang sudah masuk antrean bulan ini dicek ulang saat gilirannya tiba.

| Nilai | Terpenuhi jika |
|:--|:--|
| `employed` | Bekerja (termasuk kerja lepas) dan tidak sedang cuti |
| `career` | Bekerja di pekerjaan berjenjang (bukan kerja lepas) dan tidak cuti |
| `unemployed` | Belum/tidak bekerja |
| `headhunter` | Karier + ada incaran bergaji minimal 10% lebih tinggi |
| `studying` | Sedang kuliah (sudah dimulai) |
| `sponsor_ready` | Syarat beasiswa kantor terpenuhi |
| `has_investments` | Punya investasi |
| `has_vehicle` | Punya motor/mobil (modul Vehicles) |
| `low_happiness` | Kebahagiaan di bawah 40 |

**Menambah syarat baru:** tambah satu cabang di `match` dalam `EventManager.requires_met()`.

## Kondisi `context`

Dihitung `GameState.events.context_flags()` (ambang di `economy.json` `event_director`): `cash_rich`, `cash_poor`, `low_happiness`, `low_health`, `holds_risky`, `holds_crypto`, `unemployed`.

## Isian teks

| Isian | Sumber |
|:--|:--|
| `{rp:N}` | `UiText.money()`: harga awal permainan → nominal hari ini |
| `{job}`, `{company}`, `{salary}`, `{months}`, `{severance}`, `{raise}` | `Career.event_vars()` (wawancara, promosi, PHK, headhunter) |
| `{program}`, `{cert}` | `Education.event_vars()` (beasiswa kantor, sertifikasi) |

Isian dihitung sekali saat event mulai tampil dan ikut disimpan, sehingga teks dan efeknya selalu cocok. **Menambah isian baru:** kembalikan nilainya dari `event_vars(id)` di modul pemilik event, lalu tambahkan penggantinya di `UiText.event_text()`.

## Event yang dijadwalkan sistem

Event yang waktunya ditentukan oleh logika game (bukan undian) ditandai `"chain_only": true`, lalu dijadwalkan dari kode. Contohnya `Career.scheduled_events()`: wawancara saat ada tawaran kerja berjenjang, PHK sesuai peluang, dan promosi saat semua syarat terpenuhi. Daftarnya ada di `Career.SCHEDULED_EVENTS`.

## Sebelum selesai

- Jalankan game dan pastikan teks tampil benar (token & isian terganti).
- Jalankan simulator: `--headless --path . res://tools/balance/balance_sim.tscn -- --save-root=user://_sim/ --games=20 --years=10`, lalu bandingkan hasilnya dengan sebelum event ditambah.
