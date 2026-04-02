import 'package:flutter/material.dart';
import '../services/asset_service.dart';
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

  // Core colors matching the Khonology design
  static const Color backgroundColor = Color(0xFF1A1D2E);
  static const Color activeColor = Color(0xFFC10D00);
  static const Color leftAccentColor = Color(0xFF1565C0);

  // Layout dimensions
  static const double collapsedWidth = 72.0;
  static const double expandedWidth = 260.0;

  static const List<Map<String, String>> _items = [
    {
      'label': 'Dashboard',
      'icon': 'assets/images/new icons for manager/Dashboard.png',
    },
    {
      'label': 'Proposals',
      'icon': 'assets/images/new icons for manager/proposals.png',
    },
    {
      'label': 'Templates',
      'icon': 'assets/images/new icons for manager/Templates.png',
    },
    {
      'label': 'Content Library',
      'icon': 'assets/images/new icons for manager/content library.png',
    },
    {
      'label': 'Client Management',
      'icon': 'assets/images/new icons for manager/client_management.png',
    },
    {
      'label': 'Approved Proposals',
      'icon': 'assets/images/new icons for manager/Approved proposals.png',
    },
    {
      'label': 'Analytics (My Pipeline)',
      'icon': 'assets/images/analytics.png',
    },
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
        if (widget.isCollapsed) widget.onToggle();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: widget.isCollapsed
            ? AppSideNav.collapsedWidth
            : AppSideNav.expandedWidth,
        decoration: BoxDecoration(
          color: AppSideNav.backgroundColor,
          border: Border(
            left: BorderSide(
              color: AppSideNav.leftAccentColor,
              width: 3,
            ),
            right: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final effectiveCollapsed = widget.isCollapsed;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  _buildHeader(effectiveCollapsed),

                  // ── Nav Items ───────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          for (final item in AppSideNav._items)
                            _buildNavItem(
                              label: item['label']!,
                              assetPath: item['icon']!,
                              effectiveCollapsed: effectiveCollapsed,
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom: divider + Logout + version ──────────────────
                  _buildBottom(effectiveCollapsed),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool effectiveCollapsed) {
    if (effectiveCollapsed) {
      // Collapsed: just the toggle arrow
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.keyboard_arrow_right,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo + collapse toggle in one row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Khonology logo
              Expanded(
                child: Image.asset(
                  'assets/images/new icons for manager/khonology_logo.png',
                  height: 22,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
              InkWell(
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.keyboard_arrow_left,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Sub-header text
          const Text(
            'Welcome to',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          const Text(
            'Proposal & SOW Builder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // Thin divider below header
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.10),
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
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Tooltip(
          message: effectiveCollapsed ? label : '',
          child: InkWell(
            onTap: () => widget.onSelect(label),
            borderRadius: BorderRadius.circular(effectiveCollapsed ? 30 : 10),
            child: effectiveCollapsed
                ? _buildCollapsedIcon(assetPath, isActive, isHovering: isHovering)
                : _buildExpandedRow(label, assetPath, isActive, isHovering: isHovering),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedRow(
    String label,
    String assetPath,
    bool isActive, {
    required bool isHovering,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isActive
            ? AppSideNav.activeColor
            : isHovering
                ? Colors.white.withOpacity(0.06)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Circular icon container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFCDD5E0),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedIcon(
    String assetPath,
    bool isActive, {
    required bool isHovering,
  }) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive
            ? AppSideNav.activeColor
            : isHovering
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(11),
      child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
    );
  }

  Widget _buildBottom(bool effectiveCollapsed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (!effectiveCollapsed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              height: 1,
              color: Colors.white.withOpacity(0.10),
            ),
          _buildNavItem(
            label: 'Logout',
            assetPath: 'assets/images/Logout_KhonoBuzz.png',
            effectiveCollapsed: effectiveCollapsed,
          ),
          if (!effectiveCollapsed) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
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
    );
  }
}
