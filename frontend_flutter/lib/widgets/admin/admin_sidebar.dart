import 'package:flutter/material.dart';

import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';

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

  static const Color _adminBase = Color(0xFF252525);
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
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 90.0 : 250.0,
      decoration: BoxDecoration(
        color: _adminBase,
        border: Border(
          right: BorderSide(
            color: PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _adminBase.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isCollapsed)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Navigation',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 8),
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
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in _items)
                    _AdminSidebarNavItem(
                      label: item.label,
                      assetPath: item.assetPath,
                      isActive: currentPage == item.label,
                      isCollapsed: isCollapsed,
                      onTap: () => onSelect(item.label),
                      accent: _adminAccent,
                      base: _adminBase,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: const Color(0xFF2C3E50),
            ),
          const SizedBox(height: 12),
          _AdminSidebarNavItem(
            label: bottomLabel,
            assetPath: 'assets/images/Logout_KhonoBuzz.png',
            isActive: false,
            isCollapsed: isCollapsed,
            onTap: () => onSelect(bottomLabel),
            accent: _adminAccent,
            base: _adminBase,
          ),
          const SizedBox(height: 20),
        ],
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
    required this.base,
  });

  final String label;
  final String assetPath;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color accent;
  final Color base;

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
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: base.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? accent : Colors.white.withValues(alpha: 0.18),
                    width: isActive ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
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
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? base.withValues(alpha: 0.30) : base.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? accent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? accent : Colors.white.withValues(alpha: 0.18),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
                  ),
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
          ),
        ),
      ),
    );
  }
}

