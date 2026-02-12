import 'package:flutter/material.dart';
import '../services/asset_service.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 768;
    final effectiveCollapsed = isSmall ? true : widget.isCollapsed;

    return Container(
      width: effectiveCollapsed ? AppSideNav.collapsedWidth : AppSideNav.expandedWidth,
      decoration: BoxDecoration(
        color: AppSideNav.backgroundColor.withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),  // 10% white border
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header Section
          SizedBox(
            height: AppSideNav.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: InkWell(
                onTap: () {
                  if (!isSmall) {
                    widget.onToggle();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppSideNav.hoverColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: effectiveCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!effectiveCollapsed)
                        const Text(
                          'Navigation',
                          style: TextStyle(
                            color: AppSideNav.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Icon(
                        effectiveCollapsed
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_left,
                        color: AppSideNav.textPrimary,
                        size: 20,
                      ),
                    ],
                  ),
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

          const SizedBox(height: 12),

          // Logout Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                if (!effectiveCollapsed)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                _buildNavItem(
                  label: 'Logout',
                  assetPath: 'assets/images/Logout_KhonoBuzz.png',
                  effectiveCollapsed: effectiveCollapsed,
                ),
              ],
            ),
          ),
        ],
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
          onTap: () => widget.onSelect(label),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: AppSideNav.itemHeight,
            decoration: BoxDecoration(
              // 📱 Expanded State (280px width)
              color: effectiveCollapsed
                  ? Colors.transparent  // All items transparent when collapsed
                  : isActive
                      ? AppSideNav.activeColor  // Red-orange background for active
                      : isHovering
                          ? AppSideNav.hoverColor  // Light blue-gray for hover
                          : Colors.transparent,  // Transparent for inactive
              borderRadius: BorderRadius.circular(12),
              boxShadow: effectiveCollapsed
                  ? null
                  : isActive
                      ? [
                          BoxShadow(
                            color: AppSideNav.activeColor.withValues(alpha: 0.21), // 21% shadow
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : isHovering
                          ? [
                              BoxShadow(
                                color: AppSideNav.hoverColor.withValues(alpha: 0.21), // 21% shadow
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: effectiveCollapsed
                        ? Colors.transparent
                        : isActive
                            ? AppSideNav.activeColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _buildIcon(assetPath, isActive, effectiveCollapsed),
                  ),
                ),
                
                // Text and arrow (only when expanded)
                if (!effectiveCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? AppSideNav.textPrimary
                            : AppSideNav.textSecondary,
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // Arrow indicator for active items
                  if (isActive)
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppSideNav.textPrimary,
                    ),
                ],
              ],
            ),
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

  bool _shouldHideItemForAdmin(String label) {
    if (!widget.isAdmin) return false;
    if (label == 'My Proposals') return true;
    if (label == 'Analytics (My Pipeline)') return true;
    return false;
  }
}
