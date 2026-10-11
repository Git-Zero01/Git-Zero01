import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_controllers.dart';
import '../widgets/auth_widgets.dart';

/// `/auth/sign-in` — AC-3 / AC-4 / TC-105FE-2.
///
/// Menangani kredensial salah dan email belum terverifikasi. Untuk kasus
/// kedua, email disimpan di secure storage lalu user diarahkan ke layar
/// verifikasi.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final ok = await ref.read(signInControllerProvider.notifier).submit();
    if (!mounted) return;

    if (ok) {
      // Router guard yang mengarahkan ke /onboarding begitu session terverifikasi.
      context.go(AppRoutes.onboarding);
      return;
    }

    // Email belum diverifikasi → ke layar verifikasi (AC-4).
    if (ref.read(signInControllerProvider).canResendVerification) {
      context.go(AppRoutes.verifyEmail);
      return;
    }

    final failure = ref.read(signInControllerProvider).failure;
    if (failure != null && failure.isRetryable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _resendVerification() async {
    final notifier = ref.read(signInControllerProvider.notifier);
    await notifier.submitForgotPassword();

    if (!mounted) return;
    final failure = ref.read(signInControllerProvider).failure;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(failure?.message ?? 'Email verifikasi telah dikirim ulang.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);

    return AuthScaffold(
      title: 'Selamat datang kembali',
      subtitle: 'Masuk untuk melanjutkan.',
      showBackButton: false,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Belum punya akun? '),
          TextButton(
            onPressed: state.isSubmitting ? null : () => context.go(AppRoutes.signUp),
            child: const Text('Daftar'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner menyusut sendiri saat error hilang (lihat AuthErrorBanner).
          AuthErrorBanner(failure: state.failure),
          // AC-4: link resend hanya untuk email belum terverifikasi.
          AnimatedSlot(
            visible: state.failure != null && state.canResendVerification,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.isSubmitting ? _resendVerification : null,
                icon: const Icon(Icons.outbox_outlined, size: 18),
                label: const Text('Kirim ulang email verifikasi'),
              ),
            ),
          ),
          EmailField(
            controller: _email,
            autofocus: true,
            errorText: state.emailError,
            onChanged: controller.emailChanged,
            onSubmitted: (_) => controller.passwordTouched(),
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordField(
            controller: _password,
            errorText: state.passwordError,
            onChanged: controller.passwordChanged,
            onSubmitted: (_) => _submit(),
          ),
          // "Lupa password?" menempel di bawah field password — sebelumnya
          // nyangkut di antara email dan password sehingga membingungkan.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go(AppRoutes.forgotPassword),
              child: const Text('Lupa password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Masuk',
            busy: state.isSubmitting,
            onPressed: state.isSubmitEnabled ? _submit : null,
          ),
        ],
      ),
    );
  }
}