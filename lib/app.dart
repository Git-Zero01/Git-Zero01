import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

/// Root widget aplikasi.
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // AC-6 / TC-105FE-12: memproses deep link yang ditangkap main.dart.
    // Dipisah ke widget agar ref dibaca setelah Riverpod siap.
    _DeepLinkHandler(router: router);

    return MaterialApp.router(
      title: 'NUTRI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // Pita merah di demo mode supaya tidak ketuker dengan build produksi.
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (Env.demoMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Theme.of(context).colorScheme.error,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'MODE DEMO — data in-memory, bukan autentikasi sungguhan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Menangani uri deep link yang masuk lewat [deepLinkProvider].
///
/// Berpindah ke /auth/verify-email saat link belum diproses supaya user
/// melihat konteks yang tepat, lalu menukarnya menjadi session. Bila link
/// bermasalah (kedaluwarsa, tidak valid) user tetap berada di layar verifikasi
/// dengan aksi kirim ulang — TC-105FE-13.
class _DeepLinkHandler extends ConsumerWidget {
  const _DeepLinkHandler({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<Uri?>(deepLinkProvider, (previous, next) async {
      if (next == null) return;

      // Tunjukkan layar verifikasi sambil pertukaran session berjalan.
      if (router.routerDelegate.currentConfiguration.uri.path !=
          AppRoutes.verifyEmail) {
        router.go(AppRoutes.verifyEmail);
      }

      final ok = await ref
          .read(verifyEmailDeepLinkHandlerProvider)
          .handle(next);

      if (!ok) return;

      ref.read(deepLinkProvider.notifier).clear();
      if (router.routerDelegate.currentConfiguration.uri.path !=
          AppRoutes.onboarding) {
        router.go(AppRoutes.onboarding);
      }
    });

    return const SizedBox.shrink();
  }
}

/// Placeholder agar handler tidak melakukan pekerjaan berat saat build pertama.
final verifyEmailDeepLinkHandlerProvider = Provider<DeepLinkHandler>(
  (ref) => DeepLinkHandler(ref),
);

/// Pembungkus tipis supaya presenter tidak menyentuh Supabase langsung.
class DeepLinkHandler {
  const DeepLinkHandler(this._ref);

  final Ref _ref;

  Future<bool> handle(Uri uri) async {
    try {
      await _ref.read(authRepositoryProvider).handleDeepLink(uri);
      await _ref.read(authStatusProvider.notifier).refresh();
      await _ref.read(pendingVerificationProvider.notifier).clear();
      return true;
    } catch (_) {
      // Deep link gagal → user tetap di layar verifikasi, yang sudah
      // menampilkan banner error + tombol kirim ulang.
      return false;
    }
  }
}