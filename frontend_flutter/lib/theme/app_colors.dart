import 'package:flutter/material.dart';

class AppColors {
  // UI Standard: Solid sidebar #2A2A2A @ 100%
  static const Color backgroundColor = Color(0xFF2A2A2A);
  static const Color hoverColor = Color(0xFF3A3A3A);
  static const Color activeColor = Color(0xFFC10D00);
  // UI Standard: Text #FFFFFF @ 100%
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x8AFFFFFF);

  // UI Standard: floating widgets #FFFFFF @ 14%
  static const Color borderColor = Color(0x24FFFFFF);
  static const Color activeShadowColor = Colors.transparent;
  static const Color hoverShadowColor = Colors.transparent;

  static const double collapsedWidth = 72.0;
  static const double expandedWidth = 280.0;
  static const double headerHeight = 64.0;
  static const double itemHeight = 44.0;

  static const double backgroundOpacity = 1.0;
  static const double borderOpacity = 0.14;
  static const double shadowOpacity = 0;

  static const Duration animationDuration = Duration(milliseconds: 300);
}

class AppSpacing {
  static const EdgeInsets sidebarHeaderPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets sidebarItemPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);
}
