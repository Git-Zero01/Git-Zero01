import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../domain/auth_failure.dart';
import '../../domain/auth_validators.dart';
import 'auth_providers.dart';

/// State form sign up.
///
///Validasi dihitung real-time (AC-8) dan tombol submit memakai
/// [isSubmitEnabled] yang hanya aktif saat semua field valid.
class SignUpFormState {
  const SignUpFormState({
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.emailTouched = false,
    this.passwordTouched = false,
    this.confirmTouched = false,
    this.isSubmitting = false,
    this.failure,
  });

  final String email;
  final String password;
  final String confirmPassword;

  final bool emailTouched;
  final bool passwordTouched;
  final bool confirmTouched;

  /// Syarat TC-105FE-9: request kedua saat submit pertama masih berjalan
  /// diabaikan.
  final bool isSubmitting;

  final AuthFailure? failure;

  SignUpFormState copyWith({
    String? email,
    String? password,
    String? confirmPassword,
    bool? emailTouched,
    bool? passwordTouched,
    bool? confirmTouched,
    bool? isSubmitting,
    AuthFailure? failure,
    bool clearFailure = false,
  }) {
    return SignUpFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      emailTouched: emailTouched ?? this.emailTouched,
      passwordTouched: passwordTouched ?? this.passwordTouched,
      confirmTouched: confirmTouched ?? this.confirmTouched,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  String? get emailError =>
      emailTouched ? Validators.email(email) : null;

  String? get passwordError =>
      passwordTouched ? Validators.password(password) : null;

  String? get confirmError => confirmTouched
      ? Validators.confirmPassword(confirmPassword, password)
      : null;

  PasswordStrength get strength => Validators.strength(password);

  bool get isFormValid =>
      Validators.email(email) == null &&
      Validators.password(password) == null &&
      Validators.confirmPassword(confirmPassword, password) == null;

  /// Tombol disabled sampai form valid DAN tidak sedang mengirim.
  bool get isSubmitEnabled => isFormValid && !isSubmitting;
}

class SignUpController extends Notifier<SignUpFormState> {
  @override
  SignUpFormState build() => const SignUpFormState();

  void emailChanged(String value) =>
      state = state.copyWith(email: value, clearFailure: true);

  void passwordChanged(String value) =>
      state = state.copyWith(password: value, clearFailure: true);

  void confirmPasswordChanged(String value) =>
      state = state.copyWith(confirmPassword: value, clearFailure: true);

  void emailTouched() => state = state.copyWith(emailTouched: true);
  void passwordTouched() => state = state.copyWith(passwordTouched: true);
  void confirmPasswordTouched() => state = state.copyWith(confirmTouched: true);

  /// Kembalikan `true` bila sign up berhasil. Email tujuan disimpan agar
  /// layar verifikasi bisa menampilkannya dan bertahan setelah app ditutup
  /// (TC-105FE-14).
  Future<bool> submit() async {
    if (state.isSubmitting) return false; // TC-105FE-9

    state = state.copyWith(
      emailTouched: true,
      passwordTouched: true,
      confirmTouched: true,
    );

    if (!state.isFormValid) return false;

    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      await ref.read(authRepositoryProvider).signUp(
            email: state.email.trim(),
            password: state.password,
            emailRedirectTo: Env.emailRedirectUrl,
          );

      await ref.read(pendingVerificationProvider.notifier).set(state.email.trim());
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(isSubmitting: false, failure: e);
      return false;
    }
  }
}

final signUpControllerProvider =
    NotifierProvider<SignUpController, SignUpFormState>(SignUpController.new);

/// State form sign in.
class SignInFormState {
  const SignInFormState({
    this.email = '',
    this.password = '',
    this.emailTouched = false,
    this.passwordTouched = false,
    this.isSubmitting = false,
    this.failure,
  });

  final String email;
  final String password;
  final bool emailTouched;
  final bool passwordTouched;
  final bool isSubmitting;
  final AuthFailure? failure;

