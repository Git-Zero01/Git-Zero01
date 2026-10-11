import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Tema aplikasi NUTRI.
///
/// Netral dengan aksen hijau agar konsisten dengan produk nutrisi.
/// Ukuran spacing sengaja longgar agar aman di layar kecil (TC-105FE-15).
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),

      // Transisi halaman konsisten di semua platform: halus, tanpa "lonjakan"
      // arah. Android/desktop memakai FadeForwards (M3 motion), iOS/macOS
      // tetap memakai transisi Cupertino agar terasa native.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Tipografi: tingkatkan line-height & rapatkan letter-spacing di judul
      // supaya hierarki lebih terbaca tanpa menambah noise.
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.4),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // Border error handled lewat errorText, tinggi INPUT tetap konsisten
      // sehingga layout tidak "bergeser" saat validasi real-time (AC-8).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        // Ruang ekstra untuk pesan error inline tanpa menimpa border.
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44), // target sentuh minimal 44dp
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),

      // Feedback sentuh seragam untuk semua listrik yang bisa di-tap.
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Token jarak. Dipakai seragam supaya ritme vertikal antar layar sama.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Token radius, diselaraskan supaya sudut input / kartu / banner konsisten.
class AppRadius {
  const AppRadius._();

  static const double small = 8;
  static const double field = 12;
  static const double card = 16;
  static const double pill = 999;
}

/// Token gerak.
///
/// Semua durasi memakai kelipatan yang sama supaya aplikasi terasa "napas"
///-nya konsisten: cepat untuk feedback kecil, lambat untuk perpindahan layar.
class AppMotion {
  const AppMotion._();

  /// Feedback sekilas: pressed state, ripple.
  static const Duration instant = Duration(milliseconds: 120);

  /// State kecil: border, warna, progress.
  static const Duration fast = Duration(milliseconds: 200);

  /// Muncul/hilang elemen: banner, kartu.
  static const Duration normal = Duration(milliseconds: 300);

  /// Entri layar & perpindahan besar.
  static const Duration slow = Duration(milliseconds: 420);

  /// Kurva standar: mulai cepat lalu melambat — terasa "natural".
  static const Curve standard = Curves.easeOutCubic;

  /// Untuk yang mulai lambat dan berakhir tegas (masuk ke layar).
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Hormati pengaturan "remove animations" di OS.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Breakpoint untuk menyesuaikan layout di layar kecil (TC-105FE-15).
class Breakpoints {
  const Breakpoints._();

  /// Di bawah lebar ini form memakai padding lebih rapat.
  static const double compact = 360;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
}