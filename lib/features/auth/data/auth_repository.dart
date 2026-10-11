import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';

/// Hasil sign up.
///
/// Supabase bisa mengembalikan session langsung kalau "Confirm email" dimatikan
/// di dashboard. Kita tetap mengarahkan user ke layar verifikasi sesuai
/// requirement, tapi nilai [hasSession] dicek supaya tidak ada session yang
/// bocor ke state aplikasi.
class SignUpResult {
  const SignUpResult({
    required this.email,
    required this.hasSession,
    this.userId,
  });

  final String email;
  final bool hasSession;
  final String? userId;
}

/// Hasil sign in.
///
/// Kegagalan tidak dilempar sebagai exception, tapi dikembalikan lewat
/// [failure] supaya layar sign-in bisa bereaksi spesifik (mis. menampilkan
/// tombol resend hanya untuk [AuthFailureKind.emailNotVerified]).
class SignInResult {
  const SignInResult({
    required this.isVerified,
    required this.email,
    this.failure,
  });

  final bool isVerified;
  final String email;
  final AuthFailure? failure;

  bool get isSuccess => failure == null;
}

/// Kontrak repository auth.
///
/// Dipisah dari implementasi Supabase supaya controller bisa diuji tanpa
/// jaringan — `authRepositoryProvider` tetap memenuhi requirement tiket
/// sebagai "wrapper".
abstract class AuthRepository {
  Stream<AuthState> authStateChanges();

  Session? get currentSession;

  User? get currentUser;

  bool get isSignedIn;

  bool get isEmailVerified;

  /// AC-1 / AC-2. Email duplikat dilempar sebagai [AuthFailure] dengan kind
  /// [AuthFailureKind.emailAlreadyRegistered].
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  });

  /// AC-3 / AC-4. Kredensial salah dan email belum terverifikasi masing-masing
  /// menghasilkan [SignInResult] dengan `failure` yang berbeda.
  Future<SignInResult> signIn({
    required String email,
    required String password,
  });

  /// AC-5. Cooldown 60s ditegakkan di sisi UI; rate limit sesungguhnya ada
  /// di sisi BE.
  Future<void> resendVerificationEmail({
    required String email,
    required String emailRedirectTo,
  });

  Future<void> sendPasswordReset({
    required String email,
    required String emailRedirectTo,
  });

  /// AC-6. Tukar hasil deep link menjadi session aktif.
  Future<void> handleDeepLink(Uri uri);

  /// AC-7 / TC-105FE-10.
  Future<void> refreshSession();

  Future<void> signOut();

  /// Refresh metadata user tanpa menukar session.
  Future<User?> refreshUser();

  /// Status verifikasi untuk user tertentu.
  ///
  /// `email_verified` di app_metadata dibaca lebih dulu karena backend dapat
  /// menandainya di sana; `emailConfirmedAt` dipakai sebagai fallback.
  static bool isVerified(User user) {
    final metadataVerified = (user.userMetadata ?? const {})['email_verified'];
    if (metadataVerified is bool) return metadataVerified;
    return user.emailConfirmedAt != null;
  }
}