# Penyimpangan dari Rekomendasi — NUTRI-105-FE

Dokumen ini memenuhi **AC-9**: "Penyimpangan dari rekomendasi didokumentasikan."

Tiket diberikan lima keputusan terbuka untuk diambil engineer. Berikut pilihan yang
diambil beserta alasannya.

---

## 1. Supabase SDK: `supabase_flutter` (mengikuti rekomendasi)

**Keputusan:** memakai `supabase_flutter`, bukan custom Dio.

**Alasan:**
- Menghemat waktu integrasi dan detriment terhadap DE ticket NUTRI-105-BE
  (auth server, PKCE, rate limit) — SDK sudah menangani PKCE dan refresh token.
- Mendukung alur deep link bawaan (`detectSessionInUri`), yangrequirement
  AC-6 butuh.
- Risiko: versi SDK cukup cepat berubah (terpasang `supabase_flutter 2.18.2` /
  `gotrue 2.27.3`). Lapisan data sudah dipisah ke interface `AuthRepository`
  sehingga penggantian ke custom Dio nanti hanya menyentuh
  `SupabaseAuthRepository`.

## 2. Polling 5 detik (mengikuti spesifikasi tiket)

**Keputusan:** polling tiap 5 detik di layar verifikasi, sesuai tiket.

**Alasan:**requirement eksplisit "Polling status verifikasi setiap 5s", jadi
tidak ada dasar untuk menyimpang.

**Catatan:** push realtime (Supabase Realtime) akan lebih hemat battery dan
latency, tapi menambah dependensi channel yang harus dijaga. Jika BE NUTRI-105-BE
sudah menyiapkan channel, ini kandidat optimasi lanjutan — belum dikerjakan di
scope 5 SP ini.

## 3. Pisahkan route, bukan tab dalam satu screen (menyimpang)

**Keputusan:** tiap layar terpisah, bukan satu screen dengan tab.

**Alasan:** tiket menyebut route eksplisit (`/auth/sign-up`, `/auth/sign-in`,
`/auth/verify-email`, `/auth/forgot-password`) dan router guard yang
membedakan "butuh auth" vs "butuh verified". Satu screen bertab akan menghapus
URL yang bisa di-bookmark dan-fired deep link dari email, sehingga AC-6 sulit
memenuhi.

## 4. Cooldown resend dipersistensi ke secure storage (tambahan)

**Keputusan:** waktu habis cooldown disimpan di `flutter_secure_storage`, bukan
hanya state di memori.

**Alasan:** TC-105FE-14 mensyaratkan user yang menutup app di layar verifikasi
lalu membukanya kembali tetap berada di state yang sama. Kalau cooldown hanya di
memori, membuka ulang app akan langsung mengaktifkan tombol "Kirim ulang" dan
melewati rate limit server.

## 5. Aturan password dibuat configurable, default longgar (menyimpang)

**Keputusan:** `PasswordPolicy` dengan default **hanya** mewajibkan panjang ≥ 8,
mengandung huruf, dan mengandung angka. Aturan huruf besar & simbol tersedia
tetapi **nonaktif**.

**Alasan:** bagian **"Input Validation Rules" tidak disertakan** di brief yang
diterima (acuan di "lihat Input Validation Rules"), dan tidak ada satu pun test
case yang meminta huruf besar atau simbol. Menaktifkannya secara default
menghindari penolakan password yang seharusnya lolos seluruh TC-105FE-4/5/8.

**Tindakan lanjutan yang diperlukan:** konfirmasi ke PO/BE apakah aturan
lengkap (huruf besar, simbol, panjang minimum 8 atau 12) akan ditambahkan.
Jika ya, cukup ubah konstanta `PasswordPolicy.defaultPolicy` — seluruh UI dan
test ikut menyesuaikan karena semuanya membaca dari sana.

## 6. Pesan reset password tidak membocorkan keberadaan email

**Keputusan:** layar `/auth/forgot-password` selalu menampilkan pesan sukses yang
sama, baik email terdaftar maupun tidak.

**Alasan:** di luar spesifikasi tertulis, tapi mencegah user enumeration — pola
standar pada halaman login publik. Tidak ada TC yang bertentangan.

## 7. Auto-logout hanya setelah refresh gagal (mengikuti spesifikasi)

**Keputusan:** `autoRefreshToken: true` di Supabase (SDK refresh sendiri di
background) **dan** `refreshSession()` eksplisit dipanggil saat butuh retry-1×.

**Catatan:** TC-105FE-10 ("JWT expired saat akses API → auto-refresh + retry 1×")
menyangkut lapisan HTTP saat memanggil API setelah login. Lapisan itu milik
NUTRI-105-BE / integrasi API, bukan layar auth. Yang dikerjakan di sini adalah
sumbernya: session tersimpan di secure storage, refresh tersedia, dan router
guard memaksa user keluar bila session hilang.