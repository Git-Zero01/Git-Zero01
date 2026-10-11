/// Konfigurasi environment untuk NUTRI-105-FE.
///
/// Nilai diambil dari `--dart-define` agar kredensial tidak ikut ter-commit:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
///   --dart-define=DEEP_LINK_SCHEME=nutri
/// ```
class Env {
  const Env._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

  /// Dipertahankan untuk 호환 dengan anon key lama.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Scheme deep link yang dikonfigurasi di Supabase Dashboard > Auth > URL
  /// Configuration (Site URL + Redirect URLs).
  static const String deepLinkScheme =
      String.fromEnvironment('DEEP_LINK_SCHEME', defaultValue: 'nutri');

  static String get effectiveKey =>
      supabasePublishableKey.isNotEmpty ? supabasePublishableKey : supabaseAnonKey;

  /// `true` bila kredensial Supabase tersedia di build.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && effectiveKey.isNotEmpty;

  /// URL redirect yang dikirim ke Supabase saat sign-up / resend, supaya
  /// deep link dari email kembali ke app (AC-6, TC-105FE-12).
  static String get emailRedirectUrl => '$deepLinkScheme://auth/callback';

  /// Nama environment untuk pesan error konfigurasi.
  static const String dartDefineHint =
      'SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY';
}