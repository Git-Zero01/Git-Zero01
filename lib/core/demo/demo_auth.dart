import 'dart:async';

import 'package:nutri_auth/core/storage/secure_local_storage.dart';
import 'package:nutri_auth/features/auth/data/auth_repository.dart';
import 'package:nutri_auth/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository in-memory untuk **mode demo** (preview tampilan).
///
/// ⚠️ Tidak melakukan autentikasi sungguhan. Hanya untuk melihat dan menyentuh
/// UI tanpa backend. Aktifkan dengan `--dart-define=DEMO_MODE=true`.
///
/// Data hilang saat aplikasi dimuat ulang — tidak ada yang disimpan.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository();

  /// Akun-akun yang "sudah terdaftar" di demo ini, supaya AC-2 bisa dicoba.
  final Set<String> _registeredEmails = {
    'demo@nutri.app',
    'sudah@terdaftar.com',
  };

  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  Session? _session;

  // --------------------------------------------------------------- navigasi

  /// Ditampilkan di layar verifikasi agar tidak disalahartikan sebagai email
  /// sungguhan yang gagal terkirim.
  static const String demoNotice = 'Mode demo — tidak ada email sungguhan.';

  @override
  Stream<AuthState> authStateChanges() => _controller.stream;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  bool get isSignedIn => _session != null;

  @override
  bool get isEmailVerified =>
      _session != null && AuthRepository.isVerified(_session!.user);

  // ------------------------------------------------------------------- auth

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) async {
    await _latency();

    // AC-2: simulasi email duplikat.
    if (_registeredEmails.contains(email)) {
      throw AuthFailure.emailExists;
    }

    _registeredEmails.add(email);
    return SignUpResult(email: email, hasSession: false);
  }

  @override
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    await _latency();

    // AC-3: hanya email ini yang punya password demo12345.
    if (email == 'demo@nutri.app' && password == 'demo12345') {
      _session = _buildSession(email, verified: true);
      _emitSession();
      return SignInResult(isVerified: true, email: email);
    }

    // AC-4: email terdaftar tapi belum diverifikasi.
    if (email == 'belum@verifikasi.com') {
      return SignInResult(
        isVerified: false,
        email: email,
        failure: AuthFailure.emailNotConfirmed,
      );
    }

    // Sisanya: kredensial salah.
    return SignInResult(
      isVerified: false,
      email: email,
      failure: AuthFailure.invalidCredentials,
    );
  }

  @override
  Future<void> resendVerificationEmail({
    required String email,
    required String emailRedirectTo,
  }) async {
    await _latency();
  }

  @override
  Future<void> sendPasswordReset({
    required String email,
    required String emailRedirectTo,
  }) async {
    await _latency();
  }

  @override
  Future<void> handleDeepLink(Uri uri) async {
    await _latency();
    // Simulasikan user memverifikasi email lewat link.
    final pending = _session ?? _buildSession('demo@nutri.app', verified: false);
    _session = _buildSession(pending.user.email ?? 'demo@nutri.app', verified: true);
    _emitSession();
  }

  @override
  Future<void> refreshSession() async {}

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<User?> refreshUser() async => _session?.user;

  // -------------------------------------------------------------- internal

  /// Jeda artificial supaya spinner terlihat.
  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 450));

  void _emitSession() {
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
  }

  static Session _buildSession(String email, {required bool verified}) {
    final now = DateTime.now().toUtc().toIso8601String();
    final user = User(
      id: 'demo-user-id',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email,
      createdAt: now,
      emailConfirmedAt: verified ? now : null,
    );

    return Session(
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      expiresIn: 3600,
      tokenType: 'bearer',
      user: user,
    );
  }
}

/// Penyimpanan in-memory untuk mode demo — mengabaikan `flutter_secure_storage`
/// agar berjalan di browser tanpa konfigurasi tambahan.
class DemoSecureStorage extends SecureLocalStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      _values.containsKey('nutri.auth.session');

  @override
  Future<String?> accessToken() async => _values['nutri.auth.session'];

  @override
  Future<void> removePersistedSession() async =>
      _values.remove('nutri.auth.session');

  @override
  Future<void> persistSession(String persistSessionString) async =>
      _values['nutri.auth.session'] = persistSessionString;

  @override
  Future<String?> readPendingEmail() async => _values[SecureLocalStorage.pendingEmailKey];

  @override
  Future<void> writePendingEmail(String email) async =>
      _values[SecureLocalStorage.pendingEmailKey] = email;

  @override
  Future<void> clearPendingVerification() async {
    _values.remove(SecureLocalStorage.pendingEmailKey);
    _values.remove(SecureLocalStorage.pendingResendAtKey);
  }

  @override
  Future<DateTime?> readResendCooldownUntil() async {
    final raw = _values[SecureLocalStorage.pendingResendAtKey];
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
  }

  @override
  Future<void> writeResendCooldownUntil(DateTime at) async =>
      _values[SecureLocalStorage.pendingResendAtKey] =
          at.millisecondsSinceEpoch.toString();
}