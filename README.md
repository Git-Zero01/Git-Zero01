# NUTRI-105-FE — Auth UI (Sign Up / Sign In / Email Verification)

Implementasi mobile (Flutter) dari story **NUTRI-105-FE**: pengguna baru bisa
daftar dengan email + password, memverifikasi email, lalu masuk — dengan akun
terverifikasi dan siap lanjut ke onboarding profil.

- **Issue type:** Story / Feature · **Priority:** Blocker · **Estimasi:** 5 SP
- **Depends on:** NUTRI-102, NUTRI-104 · **Related BE:** NUTRI-105-BE
- **Stack:** Flutter 3.44.2 · Riverpod · go_router · Supabase (GoTrue)

---

## Menjalankan

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> \
  --dart-define=DEEP_LINK_SCHEME=nutri
```

Kredensial tidak di-hardcode. Tanpa `--dart-define` aplikasi menampilkan layar
konfigurasi yang jelas, bukan crash saat runtime.

### Requirement toolchain (lingkungan lokal)

Build Android butuh **JDK 21** — `java-25-openjdk` yang terpasang di mesin
developer ini ternyata hanya berisi JRE (tanpa `javac`) sehingga Gradle gagal
dengan `does not provide the required capabilities: [JAVA_COMPILER]`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --debug
```

Flutter 3.44.2 juga mensyaratkan **NDK 28.2.13676358**. Bila direktori NDK
ada tapi tidak lengkap (tidak ada `source.properties`), build gagal dengan
`CXX1101` — hapus direktorinya lalu build ulang, Gradle akan mengunduh ulang.

### Konfigurasi Supabase Dashboard

- **Authentication → Sign In / Providers → Email:** aktifkan **Confirm email**.
- **Authentication → URL Configuration:**
  - Site URL: `nutri://auth/callback`
  - Redirect URLs: `nutri://auth/callback`
- Deep link scheme (`nutri`) sudah didaftarkan di
  `android/app/src/main/AndroidManifest.xml` dan `ios/Runner/Info.plist`. Jika
  diubah lewat `--dart-define`, ubah juga kedua file tersebut.

---

## Struktur

```
lib/
├── main.dart                      # init Supabase + menangkap deep link
├── app.dart                       # MaterialApp.router + proses deep link
├── core/
│   ├── config/env.dart            # konfigurasi via --dart-define
│   ├── router/app_router.dart     # route + guard
│   ├── storage/secure_local_storage.dart
│   └── theme/app_theme.dart
└── features/auth/
    ├── data/
    │   ├── auth_repository.dart           # interface
    │   └── supabase_auth_repository.dart  # implementasi
    ├── domain/
    │   ├── auth_validators.dart           # AC-8, TC-105FE-3..8
    │   └── auth_failure.dart              # AC-2, AC-4
    └── presentation/
        ├── providers/
        │   ├── auth_providers.dart    # authStateProvider, authRepositoryProvider
        │   └── auth_controllers.dart  # state form + polling/cooldown
        ├── screens/                   # 4 route auth + /onboarding
        └── widgets/
```

Pemisahan `AuthRepository` (interface) dari `SupabaseAuthRepository` membuat
controller bisa diuji tanpa jaringan maupun kredensial Supabase.

---

## Riverpod providers

| Provider | Peran |
|---|---|
| `supabaseClientProvider` | Client Supabase; di-override di `main()` |
| `authRepositoryProvider` | **Wrapper** repository (diminta tiket) |
| `authStateProvider` | **Stream** `onAuthStateChange` dari SDK (diminta tiket) |
| `authStatusProvider` | Notifier turunan stream di atas; sumber `redirect` router |
| `secureStorageProvider` | `flutter_secure_storage` |
| `resendCooldownProvider` | Sisa cooldown resend |
| `pendingVerificationProvider` | Email yang menunggu verifikasi (TC-105FE-14) |
| `deepLinkProvider` | Deep link masuk saat app berjalan |
| `signUpControllerProvider` / `signInControllerProvider` / `verifyEmailControllerProvider` / `forgotPasswordControllerProvider` | State + aksi tiap layar |