  SignInFormState copyWith({
    String? email,
    String? password,
    bool? emailTouched,
    bool? passwordTouched,
    bool? isSubmitting,
    AuthFailure? failure,
    bool clearFailure = false,
  }) {
    return SignInFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      emailTouched: emailTouched ?? this.emailTouched,
      passwordTouched: passwordTouched ?? this.passwordTouched,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  String? get emailError => emailTouched ? Validators.email(email) : null;
  String? get passwordError =>
      passwordTouched ? Validators.password(password) : null;

  bool get isFormValid =>
      Validators.email(email) == null && password.isNotEmpty;

  bool get isSubmitEnabled => isFormValid && !isSubmitting;

  /// AC-4: tampilkan aksi resend hanya untuk kasus email belum terverifikasi.
  bool get canResendVerification =>
      failure?.canResend ?? false;
}

class SignInController extends Notifier<SignInFormState> {
  @override
  SignInFormState build() => const SignInFormState();

  void emailChanged(String value) =>
      state = state.copyWith(email: value, clearFailure: true);

  void passwordChanged(String value) =>
      state = state.copyWith(password: value, clearFailure: true);

  void emailTouched() => state = state.copyWith(emailTouched: true);
  void passwordTouched() => state = state.copyWith(passwordTouched: true);

  /// Kembalikan `true` hanya bila sign in sukses **dan** email terverifikasi.
  /// Untuk email belum terverifikasi, controller menyimpan email tujuan lalu
  /// mengembalikan `false`; pemanggil mengarahkan ke layar verifikasi.
  Future<bool> submit() async {
    if (state.isSubmitting) return false;

    state = state.copyWith(emailTouched: true, passwordTouched: true);
    if (!state.isFormValid) return false;

    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      final result = await ref.read(authRepositoryProvider).signIn(
            email: state.email.trim(),
            password: state.password,
          );

      if (!result.isSuccess) {
        state = state.copyWith(isSubmitting: false, failure: result.failure);
        if (result.failure?.kind == AuthFailureKind.emailNotVerified) {
          await ref.read(pendingVerificationProvider.notifier).set(result.email);
        }
        return false;
      }

      await ref.read(pendingVerificationProvider.notifier).clear();
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(isSubmitting: false, failure: e);
      return false;
    }
  }

  /// Ganti password dengan email yang sama (untuk kasus "belum diverifikasi").
  Future<void> submitForgotPassword() async {
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(
            email: state.email.trim(),
            emailRedirectTo: Env.emailRedirectUrl,
          );
      state = state.copyWith(isSubmitting: false);
    } on AuthFailure catch (e) {
      state = state.copyWith(isSubmitting: false, failure: e);
    }
  }
}

final signInControllerProvider =
    NotifierProvider<SignInController, SignInFormState>(SignInController.new);

/// Controller reset password (route `/auth/forgot-password`).
class ForgotPasswordState {
  const ForgotPasswordState({
    this.email = '',
    this.isSubmitting = false,
    this.isSent = false,
    this.failure,
  });

  final String email;
  final bool isSubmitting;
  final bool isSent;
  final AuthFailure? failure;

  ForgotPasswordState copyWith({
    String? email,
    bool? isSubmitting,
    bool? isSent,
    AuthFailure? failure,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSent: isSent ?? this.isSent,
      failure: failure,
    );
  }

  String? get emailError => Validators.email(email);
  bool get isSubmitEnabled =>
      Validators.email(email) == null && !isSubmitting;
}

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  void emailChanged(String value) =>
      state = ForgotPasswordState(email: value, isSent: state.isSent);

  Future<bool> submit() async {
    if (state.isSubmitting) return false;
    if (Validators.email(state.email) != null) return false;

    state = state.copyWith(isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(
            email: state.email.trim(),
            emailRedirectTo: Env.emailRedirectUrl,
          );
      state = state.copyWith(isSubmitting: false, isSent: true);
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(isSubmitting: false, failure: e);
      return false;
    }
  }
}

final forgotPasswordControllerProvider = NotifierProvider<
    ForgotPasswordController, ForgotPasswordState>(ForgotPasswordController.new);

