import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import 'auth_repository.dart';

/// Implementasi [AuthRepository] di atas Supabase GoTrue SDK.
///
/// Semua exception diterjemahkan jadi [AuthFailure] sehingga layer
/// presentation tidak pernah menampilkan pesan mentah dari server.
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  // ---------------------------------------------------------------- session

  @override
  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  bool get isSignedIn => currentSession != null;

  @override
  bool get isEmailVerified => currentUser != null && AuthRepository.isVerified(currentUser!);

  // ------------------------------------------------------------------- auth

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );

      final user = res.user;
      return SignUpResult(
        email: user?.email ?? email,
        hasSession: res.session != null,
        userId: user?.id,
      );
    } on AuthException catch (e) {
      // Semua subclass GoTrue (AuthApiException, AuthRetryableFetchException,
      // dll.) extends AuthException, jadi satu catch ini mencakup semuanya.
      throw AuthFailure.fromSupabase(
        code: e.code,
        message: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  @override
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = res.session;
      final user = res.user;

      if (session == null || user == null) {
        return SignInResult(
          isVerified: false,
          email: email,
          failure: AuthFailure.invalidCredentials,
        );
      }

      if (!AuthRepository.isVerified(user)) {
        // Jangan tahan session milik akun yang belum terverifikasi; router
        // guard akan mengarahkan ke /auth/verify-email.
        await _client.auth.signOut(scope: SignOutScope.local);

        return SignInResult(
          isVerified: false,
          email: user.email ?? email,
          failure: AuthFailure.emailNotConfirmed,
        );
      }

      return SignInResult(isVerified: true, email: user.email ?? email);
    } on AuthException catch (e) {
      return SignInResult(
        isVerified: false,
        email: email,
        failure: AuthFailure.fromSupabase(
          code: e.code,
          message: e.message,
          statusCode: e.statusCode,
        ),
      );
    }
  }

  @override
  Future<void> resendVerificationEmail({
    required String email,
    required String emailRedirectTo,
  }) async {
    try {
      await _client.auth.resend(
        type: OtpType.email,
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
    } on AuthException catch (e) {
      throw AuthFailure.fromSupabase(
        code: e.code,
        message: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  @override
  Future<void> sendPasswordReset({
    required String email,
    required String emailRedirectTo,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: emailRedirectTo);
    } on AuthException catch (e) {
      throw AuthFailure.fromSupabase(
        code: e.code,
        message: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  @override
  Future<void> handleDeepLink(Uri uri) async {
    try {
      // `session` di AuthSessionUrlResponse non-nullable, jadi link rusak
      // dilempar sebagai AuthException dan tertangkap di bawah — bukan lewat
      // pengecekan null.
      final res = await _client.auth.getSessionFromUrl(uri);

      await _client.auth.getUser(res.session.accessToken);
    } on AuthException catch (e) {
      throw AuthFailure.fromSupabase(
        code: e.code,
        message: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  @override
  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
    } on AuthException catch (e) {
      throw AuthFailure.fromSupabase(
        code: e.code,
        message: e.message,
        statusCode: e.statusCode,
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<User?> refreshUser() async {
    try {
      final res = await _client.auth.getUser();
      return res.user;
    } on AuthException {
      return null;
    }
  }
}