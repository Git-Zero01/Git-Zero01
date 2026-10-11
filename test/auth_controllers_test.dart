import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_auth/core/storage/secure_local_storage.dart';
import 'package:nutri_auth/features/auth/data/auth_repository.dart';
import 'package:nutri_auth/features/auth/domain/auth_failure.dart';
import 'package:nutri_auth/features/auth/presentation/providers/auth_controllers.dart';
import 'package:nutri_auth/features/auth/presentation/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Penyimpanan in-memory agar test tidak menyentuh platform channel.
class FakeSecureLocalStorage extends SecureLocalStorage {
  FakeSecureLocalStorage();

  final Map<String, String> store = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => store.containsKey('nutri.auth.session');

  @override
  Future<String?> accessToken() async => store['nutri.auth.session'];

  @override
  Future<void> removePersistedSession() async =>
      store.remove('nutri.auth.session');

  @override
  Future<void> persistSession(String value) async =>
      store['nutri.auth.session'] = value;

  @override
  Future<String?> readPendingEmail() async => store[SecureLocalStorage.pendingEmailKey];

  @override
  Future<void> writePendingEmail(String email) async => store[SecureLocalStorage.pendingEmailKey] = email;

  @override
  Future<void> clearPendingVerification() async {
    store.remove(SecureLocalStorage.pendingEmailKey);
    store.remove(SecureLocalStorage.pendingResendAtKey);
  }

  @override
  Future<DateTime?> readResendCooldownUntil() async {
    final raw = store[SecureLocalStorage.pendingResendAtKey];
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
  }

  @override
  Future<void> writeResendCooldownUntil(DateTime at) async =>
      store[SecureLocalStorage.pendingResendAtKey] = at.millisecondsSinceEpoch.toString();
}

/// Repository palsu yang mencatat jumlah panggilan (dipakai TC-105FE-9).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository();

  int signUpCalls = 0;
  int signInCalls = 0;
  int resendCalls = 0;
  int signOutCalls = 0;

  /// Error yang akan dilempar/ditembalikan pada panggilan berikutnya.
  AuthFailure? signUpError;
  AuthFailure? signInError;
  AuthFailure? resendError;
  AuthFailure? deepLinkError;

  SignUpResult? nextSignUpResult;
  SignInResult? nextSignInResult;

  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> authStateChanges() => _controller.stream;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  bool get isSignedIn => false;

  @override
  bool get isEmailVerified => false;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) async {
    signUpCalls++;
    final err = signUpError;
    if (err != null) throw err;
    return nextSignUpResult ?? SignUpResult(email: email, hasSession: false);
  }

  @override
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final err = signInError;
    if (err != null) {
      return SignInResult(isVerified: false, email: email, failure: err);
    }
    return nextSignInResult ??
        SignInResult(isVerified: true, email: email);
  }

  @override
  Future<void> resendVerificationEmail({
    required String email,
    required String emailRedirectTo,
  }) async {
    resendCalls++;
    final err = resendError;
    if (err != null) throw err;
  }

  @override
  Future<void> sendPasswordReset({
    required String email,
    required String emailRedirectTo,
  }) async {}

  @override
  Future<void> handleDeepLink(Uri uri) async {
    final err = deepLinkError;
    if (err != null) throw err;
  }

  @override
  Future<void> refreshSession() async {}

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<User?> refreshUser() async => null;

  Future<void> dispose() => _controller.close();
}