/// Controller layar verifikasi email.
///
/// Menangani polling 5 detik, cooldown 60 detik, dan deep link (AC-5, AC-6).
class VerifyEmailState {
  const VerifyEmailState({
    this.isResending = false,
    this.isVerifying = false,
    this.linkError,
    this.lastSentAt,
  });

  final bool isResending;
  final bool isVerifying;

  /// Error hasil deep link (mis. link kedaluwarsa, TC-105FE-13).
  final AuthFailure? linkError;

  final DateTime? lastSentAt;

  VerifyEmailState copyWith({
    bool? isResending,
    bool? isVerifying,
    AuthFailure? linkError,
    bool clearLinkError = false,
    DateTime? lastSentAt,
  }) {
    return VerifyEmailState(
      isResending: isResending ?? this.isResending,
      isVerifying: isVerifying ?? this.isVerifying,
      linkError: clearLinkError ? null : (linkError ?? this.linkError),
      lastSentAt: lastSentAt ?? this.lastSentAt,
    );
  }
}

class VerifyEmailController extends Notifier<VerifyEmailState> {
  Timer? _pollTimer;

  /// Interval polling sesuai requirement tiket.
  static const Duration pollInterval = Duration(seconds: 5);

  /// Cooldown tombol "Kirim ulang" (AC-5).
  static const Duration resendCooldown = Duration(seconds: 60);

  @override
  VerifyEmailState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const VerifyEmailState();
  }

  /// Mulai polling status verifikasi setiap 5 detik.
  ///
  /// Berhenti otomatis saat user sudah terverifikasi atau saat widget
  /// dilepas, supaya tidak ada timer yang berjalan sia-sia.
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _checkStatus());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkStatus() async {
    final status = ref.read(authStatusProvider);
    if (status.isEmailVerified) {
      stopPolling();
      ref.read(authStatusProvider.notifier).markVerified();
      return;
    }

    await ref.read(authStatusProvider.notifier).refresh();
  }

  /// Tombol "Kirim ulang" —TC-105FE-5 (cooldown).
  Future<void> resend() async {
    if (state.isResending) return;

    // Dibaca langsung dari secure storage, bukan dari AsyncValue, supaya
    // tidak bergantung pada urutan settle-nya provider.
    final email = await ref.read(secureStorageProvider).readPendingEmail();
    if (email == null || email.isEmpty) return;

    state = state.copyWith(isResending: true, clearLinkError: true);

    try {
      await ref.read(authRepositoryProvider).resendVerificationEmail(
            email: email,
            emailRedirectTo: Env.emailRedirectUrl,
          );

      final until = DateTime.now().add(resendCooldown);
      ref.read(resendCooldownProvider.notifier).start(resendCooldown);
      await ref
          .read(secureStorageProvider)
          .writeResendCooldownUntil(until);

      state = state.copyWith(isResending: false, lastSentAt: DateTime.now());
    } on AuthFailure catch (e) {
      state = state.copyWith(isResending: false, linkError: e);
    }
  }

  /// Pulihkan cooldown dari secure storage saat app dibuka ulang (TC-105FE-14).
  Future<void> restoreCooldown() async {
    final until = await ref.read(secureStorageProvider).readResendCooldownUntil();
    if (until == null) return;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) return;
    ref.read(resendCooldownProvider.notifier).start(remaining);
  }

  /// Proses deep link dari email (AC-6 / TC-105FE-12).
  Future<bool> handleDeepLink(Uri uri) async {
    state = state.copyWith(isVerifying: true, clearLinkError: true);
    try {
      await ref.read(authRepositoryProvider).handleDeepLink(uri);
      await ref.read(authStatusProvider.notifier).refresh();
      await ref.read(pendingVerificationProvider.notifier).clear();
      state = state.copyWith(isVerifying: false);
      stopPolling();
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(isVerifying: false, linkError: e);
      return false;
    }
  }

  void clearLinkError() => state = state.copyWith(clearLinkError: true);
}

final verifyEmailControllerProvider =
    NotifierProvider<VerifyEmailController, VerifyEmailState>(
  VerifyEmailController.new,
);