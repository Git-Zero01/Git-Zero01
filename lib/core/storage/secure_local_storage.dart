import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menyimpan session Supabase (berisi access + refresh token JWT) di
/// `flutter_secure_storage` alih-alih `shared_preferences`.
///
/// Tujuannya mencegah JWT ditulis ke penyimpanan yang tidak terenkripsi,
/// seperti yang diminta AC-3 ("JWT di secure storage").
///
/// Di iOS nilai disimpan di Keychain, di Android di EncryptedSharedPreferences
/// (AES, kuncinya disimpan di Android Keystore).
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ]);

  static const String _sessionKey = 'nutri.auth.session';

  /// Email yang sedang menunggu verifikasi, disimpan terpisah agar
  /// TC-105FE-14 terpenuhi: user menutup app di layar verifikasi lalu
  /// membukanya kembali tetap diarahkan ke layar tersebut.
  static const String pendingEmailKey = 'nutri.auth.pending_verification_email';

  /// Epoch ms kapan cooldown resend dimulai, untuk TC-105FE-14.
  static const String pendingResendAtKey = 'nutri.auth.resend_cooldown_until';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  // --- Helper untuk verifikasi email (di luar kontrak LocalStorage) ---

  Future<String?> readPendingEmail() => _storage.read(key: pendingEmailKey);

  Future<void> writePendingEmail(String email) =>
      _storage.write(key: pendingEmailKey, value: email);

  Future<void> clearPendingVerification() async {
    await _storage.delete(key: pendingEmailKey);
    await _storage.delete(key: pendingResendAtKey);
  }

  Future<DateTime?> readResendCooldownUntil() async {
    final raw = await _storage.read(key: pendingResendAtKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
  }

  Future<void> writeResendCooldownUntil(DateTime at) => _storage.write(
        key: pendingResendAtKey,
        value: at.millisecondsSinceEpoch.toString(),
      );
}