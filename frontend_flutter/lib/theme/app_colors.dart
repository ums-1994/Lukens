import 'package:flutter/material.dart';

class AppColors {
  // 🎯 Core Sidebar Colors
  static const Color backgroundColor = Color(0xFF1F2840); // Dark blue-gray
  static const Color hoverColor = Color(0xFF2A3652); // Lighter blue-gray
  static const Color activeColor = Color(0xFFC10D00); // Red-orange accent
  static const Color textPrimary = Colors.white; // White text
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color textMuted = Color(0x8AFFFFFF); // 54% white

  // 🎨 Border & Shadow Colors
  static const Color borderColor = Color(0x1AFFFFFF); // 10% white border
  static const Color activeShadowColor = Color(0x59C10D00); // 21% red shadow
  static const Color hoverShadowColor = Color(0x592A3652); // 21% blue shadow

  // 📐 Sidebar Dimensions
  static const double collapsedWidth = 72.0;
  static const double expandedWidth = 280.0;
  static const double headerHeight = 64.0;
  static const double itemHeight = 44.0;

  // 🎭 Visual Effects
  static const double backgroundOpacity = 0.95;
  static const double borderOpacity = 0.1;
  static const double shadowOpacity = 0x35; // 21% in hex

  // 🔄 Animation Duration
  static const Duration animationDuration = Duration(milliseconds: 300);
}

class AppSpacing {
  static const EdgeInsets sidebarHeaderPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets sidebarItemPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);
}
