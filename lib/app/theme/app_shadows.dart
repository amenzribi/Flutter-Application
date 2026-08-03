import 'package:flutter/material.dart';

/// Soft depth only — avoid multi-layer neon shadows.
abstract final class AppShadows {
  static List<BoxShadow> soft(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> card(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// Blur strength for selective glass (not full-screen).
  static const double glassBlur = 14;
}
