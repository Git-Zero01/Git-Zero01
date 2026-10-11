import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/storage/secure_local_storage.dart';
import '../../data/auth_repository.dart';
import '../../data/supabase_auth_repository.dart';
import '../../domain/auth_failure.dart';

/// Client Supabase singleton. Di-override di `main()` lewat
/// `ProviderScope(overrides: ...)` supaya layer bawah tetap testable.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError(
    'supabaseClientProvider harus di-override di ProviderScope.',
  );
});

/// `authRepositoryProvider` — wrapper sesuai requirement tiket.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Storage terenkripsi, diekspos lewat provider agar bisa di-override di test.
final secureStorageProvider = Provider<SecureLocalStorage>((ref) {
  return const SecureLocalStorage();
});

/// Snapshot status autentikasi yang dipakai router guard.
class AuthStatus {
  const AuthStatus({
    required this.session,
    required this.isEmailVerified,
    required this.isLoading,
  });

  final Session? session;
  final bool isEmailVerified;

  /// `true` selagi state awal Supabase belum diketahui — dipakai Supabase
  /// untuk menahan splash screen, bukan untuk redirect.
  final bool isLoading;

  bool get isSignedIn => session != null;
}

/// Sumber kebenaran tunggal untuk status auth.
///
/// Berasal dari stream `onAuthStateChange` milik SDK. `authStateProvider`
/// adalah alias yang diminta tiket; keduanya menunjuk ke state yang sama.
class AuthStatusNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final repo = ref.watch(authRepositoryProvider);

    // State awal: session yang sudah ada di secure storage (TC-105FE-14).
    final restored = repo.currentSession;
    if (restored != null) {
      return AuthStatus(
        session: restored,
        isEmailVerified: AuthRepository.isVerified(restored.user),
        isLoading: false,
      );
    }

    final sub = repo.authStateChanges().listen(
      _onAuthState,
      onError: (_, _) {
        state = const AuthStatus(session: null, isEmailVerified: false, isLoading: false);
      },
    );
    ref.onDispose(sub.cancel);

    return const AuthStatus(session: null, isEmailVerified: false, isLoading: true);
  }

  void _onAuthState(AuthState event) {
    final session = event.session;
    state = AuthStatus(
      session: session,
      isEmailVerified:
          session == null ? false : AuthRepository.isVerified(session.user),
      isLoading: false,
    );
  }

  /// Dipanggil setelah verifikasi berhasil supaya status terupdate tanpa
  /// menunggu stream (dipakai polling di layar verifikasi).
  void markVerified() {
    if (state.session == null) return;
    state = AuthStatus(
      session: state.session,
      isEmailVerified: true,
      isLoading: false,
    );
  }

  Future<void> refresh() async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.refreshUser();
    final session = repo.currentSession;
    if (session == null) return;
    state = AuthStatus(
      session: session,
      isEmailVerified: user != null ? AuthRepository.isVerified(user) : state.isEmailVerified,
      isLoading: false,
    );
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    await ref.read(secureStorageProvider).clearPendingVerification();
    state = const AuthStatus(session: null, isEmailVerified: false, isLoading: false);
  }
}

final authStatusProvider =
    NotifierProvider<AuthStatusNotifier, AuthStatus>(AuthStatusNotifier.new);

/// Stream mentah dari Supabase — bentuk yang diminta tiket ("stream dari
/// Supabase SDK"). Dipakai test-case yang butuh mengecek event langsung.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Guard helper untuk router: apakah user boleh masuk ke route terbatas.
extension AuthStatusX on AuthStatus {
  bool get requiresSignIn => !isLoading && session == null;
  bool get requiresVerification => session != null && !isEmailVerified;
}

/// Timer cooldown resend (AC-5): 60 detik.
class ResendCooldownNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Sisa detik sebelum boleh kirim ulang; `null` bila tidak aktif.
  int? remainingSeconds(DateTime now) {
    final until = state;
    if (until == null) return null;
    final diff = until.difference(now).inSeconds;
    return diff <= 0 ? null : diff;
  }

  void start(Duration duration) => state = DateTime.now().add(duration);

  void clear() => state = null;
}

final resendCooldownProvider =
    NotifierProvider<ResendCooldownNotifier, DateTime?>(ResendCooldownNotifier.new);

/// Email yang sedang menunggu verifikasi (TC-105FE-14).
class PendingVerificationNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(secureStorageProvider).readPendingEmail();

  Future<void> set(String email) async {
    // Tulis dulu ke storage, baru perbarui state. Urutan ini mencegah
    // `build()` yang sedang berjalan menimpa nilai baru kita.
    await ref.read(secureStorageProvider).writePendingEmail(email);
    state = AsyncData(email);
  }

  Future<void> clear() async {
    await ref.read(secureStorageProvider).clearPendingVerification();
    state = const AsyncData(null);
  }
}

final pendingVerificationProvider =
    AsyncNotifierProvider<PendingVerificationNotifier, String?>(
  PendingVerificationNotifier.new,
);

/// Deep link yang masuk saat app berjalan (AC-6).
class DeepLinkNotifier extends Notifier<Uri?> {
  @override
  Uri? build() => null;

  void set(Uri uri) => state = uri;

  void clear() => state = null;
}

final deepLinkProvider = NotifierProvider<DeepLinkNotifier, Uri?>(
  DeepLinkNotifier.new,
);

/// Error auth terakhir yang perlu ditampilkan sebagai banner (mis. "email
/// belum diverifikasi" setelah sign-in gagal).
class AuthBannerNotifier extends Notifier<AuthFailure?> {
  @override
  AuthFailure? build() => null;

  void show(AuthFailure failure) => state = failure;

  void clear() => state = null;
}

final authBannerProvider =
    NotifierProvider<AuthBannerNotifier, AuthFailure?>(AuthBannerNotifier.new);