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
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
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
                        ],
                        const SizedBox(height: 28),
                        child,
                        if (footer != null) ...[
                          const SizedBox(height: 24),
                          footer!,
                        ],
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
                    duration: const Duration(milliseconds: 180),
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
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.failure, this.onDismiss});

  final AuthFailure failure;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              failure.message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.close, size: 18, color: scheme.onErrorContainer),
              ),
            ),
        ],
      ),
    );
  }
}