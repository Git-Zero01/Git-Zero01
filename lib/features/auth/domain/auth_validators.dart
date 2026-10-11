import 'package:email_validator/email_validator.dart';

/// Aturan password yang bisa dikonfigurasi.
///
/// Catatan AC-9: bagian "Input Validation Rules" tidak disertakan di brief
/// NUTRI-105-FE, sehingga default di sini diturunkan langsung dari test case
/// yang eksplisit (TC-105FE-4, -5, -8). Aturan tambahan (uppercase, simbol)
/// sengaja dimatikan secara default agar tidak menolak password yang lolos
/// seluruh test case. Lihat `docs/DEVIATIONS.md`.
class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 8,
    this.requireLetter = true,
    this.requireDigit = true,
    this.requireUpperCase = false,
    this.requireSymbol = false,
    this.allowWhitespaceInside = false,
  });

  final int minLength;
  final bool requireLetter;
  final bool requireDigit;
  final bool requireUpperCase;
  final bool requireSymbol;
  final bool allowWhitespaceInside;

  static const PasswordPolicy defaultPolicy = PasswordPolicy();
}

/// Hasil validasi satu field.
///
/// [error] bernilai `null` bila input valid — dipakai form untuk menyalakan
/// atau mematikan tombol submit secara real-time.
class ValidationResult {
  const ValidationResult.valid() : error = null;

  const ValidationResult.invalid(this.error);

  final String? error;

  bool get isValid => error == null;

  @override
  String toString() => isValid ? 'valid' : 'invalid($error)';
}

/// Validasi input untuk seluruh layar auth.
///
/// Mengembalikan pesan berbahasa Indonesia agar bisa langsung ditampilkan
/// sebagai `errorText` pada `TextFormField` (AC-8).
class Validators {
  const Validators._();

  static final RegExp _containsDigit = RegExp(r'[0-9]');
  static final RegExp _containsLetter = RegExp(r'[A-Za-z]');
  static final RegExp _containsUpperCase = RegExp(r'[A-Z]');
  static final RegExp _containsSymbol = RegExp(r'[^A-Za-z0-9]');

  /// Karakter di luar rentang ASCII: emoji, aksen, CJK, zero-width, dll.
  /// TC-105FE-7: email berisi emoji harus ditolak.
  static final RegExp _nonAscii = RegExp(r'[^\x00-\x7F]');

  /// Dipakai untuk TC-105FE-8: password yang hanya berisi spasi.
  static bool isWhitespaceOnly(String value) =>
      value.trim().isEmpty && value.isNotEmpty;

  /// Validasi email. Mengembalikan pesan error atau `null` bila valid.
  static String? email(String? value, {bool required = true}) {
    final v = value ?? '';

    if (v.isEmpty) {
      return required ? 'Email wajib diisi' : null;
    }

    if (isWhitespaceOnly(v)) {
      return 'Email tidak boleh hanya berisi spasi';
    }

    // TC-105FE-7 — tolak lebih dulu sebelum regex, supaya pesan errornya
    // spesifik untuk emoji dan bukan "format email tidak valid" yang generik.
    if (_nonAscii.hasMatch(v)) {
      return 'Email tidak boleh mengandung emoji atau karakter khusus';
    }

    if (v.contains(' ')) {
      return 'Email tidak boleh mengandung spasi';
    }

    if (!EmailValidator.validate(v)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  /// Validasi password dengan [policy].
  static String? password(String? value, {PasswordPolicy policy = PasswordPolicy.defaultPolicy}) {
    final v = value ?? '';

    if (v.isEmpty) {
      return 'Password wajib diisi';
    }

    // TC-105FE-8 — "        " (8 spasi) tetap ditolak walau lolos panjang.
    if (isWhitespaceOnly(v)) {
      return 'Password tidak boleh hanya berisi spasi';
    }

    // TC-105FE-4
    if (v.length < policy.minLength) {
      return 'Password minimal ${policy.minLength} karakter';
    }

    if (policy.requireLetter && !_containsLetter.hasMatch(v)) {
      return 'Password harus mengandung huruf';
    }

    // TC-105FE-5
    if (policy.requireDigit && !_containsDigit.hasMatch(v)) {
      return 'Password harus mengandung angka';
    }

    if (policy.requireUpperCase && !_containsUpperCase.hasMatch(v)) {
      return 'Password harus mengandung huruf besar';
    }

    if (policy.requireSymbol && !_containsSymbol.hasMatch(v)) {
      return 'Password harus mengandung simbol';
    }

    if (!policy.allowWhitespaceInside && v.trim() != v) {
      return 'Password tidak boleh diawali/diakhiri spasi';
    }

    return null;
  }

  /// Validasi konfirmasi password (TC-105FE-6).
  static String? confirmPassword(String? value, String password) {
    final v = value ?? '';

    if (v.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }

    if (v != password) {
      return 'Konfirmasi password tidak sama';
    }

    return null;
  }

  /// Skor 0..4 untuk indikator kekuatan password di UI.
  static PasswordStrength strength(
    String? value, {
    PasswordPolicy policy = PasswordPolicy.defaultPolicy,
  }) {
    final v = value ?? '';
    if (v.isEmpty) return PasswordStrength.empty;

    var score = 0;
    if (v.length >= policy.minLength) score++;
    if (_containsLetter.hasMatch(v) && _containsUpperCase.hasMatch(v)) score++;
    if (_containsDigit.hasMatch(v)) score++;
    if (_containsSymbol.hasMatch(v)) score++;

    // Password yang tidak lolos validasi tidak boleh tampil "menguat" —
    // termasuk yang hanya berisi spasi (TC-105FE-8).
    if (password(v, policy: policy) != null) {
      return PasswordStrength.weak;
    }

    return switch (score) {
      <= 1 => PasswordStrength.weak,
      2 => PasswordStrength.fair,
      3 => PasswordStrength.good,
      _ => PasswordStrength.strong,
    };
  }
}

enum PasswordStrength { empty, weak, fair, good, strong }

extension PasswordStrengthLabel on PasswordStrength {
  String get label => switch (this) {
        PasswordStrength.empty => '',
        PasswordStrength.weak => 'Lemah',
        PasswordStrength.fair => 'Cukup',
        PasswordStrength.good => 'Baik',
        PasswordStrength.strong => 'Kuat',
      };
}