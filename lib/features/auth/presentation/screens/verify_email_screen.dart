import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_failure.dart';
import '../providers/auth_controllers.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_widgets.dart';

/// `/auth/verify-email` — AC-5, AC-6, TC-105FE-12..14.
///
/// Menampilkan "Cek email kamu", tombol kirim ulang dengan cooldown 60 detik,
/// polling status tiap 5 detik, dan memproses deep link dari email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  /// Drives hitungan mundur tombol resend.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    // Polling 5 detik (requirement Verify Email Screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = ref.read(verifyEmailControllerProvider.notifier);
      c.startPolling();
      c.restoreCooldown();
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    ref.read(verifyEmailControllerProvider.notifier).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyEmailControllerProvider);
    final authStatus = ref.watch(authStatusProvider);
    final pendingEmail = ref.watch(pendingVerificationProvider).valueOrNull;
    final cooldownUntil = ref.watch(resendCooldownProvider);

    final now = DateTime.now();
    final remaining = cooldownUntil?.difference(now).inSeconds;
    final isCoolingDown = remaining != null && remaining > 0;

    // AC-6 — begitu session terverifikasi, langsung ke onboarding.
    if (authStatus.isEmailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.onboarding);
      });
    }

    return AuthScaffold(
      title: 'Cek email kamu',
      subtitle: pendingEmail == null
          ? 'Kami telah mengirim link verifikasi ke email kamu.'
          : 'Kami telah mengirim link verifikasi ke $pendingEmail.',
      showBackButton: false,
      footer: TextButton.icon(
        onPressed: () => ref.read(authStatusProvider.notifier).signOut(),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Keluar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSlot(
            visible: state.isVerifying,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                LinearProgressIndicator(minHeight: 3),
                SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          AuthErrorBanner(
            failure: state.linkError,
            onDismiss: ref.read(verifyEmailControllerProvider.notifier).clearLinkError,
          ),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Buka link di email yang kami kirim. Halaman ini otomatis '
                      'memperbarui status setiap 5 detik.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // AC-5 — disabled selama cooldown.
          PrimaryButton(
            tonal: true,
            busy: state.isResending,
            label: isCoolingDown
                ? 'Kirim ulang dalam ${remaining}s'
                : 'Kirim ulang email',
            onPressed: (isCoolingDown || state.isResending)
                ? null
                : () => ref
                    .read(verifyEmailControllerProvider.notifier)
                    .resend()
                    .then((_) {
                      if (mounted) setState(() {});
                    }),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isCoolingDown)
            Text(
              'Batas kirim ulang: 60 detik',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Error banner khusus yang memaksa usersnap bisa request ulang
/// (TC-105FE-13: link verifikasi expired).
class ExpiredLinkNotice extends ConsumerWidget {
  const ExpiredLinkNotice({super.key, required this.failure});

  final AuthFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthErrorBanner(failure: failure);
  }
}