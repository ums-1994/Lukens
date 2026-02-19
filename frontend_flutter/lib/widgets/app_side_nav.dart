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
    final effectiveCollapsed = widget.isCollapsed;

    return GestureDetector(
      onTap: () {
        if (widget.isCollapsed) widget.onToggle();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: widget.isCollapsed
            ? AppSideNav.collapsedWidth
            : AppSideNav.expandedWidth,
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
                  onTap: widget.onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: widget.isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!widget.isCollapsed)
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
                              horizontal: widget.isCollapsed ? 0 : 8),
                          child: Icon(
                            widget.isCollapsed
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
                    if (!widget.isCollapsed)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        height: 1,
                        color: const Color(0xFF2C3E50),
                      ),
                    _buildItem('Logout', 'assets/images/Logout_KhonoBuzz.png'),
                    if (!widget.isCollapsed) ...[
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
    // Hide analytics entry for non-admin users by default.
    if (!widget.isAdmin && label.toLowerCase().contains('analytics')) return true;
    return false;
  }

  Widget _buildItem(String label, String assetPath) {
    return _buildNavItem(
      label: label,
      assetPath: assetPath,
      effectiveCollapsed: widget.isCollapsed,
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
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: InkWell(
          onTap: () => widget.onSelect(label),
          borderRadius: BorderRadius.circular(effectiveCollapsed ? 30 : 12),
          child: effectiveCollapsed
              ? _buildCollapsedIcon(assetPath, isActive, isHovering: isHovering)
              : _buildExpandedNavRow(label, assetPath, isActive,
                  isHovering: isHovering),
        ),
      ),
    );
  }

  Widget _buildExpandedNavRow(
    String label,
    String assetPath,
    bool isActive, {
    required bool isHovering,
  }) {
    final border = isActive
        ? Border.all(color: const Color(0xFFE74C3C), width: 1)
        : isHovering
            ? Border.all(color: Colors.white.withOpacity(0.18), width: 1)
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: _buildWhiteCircleIcon(assetPath, isActive),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFECF0F1),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isActive)
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildCollapsedIcon(
    String assetPath,
    bool isActive, {
    required bool isHovering,
  }) {
    final bg = isActive
        ? const Color(0xFFC10D00).withOpacity(0.16)
        : isHovering
            ? Colors.white.withOpacity(0.08)
            : Colors.transparent;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: const Color(0xFFE74C3C), width: 1)
            : null,
      ),
      padding: const EdgeInsets.all(10),
      child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
    );
  }

  Widget _buildWhiteCircleIcon(String assetPath, bool isActive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: const Color(0xFFE74C3C), width: 1)
            : Border.all(color: Colors.white.withOpacity(0.10), width: 1),
      ),
      padding: const EdgeInsets.all(10),
      child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
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
