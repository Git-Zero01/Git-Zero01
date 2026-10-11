import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../storage/secure_local_storage.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';

/// Nama route sesuai requirement tiket.
class AppRoutes {
  const AppRoutes._();

  static const signUp = '/auth/sign-up';
  static const signIn = '/auth/sign-in';
  static const verifyEmail = '/auth/verify-email';
  static const forgotPassword = '/auth/forgot-password';

  /// Tujuan setelah verifikasi berhasil — sesuai user story ("lanjut ke
  /// onboarding profil").
  static const onboarding = '/onboarding';
}

/// Adaptor [Listenable] supaya go_router_trigger reevaluasi begitu status auth
/// berubah. Dipakai sebagai `refreshListenable`.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _sub = ref.listen<AuthStatus>(authStatusProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AuthStatus> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// [Guard] yang dipanggil go_router setiap kali status auth berubah.
///
/// - Route butuh auth tapi belum login  → `/auth/sign-in`
/// - Route butuh verifikasi tapi belum terverifikasi → `/auth/verify-email`
/// - Sudah login & terverifikasi tapi membuka halaman auth → `/onboarding`
/// - Sudah login tapi belum verifikasi dan membuka halaman auth lain
///   → `/auth/verify-email`
String? authGuard(GoRouterState state, Ref ref) {
  return authGuardFor(
    location: state.matchedLocation,
    status: ref.read(authStatusProvider),
  );
}

/// Aturan redirect dalam bentuk murni (tidak butuh `Ref`), supaya bisa diuji
/// tanpa membangun GoRouter.
@visibleForTesting
String? authGuardFor({required String location, required AuthStatus status}) {
  // Selagi session dari secure storage belum dibaca, jangan redirect — tunggu
  // Supabase selesai memulihkan state supaya TC-105FE-14 tidak sempat kedip ke
  // halaman login.
  if (status.isLoading) return null;

  final isAuthRoute = _isAuthLocation(location);

  if (!status.isSignedIn) {
    // Layar verifikasi boleh diakses tanpa session, karena status verifikasi
    // memang belum tersimpan sebagai session.
    if (location == AppRoutes.verifyEmail) return null;
    return isAuthRoute ? null : AppRoutes.signIn;
  }

  // Sudah login tapi email belum terverifikasi. Semua route selain
  // /auth/verify-email butuh verifikasi, termasuk route privat seperti
  // /onboarding — bukan hanya halaman auth.
  if (!status.isEmailVerified) {
    return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
  }

  // Sudah login & terverifikasi: jangan biarkan kembali ke halaman auth.
  return isAuthRoute ? AppRoutes.onboarding : null;
}

bool _isAuthLocation(String location) => location.startsWith('/auth');

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final result = authGuard(state, ref);
      if (result != null && result != state.matchedLocation) {
        return result;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, _) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, _) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});

/// Exposed untuk testing guard tanpa membuat router.
final secureStorageForTestProvider = Provider<SecureLocalStorage>(
  (ref) => const SecureLocalStorage(),
);