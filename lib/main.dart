import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/storage/secure_local_storage.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.effectiveKey,
    // AC-3: session disimpan terenkripsi, bukan di shared_preferences.
    authOptions: FlutterAuthClientOptions(
      localStorage: const SecureLocalStorage(),
      // AC-6: SDK menukar deep link dari email menjadi session.
      detectSessionInUri: true,
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [supabaseClientProvider.overrideWithValue(Supabase.instance.client)],
      child: const NutriAuthApp(),
    ),
  );
}

/// Root widget. Menangkap deep link selama app berjalan (AC-6 / TC-105FE-12).
class NutriAuthApp extends ConsumerStatefulWidget {
  const NutriAuthApp({super.key});

  @override
  ConsumerState<NutriAuthApp> createState() => _NutriAuthAppState();
}

class _NutriAuthAppState extends ConsumerState<NutriAuthApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      // Link yang membuka app dari keadaan mati (cold start).
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        ref.read(deepLinkProvider.notifier).set(initial);
      }

      // Link yang datang saat app sedang berjalan.
      _linkSub = _appLinks.uriLinkStream.listen((uri) async {
        ref.read(deepLinkProvider.notifier).set(uri);
      });
    } catch (e) {
      debugPrint('Gagal menyiapkan deep link: $e');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AppRoot();
  }
}

/// Ditampilkan bila `--dart-define` untuk Supabase belum diisi, supaya
/// kegagalan konfigurasi jelas dan bukan crash saat runtime.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Konfigurasi Supabase belum diisi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jalankan dengan:\n'
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_URL=... \\\n'
                  '  --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}