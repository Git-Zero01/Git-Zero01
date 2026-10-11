import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_failure.dart';
import '../../domain/auth_validators.dart';

/// Scaffold bersama untuk seluruh layar auth.
///
/// Membungkus konten dalam [SingleChildScrollView] + [ConstrainedBox] agar
/// tidak terjadi overflow di layar kecil maupun saat keyboard muncul
/// (TC-105FE-15).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.showBackButton = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);

    return Scaffold(
      appBar: showBackButton
          ? AppBar(backgroundColor: Colors.transparent)
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 28,
                vertical: compact ? 16 : 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      (compact ? 32 : 64),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Judul, subjudul, form, lalu footer muncul berurutan
                        // (staggered) supaya perpindahan layar terasa hidup
                        // tanpa tetap cepat.
                        FadeSlideIn(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        if (subtitle != null)
                          FadeSlideIn(
                            delay: AppMotion.instant,
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.sm),
                              child: Text(
                                subtitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          delay: AppMotion.fast,
                          child: child,
                        ),
                        if (footer != null)
                          FadeSlideIn(
                            delay: AppMotion.normal,
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.lg),
                              child: footer!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Entri halus: fade + bergeser naik sedikit, dengan jeda opsional.
///
/// Dipakai bertingkat (*staggered*) di [AuthScaffold] supaya isi layar masuk
/// sesuai urutannya. Otomatis menghormati pengaturan "hapus animasi" di OS.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 0.03,
  });

  final Widget child;

  /// Jeda sebelum animasi mulai — dipakai untuk menyusun antrean.
  final Duration delay;

  /// Perpindahan vertikal sebagai pecahan dari tinggi anak (0.03 = 3%).
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // MediaQuery baru boleh dibaca di sini, bukan di initState.
    if (AppMotion.isReduced(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Slot opsional: konten muncul atau hilang dengan animasi tinggi, bukan
/// "lompatan" mendadak saat flag berubah.
class AnimatedSlot extends StatelessWidget {
  const AnimatedSlot({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: visible ? child : const SizedBox(width: double.infinity),
    );
  }
}

/// Kolom email dengan validasi real-time (AC-8).
class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      // Email tidak pernah mengandung spasi; mencegah user keceploh ketik.
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'nama@email.com',
        errorText: errorText,
        prefixIcon: const Icon(Icons.mail_outline),
      ),
    );
  }
}

/// Kolom password dengan ikon lihat/sembunyikan.
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.onSubmitted,
    this.autofocus = false,
    this.label = 'Password',
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String label;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return _ObscuredField(
      controller: controller,
      label: label,
      errorText: errorText,
      helperText: helperText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      textInputAction: textInputAction,
    );
  }
}

class _ObscuredField extends StatefulWidget {
  const _ObscuredField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction textInputAction;

  @override
  State<_ObscuredField> createState() => _ObscuredFieldState();
}

class _ObscuredFieldState extends State<_ObscuredField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorMaxLines: 3,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          tooltip: _obscured ? 'Tampilkan password' : 'Sembunyikan password',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Indikator kekuatan password dengan label teks.
///
/// Warna saja tidak cukup untuk aksesibilitas, jadi label selalu ikut
/// ditampilkan dan diumumkan ke screen reader.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.strength,
    required this.policy,
  });

  final PasswordStrength strength;
  final PasswordPolicy policy;

  Color _color(ColorScheme scheme) => switch (strength) {
        PasswordStrength.empty => scheme.outlineVariant,
        PasswordStrength.weak => AppTheme.error,
        PasswordStrength.fair => const Color(0xFFF9A825),
        PasswordStrength.good => const Color(0xFF558B2F),
        PasswordStrength.strong => scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
    final filled = switch (strength) {
      PasswordStrength.empty => 0,
      PasswordStrength.weak => 1,
      PasswordStrength.fair => 2,
      PasswordStrength.good => 3,
      PasswordStrength.strong => 4,
    };

    return Semantics(
      label: 'Kekuatan password: ${strength.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.standard,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < filled ? color : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            strength.label.isEmpty
                ? 'Minimal ${policy.minLength} karakter dan mengandung angka'
                : strength.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Banner error untuk kegagalan dari server (AC-2, AC-4).
///
/// [failure] boleh null: banner lalu menyusut sendiri lewat [AnimatedSize]
/// alih-alih hilang seketika, supaya layout tidak "melompat".
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    super.key,
    this.failure,
    this.onDismiss,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final AuthFailure? failure;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;

    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: failure == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: margin,
              child: _BannerBody(failure: failure, onDismiss: onDismiss),
            ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.failure, this.onDismiss});

  final AuthFailure failure;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              color: scheme.onErrorContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                failure.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            ),
          ),
          // Tombol sungguhan, bukan GestureDetector: punya area sentuh 40dp,
          // tooltip, dan terbaca screen reader.
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Tutup pesan',
              color: scheme.onErrorContainer,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
        ],
      ),
    );
  }
}

/// Tombol aksi utama dengan umpan balik tekan yang halus dan status loading
/// yang seragam di seluruh alur auth.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.tonal = false,
  });

  final String label;

  /// Null berarti tombol nonaktif — dipakai controller saat form tak valid.
  final VoidCallback? onPressed;
  final bool busy;
  final bool tonal;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Nonaktif saat form tak valid ATAU sedang submit.
    final enabled = widget.onPressed != null && !widget.busy;

    final label = AnimatedSwitcher(
      duration: AppMotion.fast,
      child: widget.busy
          ? SizedBox(
              key: const ValueKey('busy'),
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(
              widget.label,
              key: const ValueKey('label'),
            ),
    );

    final button = widget.tonal
        ? FilledButton.tonal(
            onPressed: enabled ? widget.onPressed : null,
            child: label,
          )
        : FilledButton(
            onPressed: enabled ? widget.onPressed : null,
            child: label,
          );

    return AnimatedScale(
      // Menekan sedikit memberi rasa "hidup" tanpa mengaburkan teks.
      scale: _pressed && enabled ? 0.98 : 1,
      duration: AppMotion.instant,
      curve: AppMotion.standard,
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel:
            enabled ? (_) => setState(() => _pressed = false) : null,
        child: button,
      ),
    );
  }
}