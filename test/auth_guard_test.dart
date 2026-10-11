import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_auth/core/router/app_router.dart';
import 'package:nutri_auth/features/auth/data/auth_repository.dart';
import 'package:nutri_auth/features/auth/presentation/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test untuk logika router guard dan verifikasi status email.
///
/// Guard diuji lewat [authGuardFor] (fungsi murni) supaya tidak perlu
/// membangun GoRouter yang lengkap.
void main() {
  AuthStatus signedOut({bool loading = false}) => AuthStatus(
        session: null,
        isEmailVerified: false,
        isLoading: loading,
      );

  AuthStatus signedInVerified() => AuthStatus(
        session: _session(emailConfirmed: true),
        isEmailVerified: true,
        isLoading: false,
      );

  AuthStatus signedInUnverified() => AuthStatus(
        session: _session(emailConfirmed: false),
        isEmailVerified: false,
        isLoading: false,
      );

  group('authGuardFor — belum login', () {
    test('route butuh auth → redirect ke sign-in', () {
      expect(
        authGuardFor(location: AppRoutes.onboarding, status: signedOut()),
        AppRoutes.signIn,
      );
    });

    test('sudah di halaman auth → tidak redirect', () {
      expect(
        authGuardFor(location: AppRoutes.signIn, status: signedOut()),
        isNull,
      );
      expect(
        authGuardFor(location: AppRoutes.signUp, status: signedOut()),
        isNull,
      );
      expect(
        authGuardFor(location: AppRoutes.forgotPassword, status: signedOut()),
        isNull,
      );
    });

    test('layar verifikasi boleh diakses tanpa session (AC-6)', () {
      expect(
        authGuardFor(location: AppRoutes.verifyEmail, status: signedOut()),
        isNull,
      );
    });

    test('selagi loading tidak redirect (TC-105FE-14)', () {
      // Penting: mencegah kedip ke halaman login saat app start.
      expect(
        authGuardFor(
          location: AppRoutes.onboarding,
          status: signedOut(loading: true),
        ),
        isNull,
      );
    });
  });

  group('authGuardFor — login tapi belum verifikasi', () {
    test('route butuh verifikasi → redirect ke verify-email', () {
      expect(
        authGuardFor(
          location: AppRoutes.onboarding,
          status: signedInUnverified(),
        ),
        AppRoutes.verifyEmail,
      );
    });

    test('membuka halaman auth → redirect ke verify-email', () {
      expect(
        authGuardFor(
          location: AppRoutes.signIn,
          status: signedInUnverified(),
        ),
        AppRoutes.verifyEmail,
      );
      expect(
        authGuardFor(
          location: AppRoutes.signUp,
          status: signedInUnverified(),
        ),
        AppRoutes.verifyEmail,
      );
    });

    test('sudah di verify-email → tidak redirect', () {
      expect(
        authGuardFor(
          location: AppRoutes.verifyEmail,
          status: signedInUnverified(),
        ),
        isNull,
      );
    });
  });

  group('authGuardFor — login dan terverifikasi', () {
    test('route bebas akses tetap di tempat', () {
      expect(
        authGuardFor(location: AppRoutes.onboarding, status: signedInVerified()),
        isNull,
      );
    });

    test('membuka halaman auth → redirect ke onboarding', () {
      expect(
        authGuardFor(location: AppRoutes.signIn, status: signedInVerified()),
        AppRoutes.onboarding,
      );
      expect(
        authGuardFor(location: AppRoutes.signUp, status: signedInVerified()),
        AppRoutes.onboarding,
      );
      expect(
        authGuardFor(
          location: AppRoutes.verifyEmail,
          status: signedInVerified(),
        ),
        AppRoutes.onboarding,
      );
    });
  });

  group('AuthRepository.isVerified', () {
    test('emailConfirmedAt terisi → terverifikasi', () {
      final user = User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'budi@example.com',
        createdAt: '2024-01-01T00:00:00Z',
        emailConfirmedAt: '2024-01-01T00:01:00Z',
      );
      expect(AuthRepository.isVerified(user), isTrue);
    });

    test('emailConfirmedAt kosong → belum terverifikasi', () {
      final user = User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'budi@example.com',
        createdAt: '2024-01-01T00:00:00Z',
      );
      expect(AuthRepository.isVerified(user), isFalse);
    });

    test('metadata email_verified menang atas emailConfirmedAt', () {
      final verified = User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {'email_verified': true},
        aud: 'authenticated',
        email: 'budi@example.com',
        createdAt: '2024-01-01T00:00:00Z',
      );
      expect(AuthRepository.isVerified(verified), isTrue);

      final notVerifiedDespiteStamp = User(
        id: 'u2',
        appMetadata: const {},
        userMetadata: const {'email_verified': false},
        aud: 'authenticated',
        email: 'siti@example.com',
        createdAt: '2024-01-01T00:00:00Z',
        emailConfirmedAt: '2024-01-01T00:01:00Z',
      );
      expect(AuthRepository.isVerified(notVerifiedDespiteStamp), isFalse);
    });
  });
}

/// Membangun [Session] palsu untuk keperluan testing guard.
Session _session({required bool emailConfirmed}) {
  final user = User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'budi@example.com',
    createdAt: '2024-01-01T00:00:00Z',
    emailConfirmedAt: emailConfirmed ? '2024-01-01T00:01:00Z' : null,
  );

  return Session(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresIn: 3600,
    tokenType: 'bearer',
    user: user,
  );
}