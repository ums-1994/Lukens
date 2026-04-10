import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../../services/asset_service.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentPage,
    required this.onToggle,
    required this.onSelect,
    this.bottomLabel = 'Sign Out',
  });

  final bool isCollapsed;
  final String currentPage;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String bottomLabel;

  // UI Standard: Solid sidebar #2A2A2A @ 100%
  static const Color _adminBase = Color(0xFF2A2A2A);
  static const Color _adminAccent = Color(0xFFC10D00);

  static const List<_AdminNavItem> _items = [
    _AdminNavItem(
      label: 'Dashboard',
      assetPath: 'assets/images/Dahboard.png',
    ),
    _AdminNavItem(
      label: 'Approvals',
      assetPath: 'assets/images/Time Allocation_Approval_Blue.png',
    ),
    _AdminNavItem(
      label: 'Analytics',
      assetPath: 'assets/images/analytics.png',
    ),
    _AdminNavItem(
      label: 'History',
      assetPath: 'assets/images/analytics.png',
    ),
    _AdminNavItem(
      label: 'Content Library',
      assetPath: 'assets/images/content_library.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 90.0 : 250.0,
      decoration: const BoxDecoration(
        color: _adminBase,
        border: Border(
          right: BorderSide(
            color: Color(0x24FFFFFF),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveCollapsed = constraints.maxWidth < 160;

          return Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          effectiveCollapsed
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_left,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in _items)
                        _AdminSidebarNavItem(
                          label: item.label,
                          assetPath: item.assetPath,
                          isActive: currentPage == item.label,
                          isCollapsed: effectiveCollapsed,
                          onTap: () => onSelect(item.label),
                          accent: _adminAccent,
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (!effectiveCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: Colors.white.withOpacity(0.14),
                ),
              const SizedBox(height: 12),
              _AdminSidebarNavItem(
                label: bottomLabel,
                assetPath: 'assets/images/Logout_KhonoBuzz.png',
                isActive: false,
                isCollapsed: effectiveCollapsed,
                onTap: () => onSelect(bottomLabel),
                accent: _adminAccent,
              ),
              if (!effectiveCollapsed) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      AppConstants.fullVersion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _AdminNavItem {
  final String label;
  final String assetPath;

  const _AdminNavItem({required this.label, required this.assetPath});
}

class _AdminSidebarNavItem extends StatelessWidget {
  const _AdminSidebarNavItem({
    required this.label,
    required this.assetPath,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final String assetPath;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isActive
                      ? accent
                      : Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath,
                      fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? accent
                  : Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: AssetService.buildImageWidget(assetPath,
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