void main() {
  late FakeAuthRepository repository;
  late FakeSecureLocalStorage storage;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        secureStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repository = FakeAuthRepository();
    storage = FakeSecureLocalStorage();
  });

  group('SignUpController', () {
    test('tombol disabled sampai form valid', () {
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);
      final state = c.read(signUpControllerProvider);

      expect(state.isSubmitEnabled, isFalse);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc123');
      expect(c.read(signUpControllerProvider).isSubmitEnabled, isFalse,
          reason: 'password < 8 karakter');

      notifier.passwordChanged('abc12345');
      expect(c.read(signUpControllerProvider).isSubmitEnabled, isFalse,
          reason: 'konfirmasi masih kosong');

      notifier.confirmPasswordChanged('abc12345');
      expect(c.read(signUpControllerProvider).isSubmitEnabled, isTrue);
    });

    test('TC-105FE-1: sign up valid berhasil dan simpan email pending', () async {
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc12345');
      notifier.confirmPasswordChanged('abc12345');

      final ok = await notifier.submit();

      expect(ok, isTrue);
      expect(repository.signUpCalls, 1);
      expect(await storage.readPendingEmail(), 'budi@example.com');
    });

    test('TC-105FE-9: rapid tap hanya mengirim 1 request', () async {
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc12345');
      notifier.confirmPasswordChanged('abc12345');

      final results = await Future.wait<bool>([
        notifier.submit(),
        notifier.submit(),
        notifier.submit(),
      ]);

      expect(repository.signUpCalls, 1);
      expect(results.where((r) => r).length, 1);
    });

    test('form tidak valid tidak menembak request', () async {
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);

      notifier.emailChanged('bukan-email');
      final ok = await notifier.submit();

      expect(ok, isFalse);
      expect(repository.signUpCalls, 0);
      expect(c.read(signUpControllerProvider).emailTouched, isTrue);
    });

    test('AC-2: email duplikat menampilkan error jelas', () async {
      repository.signUpError = AuthFailure.emailExists;
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc12345');
      notifier.confirmPasswordChanged('abc12345');

      final ok = await notifier.submit();

      expect(ok, isFalse);
      final failure = c.read(signUpControllerProvider).failure;
      expect(failure, isNotNull);
      expect(failure!.kind, AuthFailureKind.emailAlreadyRegistered);
      expect(failure.message, contains('sudah terdaftar'));
      //.isSubmitting harus kembali false agar user bisa mencoba lagi.
      expect(c.read(signUpControllerProvider).isSubmitting, isFalse);
    });

    test('validasi real-time: error muncul setelah field disentuh', () {
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);

      notifier.emailChanged('salah');
      expect(c.read(signUpControllerProvider).emailError, isNull,
          reason: 'belum disentuh → belum tampil error');

      notifier.emailTouched();
      expect(c.read(signUpControllerProvider).emailError, isNotNull);
    });

    test('confirm password mismatch terdeteksi real-time', () {
      final c = makeContainer();
      final notifier = c.read(signUpControllerProvider.notifier);

      notifier.passwordChanged('abc12345');
      notifier.confirmPasswordChanged('abc99999');
      notifier.confirmPasswordTouched();

      expect(c.read(signUpControllerProvider).confirmError,
          'Konfirmasi password tidak sama');
    });
  });

  group('SignInController', () {
    test('AC-3: sign in sukses', () async {
      final c = makeContainer();
      final notifier = c.read(signInControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc12345');

      final ok = await notifier.submit();

      expect(ok, isTrue);
      expect(repository.signInCalls, 1);
    });

    test('TC-105FE-2: kredensial salah ditolak dengan pesan jelas', () async {
      repository.signInError = AuthFailure.invalidCredentials;
      final c = makeContainer();
      final notifier = c.read(signInControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('salahsekali');

      final ok = await notifier.submit();

      expect(ok, isFalse);
      expect(c.read(signInControllerProvider).failure!.kind,
          AuthFailureKind.invalidCredentials);
    });

    test('AC-4: email belum terverifikasi → canResend + email tersimpan', () async {
      repository.signInError = AuthFailure.emailNotConfirmed;
      final c = makeContainer();
      final notifier = c.read(signInControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc12345');

      final ok = await notifier.submit();

      expect(ok, isFalse);
      expect(c.read(signInControllerProvider).canResendVerification, isTrue);
      expect(await storage.readPendingEmail(), 'budi@example.com');
    });

    test('TC-105FE-9: rapid tap sign in hanya 1 request', () async {
      final c = makeContainer();
      final notifier = c.read(signInControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('abc12345');

      await Future.wait<bool>([notifier.submit(), notifier.submit(), notifier.submit()]);

      expect(repository.signInCalls, 1);
    });

    test('kredensial salah tidak menawarkan resend', () async {
      repository.signInError = AuthFailure.invalidCredentials;
      final c = makeContainer();
      final notifier = c.read(signInControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      notifier.passwordChanged('salahsekali');
      await notifier.submit();

      expect(c.read(signInControllerProvider).canResendVerification, isFalse);
    });
  });

  group('VerifyEmailController — cooldown', () {
    test('AC-5: resend memicu cooldown 60 detik', () async {
      final c = makeContainer();
      await c.read(pendingVerificationProvider.notifier).set('budi@example.com');

      final notifier = c.read(verifyEmailControllerProvider.notifier);
      await notifier.resend();

      expect(repository.resendCalls, 1);

      final until = await storage.readResendCooldownUntil();
      expect(until, isNotNull);
      final seconds = until!.difference(DateTime.now()).inSeconds;
      // Toleransi 1 detik untuk waktu eksekusi test.
      expect(seconds, inInclusiveRange(58, 60));

      final cooldown = c.read(resendCooldownProvider);
      expect(cooldown, isNotNull);
    });

    test('resend tanpa email pending tidak menembak request', () async {
      final c = makeContainer();
      await c.read(verifyEmailControllerProvider.notifier).resend();
      expect(repository.resendCalls, 0);
    });

    test('TC-105FE-14: cooldown pulih dari secure storage setelah reopen', () async {
      await storage.writeResendCooldownUntil(
        DateTime.now().add(const Duration(seconds: 45)),
      );

      final c = makeContainer();
      await c.read(verifyEmailControllerProvider.notifier).restoreCooldown();

      final until = c.read(resendCooldownProvider);
      expect(until, isNotNull);
      final remaining = until!.difference(DateTime.now()).inSeconds;
      expect(remaining, inInclusiveRange(43, 45));
    });

    test('cooldown yang sudah lewat tidak diaktifkan', () async {
      await storage.writeResendCooldownUntil(
        DateTime.now().subtract(const Duration(seconds: 10)),
      );

      final c = makeContainer();
      await c.read(verifyEmailControllerProvider.notifier).restoreCooldown();

      expect(c.read(resendCooldownProvider), isNull);
    });

    test('TC-105FE-13: link kedaluwarsa → error + canResend', () async {
      repository.deepLinkError = AuthFailure.linkExpired;
      final c = makeContainer();

      final ok = await c
          .read(verifyEmailControllerProvider.notifier)
          .handleDeepLink(Uri.parse('nutri://auth/callback?error=expired'));

      expect(ok, isFalse);
      final state = c.read(verifyEmailControllerProvider);
      expect(state.linkError, isNotNull);
      expect(state.linkError!.canResend, isTrue);
      expect(state.linkError!.message, contains('kedaluwarsa'));
    });

    test('AC-6: deep link valid → session aktif', () async {
      final c = makeContainer();

      final ok = await c
          .read(verifyEmailControllerProvider.notifier)
          .handleDeepLink(Uri.parse('nutri://auth/callback?code=abc'));

      expect(ok, isTrue);
      expect(c.read(verifyEmailControllerProvider).linkError, isNull);
    });
  });

  group('ForgotPasswordController', () {
    test('email invalid tidak bisa submit', () async {
      final c = makeContainer();
      final notifier = c.read(forgotPasswordControllerProvider.notifier);

      notifier.emailChanged('bukan-email');
      expect(c.read(forgotPasswordControllerProvider).isSubmitEnabled, isFalse);

      final ok = await notifier.submit();
      expect(ok, isFalse);
    });

    test('email valid → terkirim', () async {
      final c = makeContainer();
      final notifier = c.read(forgotPasswordControllerProvider.notifier);

      notifier.emailChanged('budi@example.com');
      final ok = await notifier.submit();

      expect(ok, isTrue);
      expect(c.read(forgotPasswordControllerProvider).isSent, isTrue);
    });
  });
}