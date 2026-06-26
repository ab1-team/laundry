import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';

/// Input field variants — `outlined` (default, 1px border), `search`
/// (borderless with soft shadow, DESIGN.md search-bar style), or
/// `currency` (Rp prefix, thousands-separated while typing).
enum AppTextFieldVariant { outlined, search, currency }

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autocorrect = true,
    this.enabled = true,
    this.variant = AppTextFieldVariant.outlined,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  /// Inline prefix text rendered as part of the input (e.g. "+62 " or
  /// "Rp"). Sits between the field border and the typed value, so it
  /// scrolls with the text — unlike `prefixIcon` which is fixed.
  final String? prefixText;

  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool enabled;
  final AppTextFieldVariant variant;

  /// Number of visible lines. Pass `> 1` for a textarea-style field;
  /// defaults to a single line.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final isSearch = variant == AppTextFieldVariant.search;
    final isCurrency = variant == AppTextFieldVariant.currency;
    final onSurfaceVar = context.colors.onSurfaceVariant;
    final outline = context.colors.outline;

    // Currency variant: keypad + auto-group thousands (1.000.000).
    // The raw digits live in controller.text; formatter only restyles display.
    final formatters = <TextInputFormatter>[
      if (isCurrency) _ThousandsSeparatorFormatter(),
    ];
    final effectiveKeyboard = keyboardType ??
        (isCurrency ? const TextInputType.numberWithOptions(decimal: false) : null);
    final effectivePrefix = isCurrency
        ? Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Text(
              'Rp',
              style: TextStyle(
                color: onSurfaceVar,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : (prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  prefixIcon,
                  color: isSearch ? outline : onSurfaceVar,
                  size: 20,
                ),
              )
            : (prefixText != null
                // Render `prefixText` via `prefixIcon` (widget slot) so it
                // stays visible when the field is unfocused and empty —
                // `prefixText`/`prefix` (string/widget in the prefix slot)
                // are collapsed under that condition in Material 3.
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      prefixText!,
                      style: AppTextStyles.bodyLg.copyWith(
                        color: onSurfaceVar,
                      ),
                    ),
                  )
                : null));

    final field = TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: effectiveKeyboard,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      inputFormatters: formatters,
      maxLines: isCurrency ? 1 : maxLines,
      minLines: isCurrency ? 1 : (maxLines > 1 ? maxLines : null),
      style: AppTextStyles.bodyLg.copyWith(color: context.colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyLg.copyWith(
          color: isSearch ? outline : onSurfaceVar,
        ),
        prefixIcon: effectivePrefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSearch ? 16 : 16,
          vertical: isSearch ? 12 : 14,
        ),
        filled: isSearch,
        fillColor: isSearch ? context.colors.surface : null,
        border: isSearch ? null : OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        enabledBorder: isSearch ? null : OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        focusedBorder: isSearch ? null : OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
    );

    if (isSearch) {
      // DESIGN.md search bar: 20px radius, soft shadow, no border, 48px height.
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: field,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLg.copyWith(color: context.colors.onSurface)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Formats digits as thousands-separated string ("1500000" -> "1.500.000").
/// Keeps the underlying value as plain digits so consumers can parse it
/// with `int.tryParse` / `double.tryParse` without stripping dots first.
class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
