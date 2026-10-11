import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../domain/auth_validators.dart';
import '../providers/auth_controllers.dart';
import '../widgets/auth_widgets.dart';

/// `/auth/sign-up` — TC-105FE-1.
///
/// Tombol disabled sampai form valid; setelah sukses langsung ke
/// `/auth/verify-email`.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirm;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final ok = await ref.read(signUpControllerProvider.notifier).submit();
    if (!mounted) return;

    if (ok) {
      context.go(AppRoutes.verifyEmail);
      return;
    }

    final failure = ref.read(signUpControllerProvider).failure;
    if (failure != null && failure.isRetryable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);
    final controller = ref.read(signUpControllerProvider.notifier);

    return AuthScaffold(
      title: 'Buat akun',
      subtitle: 'Mulai perjalanan nutrisi kamu dengan satu akun.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Sudah punya akun? '),
          TextButton(
            onPressed: state.isSubmitting ? null : () => context.go(AppRoutes.signIn),
            child: const Text('Masuk'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.failure != null) ...[
              AuthErrorBanner(failure: state.failure!),
              const SizedBox(height: 16),
            ],
            EmailField(
              controller: _email,
              autofocus: true,
              errorText: state.emailError,
              onChanged: controller.emailChanged,
              onSubmitted: (_) => controller.passwordTouched(),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              label: 'Password',
              errorText: state.passwordError,
              helperText: 'Minimal 8 karakter, mengandung huruf dan angka',
              textInputAction: TextInputAction.next,
              onChanged: controller.passwordChanged,
              onSubmitted: (_) => controller.confirmPasswordTouched(),
            ),
            const SizedBox(height: 12),
            PasswordStrengthMeter(
              strength: state.strength,
              policy: PasswordPolicy.defaultPolicy,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: 'Konfirmasi password',
              errorText: state.confirmError,
              onChanged: controller.confirmPasswordChanged,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              // Disabled sampai valid (requirement Sign Up Screen).
              onPressed: state.isSubmitEnabled ? _submit : null,
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Daftar'),
            ),
            const SizedBox(height: 12),
            Text(
              'Dengan mendaftar kamu setuju dengan Syarat & Kebijakan Privasi.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}