/// Klasifikasi error auth supaya UI bisa bereaksi spesifik (mis. menampilkan
/// tombol "Kirim ulang" hanya saat [kind] == [AuthFailureKind.emailNotVerified]).
enum AuthFailureKind {
  network,
  invalidCredentials,
  emailNotVerified,
  emailAlreadyRegistered,
  weakPassword,
  rateLimited,
  verificationLinkExpired,
  invalidLink,
  missingSession,
  unknown,
}

/// Error domain yang aman ditampilkan ke user.
///
/// Pesan dari Supabase bisa membocorkan detail internal, jadi semua pesan
/// disimpan di sini dalam Bahasa Indonesia (AC-2, AC-4: "error jelas").
class AuthFailure implements Exception {
  const AuthFailure({
    required this.kind,
    required this.message,
    this.canResend = false,
    this.cause,
  });

  final AuthFailureKind kind;

  /// Pesan yang aman ditampilkan ke user.
  final String message;

  /// Apakah UI sebaiknya menawarkan aksi "Kirim ulang email verifikasi".
  final bool canResend;

  final Object? cause;

  bool get isRetryable =>
      kind == AuthFailureKind.network || kind == AuthFailureKind.rateLimited;

  /// Error codes resmi GoTrue. Dipakai untuk pencocokan yang stabil —
  /// pesan string dari server bisa berubah kapan saja.
  static const AuthFailure emailExists = AuthFailure(
    kind: AuthFailureKind.emailAlreadyRegistered,
    message: 'Email ini sudah terdaftar. Silakan masuk atau atur ulang password.',
  );

  static const AuthFailure invalidCredentials = AuthFailure(
    kind: AuthFailureKind.invalidCredentials,
    message: 'Email atau password salah.',
  );

  static const AuthFailure emailNotConfirmed = AuthFailure(
    kind: AuthFailureKind.emailNotVerified,
    message: 'Email kamu belum diverifikasi. Periksa kotak masuk.',
    canResend: true,
  );

  static const AuthFailure weakPassword = AuthFailure(
    kind: AuthFailureKind.weakPassword,
    message: 'Password tidak memenuhi syarat keamanan.',
  );

  static const AuthFailure rateLimited = AuthFailure(
    kind: AuthFailureKind.rateLimited,
    message: 'Terlalu sering mengirim email. Tunggu sebentar lalu coba lagi.',
  );

  static const AuthFailure linkExpired = AuthFailure(
    kind: AuthFailureKind.verificationLinkExpired,
    message: 'Link verifikasi sudah kedaluwarsa. Minta link baru di bawah.',
    canResend: true,
  );

  static const AuthFailure invalidLink = AuthFailure(
    kind: AuthFailureKind.invalidLink,
    message: 'Link verifikasi tidak valid. Minta link baru.',
    canResend: true,
  );

  static const Map<String, AuthFailure> _byCode = {
    'email_exists': emailExists,
    'user_already_exists': emailExists,
    'invalid_credentials': invalidCredentials,
    'email_not_confirmed': emailNotConfirmed,
    'email_address_not_authorized': emailNotConfirmed,
    'weak_password': weakPassword,
    'over_request_rate_limit': rateLimited,
    'over_email_send_rate_limit': rateLimited,
    'token_expired': linkExpired,
    'otp_expired': linkExpired,
    'access_denied': invalidLink,
    'invalid_token': invalidLink,
    'session_not_found': AuthFailure(
      kind: AuthFailureKind.missingSession,
      message: 'Sesi kamu sudah berakhir. Silakan masuk kembali.',
    ),
  };

  /// Frasa yang muncul pada pesan server bila `code` tidak tersedia.
  static const List<(String, AuthFailure)> _byPhrase = [
    ('already registered', emailExists),
    ('already been registered', emailExists),
    ('invalid login credentials', invalidCredentials),
    ('not confirmed', emailNotConfirmed),
    ('not verified', emailNotConfirmed),
    ('rate limit', rateLimited),
    ('too many', rateLimited),
    ('expired', linkExpired),
  ];

  /// Terjemahkan respons Supabase menjadi [AuthFailure].
  ///
  /// [code] diprioritaskan karena stabil antar versi, [message] hanya jadi
  /// fallback. [statusCode] adalah string (tipe asli di gotrue) dan hanya
  /// dipakai untuk membedakan error 5xx dari 4xx.
  static AuthFailure fromSupabase({
    String? code,
    String? message,
    String? statusCode,
  }) {
    if (code != null) {
      final mapped = _byCode[code];
      if (mapped != null) return mapped;
    }

    final raw = (message ?? '').toLowerCase();
    if (raw.isNotEmpty) {
      for (final (phrase, failure) in _byPhrase) {
        if (raw.contains(phrase)) return failure;
      }
    }

    final status = int.tryParse(statusCode ?? '');
    if (status != null && status >= 500) {
      return AuthFailure(
        kind: AuthFailureKind.network,
        message: 'Server sedang bermasalah. Coba lagi sebentar.',
        cause: message,
      );
    }

    if (code != null) {
      return AuthFailure(
        kind: AuthFailureKind.unknown,
        message: 'Terjadi kesalahan ($code). Silakan coba lagi.',
        cause: message,
      );
    }

    return const AuthFailure(
      kind: AuthFailureKind.unknown,
      message: 'Terjadi kesalahan. Silakan coba lagi.',
    );
  }

  /// Error jaringan saat request tidak sampai ke server.
  static const AuthFailure network = AuthFailure(
    kind: AuthFailureKind.network,
    message: 'Koneksi bermasalah. Periksa internet lalu coba lagi.',
  );

  @override
  String toString() => 'AuthFailure(${kind.name}): $message';
}