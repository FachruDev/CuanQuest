# Pedoman Konten Sensitif (v2b)

> **Status: USULAN, menunggu persetujuan pemilik proyek.** Fitur depresi (v2b langkah 4) dan kematian (v2b langkah 3) baru dikerjakan setelah pedoman ini disetujui (dokumen MVP, bagian 11: "v2b jangan dikerjakan sebelum pedoman konten sensitif disepakati").

Pedoman ini berlaku untuk semua teks, event, popup, dan layar yang menyentuh **kesehatan mental (depresi)**, **sakit kritis**, dan **kematian**. Tujuannya: game tetap jujur bahwa hidup punya risiko, tanpa menakut-nakuti, menstigma, atau membahayakan pemain yang sedang rapuh.

## 1. Prinsip

| # | Prinsip | Artinya di game |
|:--|:--|:--|
| 1 | **Ini simulasi, bukan diagnosis** | Status "Depresi" adalah penyederhanaan permainan. Teks menyebut bahwa depresi di dunia nyata adalah kondisi kesehatan yang bisa ditangani tenaga profesional. |
| 2 | **Tanpa penggambaran menyakiti diri sendiri** | Tidak ada event, pilihan, teks, penyebab kematian, atau sindiran yang berkaitan dengan menyakiti diri sendiri atau bunuh diri. Tidak pernah. |
| 3 | **Depresi tidak pernah mengakhiri permainan** | Depresi tidak menyebabkan kematian atau "kalah" secara langsung. Efeknya sementara (energi berkurang, kesehatan turun perlahan) dan selalu ada jalan pulih. |
| 4 | **Mencari bantuan selalu tersedia dan tidak dihukum** | Pilihan konseling, istirahat, dan bercerita ke orang terdekat selalu ada, murah atau ditanggung BPJS, dan memberi hasil baik. Game tidak pernah memberi "hadiah" untuk memendam masalah. |
| 5 | **Bahasa netral, tidak menyalahkan, tanpa stigma** | Hindari kata "lemah", "gila", "malas", "cengeng". Pakai "sedang tidak baik-baik saja", "kelelahan mental", "butuh istirahat". Tidak ada humor tentang kesehatan mental, penyakit, atau kematian. |
| 6 | **Tidak ada kematian mendadak tanpa peringatan** | Kematian hanya setelah peringatan jelas: status **Kritis** (kesehatan < 20), atau pemberitahuan **masa senja** (usia 70+). Kesehatan 0 selama 3 bulan tetap berakibat meninggal karena sakit parah, dengan peringatan setiap bulan sebelumnya. |
| 7 | **Kematian ditulis tenang dan hormat** | Pakai "meninggal dunia" atau "tutup usia". Penyebab ditulis umum (usia lanjut, sakit kritis, sakit parah) tanpa detail medis berlebihan. Tidak ada gambar atau animasi grafis. Layar akhir berisi refleksi perjalanan hidup dan warisan, bukan "GAME OVER". |
| 8 | **Tokoh berulang tidak meninggal** | Ibu, Bima, Kak Wulan, dan tokoh lain tidak meninggal di v2b. Event Ibu berhenti muncul saat pemain berusia 55+, tanpa diceritakan alasannya. |
| 9 | **Edukatif, bukan menakut-nakuti** | Event sakit menekankan hal yang bisa dilakukan: pemeriksaan rutin, BPJS & asuransi, dana darurat, istirahat. Tidak menyebut penyakit spesifik yang lekat dengan stigma. |

## 2. Pesan dukungan

Tampil saat status Depresi muncul pertama kali di sebuah permainan, dan tersedia di **Profil > Bantuan**:

> Ini hanya simulasi. Jika kamu sendiri sedang merasa tertekan atau tidak baik-baik saja, kamu tidak sendirian. Bicarakan dengan orang yang kamu percaya, atau temui tenaga profesional seperti psikolog atau dokter di puskesmas. Dalam keadaan darurat, hubungi **119**.

- **[VERIFIKASI SEBELUM RILIS]** Nomor dan nama layanan kesehatan jiwa resmi yang masih aktif (mis. layanan konseling Kementerian Kesehatan). Nomor 119 adalah layanan gawat darurat medis nasional.
- Pesan ini tidak bisa dimatikan dan tidak memakai bahasa promosi.

## 3. Daftar cek untuk setiap konten baru

Sebelum event, teks, atau layar bertema sensitif ditambahkan:

- [ ] Tidak menyebut atau menyiratkan menyakiti diri sendiri / bunuh diri
- [ ] Ada pilihan mencari bantuan, dan pilihan itu tidak dihukum
- [ ] Bahasa netral, tanpa kata yang menstigma, tanpa humor
- [ ] Kematian: ada peringatan sebelumnya, bahasa tenang, tanpa detail grafis
- [ ] Tidak menampilkan tokoh berulang meninggal
- [ ] Ada nilai edukasi (BPJS, asuransi, pemeriksaan, dana darurat, istirahat, dukungan sosial)

**Uji otomatis:** uji konten memeriksa data event & teks terhadap daftar kata terlarang (mis. "bunuh diri", "mengakhiri hidup", "menyakiti diri", "gila", "lemah mental") dan memastikan event bertema depresi selalu punya pilihan mencari bantuan.

## 4. Play Store

Tema kematian (non-grafis) dan kesehatan mental dicantumkan dengan jujur di kuesioner rating konten (IARC) saat rilis (Penutup v2 / M7). Deskripsi aplikasi menyebut bahwa game ini simulasi edukasi.
