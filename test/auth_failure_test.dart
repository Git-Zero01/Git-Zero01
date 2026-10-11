import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_auth/features/auth/domain/auth_failure.dart';

/// AC-2, AC-4, AC-5 — pemetaan error Supabase ke pesan user.
void main() {
  group('AuthFailure.fromSupabase — berdasarkan code', () {
    test('AC-2: email duplikat → kind emailAlreadyRegistered', () {
      final f = AuthFailure.fromSupabase(code: 'email_exists');
      expect(f.kind, AuthFailureKind.emailAlreadyRegistered);
      expect(f.message, contains('sudah terdaftar'));
    });

    test('user_already_exists dipetakan sama', () {
      final f = AuthFailure.fromSupabase(code: 'user_already_exists');
      expect(f.kind, AuthFailureKind.emailAlreadyRegistered);
    });

    test('kredensial salah → invalidCredentials', () {
      final f = AuthFailure.fromSupabase(code: 'invalid_credentials');
      expect(f.kind, AuthFailureKind.invalidCredentials);
      expect(f.canResend, isFalse);
    });

    test('AC-4: email belum diverifikasi → emailNotVerified + canResend', () {
      final f = AuthFailure.fromSupabase(code: 'email_not_confirmed');
      expect(f.kind, AuthFailureKind.emailNotVerified);
      expect(f.canResend, isTrue);
      expect(f.message, contains('belum diverifikasi'));
    });

    test('AC-5: rate limit → rateLimited', () {
      for (final code in ['over_request_rate_limit', 'over_email_send_rate_limit']) {
        final f = AuthFailure.fromSupabase(code: code);
        expect(f.kind, AuthFailureKind.rateLimited, reason: code);
        expect(f.isRetryable, isTrue);
      }
    });

    test('TC-105FE-13: token kedaluwarsa → linkExpired + canResend', () {
      for (final code in ['token_expired', 'otp_expired']) {
        final f = AuthFailure.fromSupabase(code: code);
        expect(f.kind, AuthFailureKind.verificationLinkExpired, reason: code);
        expect(f.canResend, isTrue);
        expect(f.message, contains('kedaluwarsa'));
      }
    });

    test('weak password dipetakan', () {
      final f = AuthFailure.fromSupabase(code: 'weak_password');
      expect(f.kind, AuthFailureKind.weakPassword);
    });

    test('session not found → missingSession', () {
      final f = AuthFailure.fromSupabase(code: 'session_not_found');
      expect(f.kind, AuthFailureKind.missingSession);
    });
  });

  group('AuthFailure.fromSupabase — fallback ke message', () {
    test('pesan "User already registered" terdeteksi', () {
      final f = AuthFailure.fromSupabase(
        message: 'User already registered',
      );
      expect(f.kind, AuthFailureKind.emailAlreadyRegistered);
    });

    test('pesan "Invalid login credentials" terdeteksi', () {
      final f = AuthFailure.fromSupabase(message: 'Invalid login credentials');
      expect(f.kind, AuthFailureKind.invalidCredentials);
    });

    test('pesan Email not confirmed terdeteksi', () {
      final f = AuthFailure.fromSupabase(message: 'Email not confirmed');
      expect(f.kind, AuthFailureKind.emailNotVerified);
    });

    test('status 5xx → network', () {
      final f = AuthFailure.fromSupabase(message: 'boom', statusCode: '503');
      expect(f.kind, AuthFailureKind.network);
      expect(f.isRetryable, isTrue);
    });

    test('status 4xx tanpa code dikenal tidak dianggap network', () {
      final f = AuthFailure.fromSupabase(message: 'bad', statusCode: '400');
      expect(f.kind, isNot(AuthFailureKind.network));
    });

    test('error tak dikenal tetap punya pesan user-friendly', () {
      final f = AuthFailure.fromSupabase();
      expect(f.kind, AuthFailureKind.unknown);
      expect(f.message, isNotEmpty);
      expect(f.message, isNot(contains('null')));
    });

    test('code tak dikenal memuat code di pesan untuk debugging', () {
      final f = AuthFailure.fromSupabase(code: 'some_new_code');
      expect(f.kind, AuthFailureKind.unknown);
      expect(f.message, contains('some_new_code'));
    });
  });
}