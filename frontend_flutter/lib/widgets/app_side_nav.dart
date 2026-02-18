import 'package:flutter/material.dart';
import '../services/asset_service.dart';
import '../theme/premium_theme.dart';
import '../config/app_constants.dart';

class AppSideNav extends StatefulWidget {
  const AppSideNav({
    super.key,
    required this.isCollapsed,
    required this.currentLabel,
    required this.onSelect,
    required this.onToggle,
    required this.isAdmin,
  });

  final bool isCollapsed;
  final String currentLabel;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;
  final bool isAdmin;

  // 🎨 Core Sidebar Colors
  static const Color backgroundColor = Color(0xFF1F2840);    // Dark blue-gray
  static const Color hoverColor = Color(0xFF2A3652);        // Lighter blue-gray  
  static const Color activeColor = Color(0xFFC10D00);        // Red-orange accent
  static const Color textPrimary = Colors.white;               // White text
  static const Color textSecondary = Colors.white70;           // 70% white
  static const Color textMuted = Colors.white54;              // 54% white

  // 📐 Layout Dimensions
  static const double collapsedWidth = 72.0;  // Collapsed: 72px
  static const double expandedWidth = 280.0;   // Expanded: 280px
  static const double itemHeight = 44.0;      // Each nav item height
  static const double headerHeight = 64.0;    // Fixed header height

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
  State<AppSideNav> createState() => _AppSideNavState();
}

class _AppSideNavState extends State<AppSideNav> {
  String? _hoveringItem;

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
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.2),
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
              const SizedBox(height: 16),
              // Toggle button (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
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

          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in AppSideNav._items)
                    if (!_shouldHideItemForAdmin(item['label']!))
                      _buildNavItem(
                        label: item['label']!,
                        assetPath: item['icon']!,
                        effectiveCollapsed: effectiveCollapsed,
                      ),
                ],
              ),
            ),
          ),

              // Bottom section - Logout
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    if (!isCollapsed)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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

  Widget _buildNavItem({
    required String label,
    required String assetPath,
    required bool effectiveCollapsed,
  }) {
    final bool isActive = label == widget.currentLabel;
    final bool isHovering = _hoveringItem == label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveringItem = label),
      onExit: (_) => setState(() => _hoveringItem = null),
      child: Padding(
        padding: effectiveCollapsed
            ? const EdgeInsets.symmetric(vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => onSelect(label),
          borderRadius: BorderRadius.circular(30),
          child: _buildCollapsedIcon(assetPath, active),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            // Keep row background transparent so the sidebar color is stable
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            // Use a subtle red border to indicate the active item
            border: active
                ? Border.all(color: const Color(0xFFE74C3C), width: 1)
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: _buildWhiteCircleIcon(assetPath, active),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFFECF0F1),
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (active)
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String assetPath, bool isActive, bool isCollapsed) {
    // 🎨 Icon Color Logic
    // AssetService.buildImageWidget doesn't support color tinting
    // Icons will use their original colors
    return ClipOval(
      child: AssetService.buildImageWidget(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }
}
