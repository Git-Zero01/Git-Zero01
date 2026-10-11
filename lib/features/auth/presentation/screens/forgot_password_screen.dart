import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../providers/auth_controllers.dart';
import '../widgets/auth_widgets.dart';

/// `/auth/forgot-password` — mengirim email reset password.
///
/// Sengaja tidak memberi tahu apakah email terdaftar (anti user enumeration),
/// tampilan sukses identik baik untuk email terdaftar maupun tidak.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref.read(forgotPasswordControllerProvider.notifier).submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);

    if (state.isSent) {
      return AuthScaffold(
        title: 'Periksa email kamu',
        subtitle: 'Jika email tersebut terdaftar, kami sudah mengirim link untuk '
            'mengatur ulang password.',
        footer: TextButton(
          onPressed: () => context.go(AppRoutes.signIn),
          child: const Text('Kembali ke halaman masuk'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.signIn),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Atur ulang password',
      subtitle: 'Masukkan email yang kamu gunakan mendaftar.',
      footer: TextButton(
        onPressed: () => context.go(AppRoutes.signIn),
        child: const Text('Kembali ke halaman masuk'),
      ),
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
            errorText: state.email.isEmpty ? null : state.emailError,
            onChanged: ref.read(forgotPasswordControllerProvider.notifier).emailChanged,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.isSubmitEnabled ? _submit : null,
            child: state.isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Kirim link reset'),
          ),
        ],
      ),
    );
  }
}