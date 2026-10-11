import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_auth/features/auth/domain/auth_validators.dart';

/// TC-105FE-3 s/d TC-105FE-8 + AC-8.
void main() {
  group('Validators.email', () {
    test('TC-105FE-1: email valid diterima', () {
      expect(Validators.email('budi@example.com'), isNull);
      expect(Validators.email('siti.nur@sub.domain.co.id'), isNull);
      expect(Validators.email('user+tag@example.com'), isNull);
    });

    test('TC-105FE-3: format email invalid ditolak', () {
      expect(Validators.email('budi'), isNotNull);
      expect(Validators.email('budi@'), isNotNull);
      expect(Validators.email('@example.com'), isNotNull);
      expect(Validators.email('budi@example'), isNotNull);
      expect(Validators.email('budi@@example.com'), isNotNull);
    });

    test('TC-105FE-7: email dengan emoji ditolak', () {
      expect(Validators.email('budi😀@example.com'), isNotNull);
      expect(Validators.email('😀'), isNotNull);
      expect(Validators.email('budi@exa😀mple.com'), isNotNull);
      expect(Validators.email('budie🎉'), isNotNull);
    });

    test('email kosong wajib diisi kecuali required=false', () {
      expect(Validators.email(''), 'Email wajib diisi');
      expect(Validators.email('', required: false), isNull);
    });

    test('email dengan spasi ditolak', () {
      expect(Validators.email('budi>@example.com'), isNotNull);
      expect(Validators.email(' budi@example.com '), isNotNull);
    });

    test('email hanya spasi ditolak', () {
      expect(Validators.isWhitespaceOnly('   '), isTrue);
      expect(Validators.email('   '), isNotNull);
    });
  });

  group('Validators.password', () {
    test('TC-105FE-4: password < 8 karakter ditolak', () {
      expect(Validators.password('abc1'), 'Password minimal 8 karakter');
      expect(Validators.password('abc123'), 'Password minimal 8 karakter');
      expect(Validators.password('abc12345'), isNull); // tepat 8
    });

    test('TC-105FE-5: password tanpa angka ditolak', () {
      expect(Validators.password('abcdefgh'), 'Password harus mengandung angka');
    });

    test('TC-105FE-8: password hanya whitespace ditolak walau >= 8', () {
      expect(Validators.password('        '), 'Password tidak boleh hanya berisi spasi');
      expect(Validators.password('    '), 'Password tidak boleh hanya berisi spasi');
      expect(Validators.password('\t\t\t\t'), 'Password tidak boleh hanya berisi spasi');
    });

    test('password yang hanya spasi + angka tetap ditolak (rule huruf)', () {
      // Menguji bahwa penolakan terjadi, walau karena aturan lain.
      expect(Validators.password('   12345   '), 'Password harus mengandung huruf');
    });

    test('spasi di awal/akhir pada password valid tetap ditolak', () {
      expect(Validators.password('   ab12345   '),
          'Password tidak boleh diawali/diakhiri spasi');
    });

    test('password kosong wajib diisi', () {
      expect(Validators.password(''), 'Password wajib diisi');
      expect(Validators.password(null), 'Password wajib diisi');
    });


    test('policy kustom: huruf besar wajib', () {
      const policy = PasswordPolicy(requireUpperCase: true);
      expect(Validators.password('abcdefg1', policy: policy), isNotNull);
      expect(Validators.password('Abcdefg1', policy: policy), isNull);
    });

    test('policy kustom: simbol wajib', () {
      const policy = PasswordPolicy(requireSymbol: true);
      expect(Validators.password('abcdefg1', policy: policy), isNotNull);
      expect(Validators.password('abcdefg1!', policy: policy), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('TC-105FE-6: konfirmasi tidak sama ditolak', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345x'), isNotNull);
      expect(Validators.confirmPassword('abc12345 ', 'abc12345'), isNotNull);
    });

    test('TC-105FE-6: konfirmasi sama diterima', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
    });

    test('konfirmasi kosong wajib diisi', () {
      expect(Validators.confirmPassword('', 'abc12345'), isNotNull);
    });

    test('case sensitive', () {
      expect(Validators.confirmPassword('ABC12345', 'abc12345'), isNotNull);
    });
  });

  group('Validators.strength', () {
    test('password kosong -> empty', () {
      expect(Validators.strength(''), PasswordStrength.empty);
      expect(Validators.strength(null), PasswordStrength.empty);
    });

    test('password invalid tetap weak', () {
      expect(Validators.strength('abc'), PasswordStrength.weak);
      expect(Validators.strength('        '), PasswordStrength.weak);
    });

    test('password kuat menghasilkan strong', () {
      expect(Validators.strength('Abcdefg1!'), PasswordStrength.strong);
    });

    test('label tidak kosong untuk password terisi', () {
      expect(PasswordStrength.weak.label, isNotEmpty);
      expect(PasswordStrength.empty.label, isEmpty);
    });
  });
}