import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

abstract final class EditTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: EditTokens.bg,
      colorScheme: const ColorScheme.dark(
        surface: EditTokens.surface,
        primary: EditTokens.accent,
        onPrimary: EditTokens.bg,
        secondary: EditTokens.accentDim,
        error: EditTokens.danger,
        onSurface: EditTokens.text,
        outline: EditTokens.border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EditTokens.bg,
        foregroundColor: EditTokens.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: EditTokens.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: EditTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EditTokens.radiusMd),
          side: const BorderSide(color: EditTokens.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: EditTokens.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: EditTokens.text,
        displayColor: EditTokens.text,
      ).copyWith(
        bodyMedium: const TextStyle(
          color: EditTokens.text,
          fontSize: 15,
          height: 1.35,
        ),
        bodySmall: const TextStyle(
          color: EditTokens.textMuted,
          fontSize: 13,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          color: EditTokens.text,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleMedium: const TextStyle(
          color: EditTokens.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EditTokens.accent,
          foregroundColor: EditTokens.bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EditTokens.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EditTokens.text,
          side: const BorderSide(color: EditTokens.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EditTokens.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EditTokens.textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EditTokens.surfaceHigh,
        hintStyle: const TextStyle(color: EditTokens.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EditTokens.radiusSm),
          borderSide: const BorderSide(color: EditTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EditTokens.radiusSm),
          borderSide: const BorderSide(color: EditTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EditTokens.radiusSm),
          borderSide: const BorderSide(color: EditTokens.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: EditTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EditTokens.radiusMd),
          side: const BorderSide(color: EditTokens.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EditTokens.surfaceHigh,
        contentTextStyle: const TextStyle(color: EditTokens.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EditTokens.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: const IconThemeData(color: EditTokens.textMuted, size: 22),
    );
  }
}
