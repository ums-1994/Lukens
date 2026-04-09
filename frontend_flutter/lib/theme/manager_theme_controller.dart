import 'package:flutter/material.dart';

/// Light / dark chrome for Manager & SOW Builder shell (sidebar, panels, text).
///
/// Light mode (spec): sidebar #FFFFFF @ 100%, floating widgets #7F7F7F73,
/// text #090812 @ 100%. Radius 10px, no shadows.
class ManagerChromeTheme {
  const ManagerChromeTheme._({required this.isDark});

  static const ManagerChromeTheme dark = ManagerChromeTheme._(isDark: true);
  static const ManagerChromeTheme light = ManagerChromeTheme._(isDark: false);

  final bool isDark;

  static const Color textDark = Color(0xFF090812);

  /// Light floating panels (RRGGBBAA → Flutter ARGB: #7F7F7F73).
  static const Color floatingLightFill = Color(0x737F7F7F);

  static const String darkBgAsset =
      'assets/images/new icons for manager/new_universal_bg_darkmode.png';
  static const String lightBgAsset =
      'assets/images/new icons for manager/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png';

  String get backgroundAsset => isDark ? darkBgAsset : lightBgAsset;

  Color get sidebarBackground => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  Color get sidebarRightBorder =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

  Color get textPrimary => isDark ? Colors.white : textDark;

  Color get textSecondary =>
      isDark ? Colors.white.withOpacity(0.55) : textDark.withOpacity(0.62);

  Color get textMuted =>
      isDark ? Colors.white.withOpacity(0.45) : textDark.withOpacity(0.5);

  /// Floating panels / cards
  Color get floatingFill =>
      isDark ? Colors.white.withOpacity(0.14) : floatingLightFill;

  /// Floating panels (light: #7F7F7F73 fill + divider border).
  BoxDecoration floatingPanelDecoration({
    double radius = 10,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      color: floatingFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: divider, width: borderWidth),
    );
  }

  Color get headerBarFill => floatingFill;

  Color get divider =>
      isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.10);

  Color get sidebarHoverFill =>
      isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06);

  Color get sidebarIconCircleFill =>
      isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06);

  Color get sidebarCollapsedIconIdle =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  Color get filterInactiveBg =>
      isDark ? Colors.black : Colors.white.withOpacity(0.55);

  Color get filterBorder => const Color(0xFFC10D00);

  /// Text fields / search on floating panels
  Color get fieldFill => isDark
      ? Colors.white.withOpacity(0.06)
      : Colors.white.withOpacity(0.72);

  Color get fieldBorder => isDark
      ? Colors.white.withOpacity(0.12)
      : Colors.black.withOpacity(0.14);

  Color get dropdownSurface => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  /// Scrollbar track (light bg needs visible track)
  Color get scrollbarTrack =>
      isDark ? const Color(0xFF1A1F26) : Colors.black.withOpacity(0.06);

  Color get scrollbarThumb =>
      isDark ? const Color(0xFF3498DB) : accentRed;

  static const Color accentRed = Color(0xFFC10D00);
  static const Color leftAccentBlue = Color(0xFF1565C0);
}

class ManagerThemeController extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  ManagerChromeTheme get chrome =>
      _isDark ? ManagerChromeTheme.dark : ManagerChromeTheme.light;

  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
  }

  void toggle() => setDark(!_isDark);
}
