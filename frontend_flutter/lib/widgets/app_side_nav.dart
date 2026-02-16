import 'package:flutter/material.dart';
import '../services/asset_service.dart';
import '../theme/premium_theme.dart';
import '../config/app_constants.dart';

class AppSideNav extends StatelessWidget {
  const AppSideNav({
    super.key,
    required this.isCollapsed,
    required this.currentLabel,
    required this.onSelect,
    required this.onToggle,
    required this.isAdmin,
    required this.isLightMode,
    required this.onToggleThemeMode,
    this.extraItems = const [],
  });

  final bool isCollapsed;
  final String currentLabel;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;
  final bool isAdmin;
  final bool isLightMode;
  final VoidCallback onToggleThemeMode;
  final List<Map<String, String>> extraItems;

  static const double collapsedWidth = 90.0;
  static const double expandedWidth = 250.0;

  static const double _collapsedItemVerticalPadding = 6.0;
  static const double _expandedItemVerticalPadding = 4.0;
  static const double _expandedItemInternalVerticalPadding = 8.0;
  static const double _expandedIconBoxSize = 44.0;
  static const double _iconCircleSize = 36.0;
  static const double _iconCirclePadding = 5.0;
  static const double _labelFontSize = 12.0;

  static const List<Map<String, String>> _items = [
    {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
    {'label': 'My Proposals', 'icon': 'assets/images/My_Proposals.png'},
    {'label': 'Templates', 'icon': 'assets/images/content_library.png'},
    {'label': 'Content Library', 'icon': 'assets/images/content_library.png'},
    {'label': 'Client Management', 'icon': 'assets/images/collaborations.png'},
    {
      'label': 'Approved Proposals',
      'icon': 'assets/images/Time Allocation_Approval_Blue.png'
    },
    {'label': 'Analytics (My Pipeline)', 'icon': 'assets/images/analytics.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isCollapsed) onToggle();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isCollapsed ? collapsedWidth : expandedWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.2),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(
            right: BorderSide(
              color: PremiumTheme.glassWhiteBorder,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Toggle button (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isCollapsed)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Navigation',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: isCollapsed ? 0 : 8),
                          child: Icon(
                            isCollapsed
                                ? Icons.keyboard_arrow_right
                                : Icons.keyboard_arrow_left,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Main icons
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final it in _items)
                        if (!_shouldHideItemForAdmin(it['label']!))
                          _buildItem(it['label']!, it['icon']!),
                      for (final it in extraItems)
                        _buildItem(it['label']!, it['icon']!),
                    ],
                  ),
                ),
              ),

              // Bottom section - Logout
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (!isCollapsed)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        height: 1,
                        color: const Color(0xFF2C3E50),
                      ),
                    _buildItem('Logout', 'assets/images/Logout_KhonoBuzz.png'),
                    if (!isCollapsed) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFF2C3E50), width: 1),
                          ),
                          child: Text(
                            AppConstants.fullVersion,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldHideItemForAdmin(String label) {
    return false;
  }

  Widget _buildItem(String label, String assetPath) {
    final bool active = label == currentLabel;
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: _collapsedItemVerticalPadding),
        child: InkWell(
          onTap: () => onSelect(label),
          borderRadius: BorderRadius.circular(30),
          child: _buildCollapsedIcon(assetPath, active),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: _expandedItemVerticalPadding),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: _expandedItemInternalVerticalPadding),
          decoration: BoxDecoration(
            color:
                active ? PremiumTheme.purple.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? PremiumTheme.purple
                  : PremiumTheme.glassWhiteBorder.withValues(alpha: 0.7),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _expandedIconBoxSize,
                height: _expandedIconBoxSize,
                child: _buildWhiteCircleIcon(assetPath, active),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFFECF0F1),
                    fontSize: _labelFontSize,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (active)
                const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedIcon(String assetPath, bool active) {
    return _buildWhiteCircleIcon(assetPath, active);
  }

  Widget _buildWhiteCircleIcon(String assetPath, bool active) {
    return Container(
      width: _iconCircleSize,
      height: _iconCircleSize,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? PremiumTheme.purple : const Color(0xFF4B5563),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: PremiumTheme.purple.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.all(_iconCirclePadding),
      child: ClipOval(
        child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}