---

## Peta Acceptance Criteria

| AC | Implementasi | Test |
|---|---|---|
| AC-1 Sign up valid → 201, redirect verify | `SupabaseAuthRepository.signUp` + guard `signUpControllerProvider.submit()` | `auth_controllers_test.dart` → TC-105FE-1 |
| AC-2 Email duplikat → error jelas | `AuthFailure.emailExists` (code `email_exists` / `user_already_exists`) | `auth_failure_test.dart`, `auth_controllers_test.dart` |
| AC-3 Sign in sukses → session di secure storage | `SecureLocalStorage` (Keychain / EncryptedSharedPreferences) | `auth_controllers_test.dart` |
| AC-4 Belum verified → error + link resend | `SignInResult.failure.canResend` + banner + tombol resend | `auth_controllers_test.dart` |
| AC-5 Resend rate-limited 60s | `VerifyEmailController.resendCooldown` (60s), dipersistensi | `auth_controllers_test.dart` |
| AC-6 Deep link → session aktif | `FlutterAuthClientOptions(detectSessionInUri: true)` + `DeepLinkHandler` | `auth_controllers_test.dart`, `auth_guard_test.dart` |
| AC-7 Auto-refresh; logout bila gagal | `autoRefreshToken: true` + `authStatusProvider.signOut()` + guard | lihat catatan di `docs/DEVIATIONS.md` §7 |
| AC-8 Semua input tervalidasi | `Validators` + `errorText` real-time | `validators_test.dart` |
| AC-9 Penyimpangan didokumentasikan | `docs/DEVIATIONS.md` | — |

## Peta Test Case

| TC | Status | Diuji oleh |
|---|---|---|
| TC-105FE-1 Sign up valid | ✅ | `auth_controllers_test.dart` |
| TC-105FE-2 Sign in setelah verify | ✅ | `auth_controllers_test.dart` |
| TC-105FE-3 Format email invalid | ✅ | `validators_test.dart` |
| TC-105FE-4 Password < 8 char | ✅ | `validators_test.dart` |
| TC-105FE-5 Password tanpa angka | ✅ | `validators_test.dart` |
| TC-105FE-6 Confirm mismatch | ✅ | `validators_test.dart` |
| TC-105FE-7 Email dengan emoji | ✅ | `validators_test.dart` |
| TC-105FE-8 Password whitespace | ✅ | `validators_test.dart` |
| TC-105FE-9 Rapid tap → 1 request | ✅ | `auth_controllers_test.dart` |
| TC-105FE-10 JWT expired → refresh + retry 1× | ⚠️ sebagian | Retry-1× ada di lapisan HTTP (BE). Lihat `docs/DEVIATIONS.md` §7 |
| TC-105FE-11 Refresh gagal → logout | ⚠️ sebagian | Logout + guard ada; pemicu refresh ada di lapisan HTTP (BE) |
| TC-105FE-12 Buka link verifikasi | ✅ | `auth_controllers_test.dart` |
| TC-105FE-13 Link expired | ✅ | `auth_controllers_test.dart` |
| TC-105FE-14 Close app di verify screen | ✅ | `auth_controllers_test.dart` + `auth_guard_test.dart` |
| TC-105FE-15 Small screen, no overflow | ✅ | `AuthScaffold` (`SingleChildScrollView` + `ConstrainedBox` + max width 440) |

Menjalankan test:

```bash
flutter test        # 69 test
flutter analyze     # bersih
```

---

## Catatan

- `docs/DEVIATIONS.md` memuat semua keputusan yang dibebaskan tiket beserta
  alasannya, termasuk **bagian "Input Validation Rules" yang tidak disertakan**
  di brief — aturan password dibuat configurable sampai Aturan lengkap
  dikonfirmasi.
- `/onboarding` masih placeholder; pengisian profil berada di luar scope
  NUTRI-105-FE.
- Pengujian manual end-to-end (AC-1 s/d AC-7) memerlukan project Supabase nyata
  dan belum dijalankan di lingkungan ini — hanya unit test tanpa jaringan.