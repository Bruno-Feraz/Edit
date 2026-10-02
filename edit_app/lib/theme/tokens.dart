import 'package:flutter/material.dart';

/// Design tokens — tema scuro minimale (PRD §2.1).
abstract final class EditTokens {
  static const Color bg = Color(0xFF0B0C0E);
  static const Color surface = Color(0xFF14161A);
  static const Color surfaceHigh = Color(0xFF1C1F26);
  static const Color border = Color(0xFF2A2E38);

  static const Color text = Color(0xFFF2F3F5);
  static const Color textMuted = Color(0xFF9AA0AB);

  /// Accento UI (cyan). Brand logo = verde [EditLogo.green].
  static const Color accent = Color(0xFF3DDBD9);
  static const Color brandGreen = Color(0xFF5DA84A);
  static const Color accentDim = Color(0xFF1A4A49);

  static const Color danger = Color(0xFFE85D5D);

  static const double radiusSm = 6;
  static const double radiusMd = 10;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  /// Layout stretto (telefono / finestra stretta).
  static const double breakpointNarrow = 600;
}
