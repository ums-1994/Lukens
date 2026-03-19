import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../../theme/premium_theme.dart';

class FinanceSidebar extends StatelessWidget {
  const FinanceSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentPage,
    required this.onToggle,
    required this.onSelect,
    this.bottomLabel = 'Sign Out',
    this.showAudit = false,
    this.pendingBadge,
  });

  final bool isCollapsed;
  final String currentPage;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String bottomLabel;
  final bool showAudit;
  final int? pendingBadge;

  static const Color _base = Color(0xFF252525);
  static const Color _accent = PremiumTheme.teal;

  @override
  Widget build(BuildContext context) {
    final items = <_FinanceNavItem>[
      const _FinanceNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
      _FinanceNavItem(
        label: 'Proposals',
        icon: Icons.description_outlined,
        badge: pendingBadge,
      ),
      const _FinanceNavItem(
        label: 'Client Management',
        icon: Icons.business_outlined,
      ),
      if (showAudit)
        const _FinanceNavItem(
          label: 'Audit',
          icon: Icons.receipt_long_outlined,
        ),
      const _FinanceNavItem(label: 'Analytics', icon: Icons.analytics_outlined),
      const _FinanceNavItem(label: 'Settings', icon: Icons.settings_outlined),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 90.0 : 250.0,
      decoration: BoxDecoration(
        color: _base,
        border: Border(
          right: BorderSide(
            color: PremiumTheme.glassWhiteBorder,
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _base.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 1,
                      ),
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
                      for (final item in items)
                        _FinanceSidebarNavItem(
                          label: item.label,
                          icon: item.icon,
                          badge: item.badge,
                          isActive: currentPage == item.label,
                          isCollapsed: effectiveCollapsed,
                          onTap: () => onSelect(item.label),
                          accent: _accent,
                          base: _base,
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
                  color: const Color(0xFF2C3E50),
                ),
              const SizedBox(height: 12),
              _FinanceSidebarNavItem(
                label: bottomLabel,
                icon: Icons.logout,
                badge: null,
                isActive: false,
                isCollapsed: effectiveCollapsed,
                onTap: () => onSelect(bottomLabel),
                accent: _accent,
                base: _base,
              ),
              if (!effectiveCollapsed) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF2C3E50),
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
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _FinanceNavItem {
  final String label;
  final IconData icon;
  final int? badge;

  const _FinanceNavItem({required this.label, required this.icon, this.badge});
}

class _FinanceSidebarNavItem extends StatelessWidget {
  const _FinanceSidebarNavItem({
    required this.label,
    required this.icon,
    required this.badge,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    required this.accent,
    required this.base,
  });

  final String label;
  final IconData icon;
  final int? badge;
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: base.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? accent
                            : Colors.white.withValues(alpha: 0.18),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      icon,
                      color: isActive ? Colors.white : Colors.white70,
                      size: 22,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          badge! > 99 ? '99+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
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
              color: isActive
                  ? base.withValues(alpha: 0.30)
                  : base.withValues(alpha: 0.18),
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
                      color: isActive
                          ? accent
                          : Colors.white.withValues(alpha: 0.18),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    icon,
                    color: isActive ? Colors.white : const Color(0xFFECF0F1),
                    size: 20,
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
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      badge! > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (isActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
