import 'package:flutter/material.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';

/// Left navigation sidebar used by the document editor.
///
/// This widget is purely presentational: it renders navigation items based
/// on the current page and admin status, and reports user interactions back
/// via callbacks.
class LeftSidebar extends StatelessWidget {
  const LeftSidebar({
    super.key,
    required this.isCollapsed,
    required this.isAdmin,
    required this.currentPage,
    required this.onToggleCollapse,
    required this.onNavigate,
  });

  final bool isCollapsed;
  final bool isAdmin;
  final String currentPage;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isCollapsed) {
          onToggleCollapse();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isCollapsed ? 90.0 : 250.0,
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Toggle button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: onToggleCollapse,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: PremiumTheme.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PremiumTheme.glassWhiteBorder,
                        width: 1,
                      ),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCollapsed ? 0 : 8,
                          ),
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
              // Navigation items
              _buildSidebarItems(),
              const SizedBox(height: 20),
              // Divider
              if (!isCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: const Color(0xFF2C3E50),
                ),
              const SizedBox(height: 12),
              // Logout button
              _buildNavItem(
                label: 'Logout',
                assetPath: 'assets/images/Logout_KhonoBuzz.png',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItems() {
    if (isAdmin) {
      // Admin sidebar items
      return Column(
        children: [
          _buildNavItem(
            label: 'Dashboard',
            assetPath: 'assets/images/Dahboard.png',
          ),
          _buildNavItem(
            label: 'Proposals for Review',
            assetPath: 'assets/images/Time Allocation_Approval_Blue.png',
          ),
          _buildNavItem(
            label: 'Governance & Risk',
            assetPath: 'assets/images/Time Allocation_Approval_Blue.png',
          ),
          _buildNavItem(
            label: 'Template Management',
            assetPath: 'assets/images/content_library.png',
          ),
          _buildNavItem(
            label: 'Content Library',
            assetPath: 'assets/images/content_library.png',
          ),
          _buildNavItem(
            label: 'Client Management',
            assetPath: 'assets/images/collaborations.png',
          ),
          _buildNavItem(
            label: 'User Management',
            assetPath: 'assets/images/collaborations.png',
          ),
          _buildNavItem(
            label: 'Approved Proposals',
            assetPath: 'assets/images/Time Allocation_Approval_Blue.png',
          ),
          _buildNavItem(
            label: 'Audit Logs',
            assetPath: 'assets/images/analytics.png',
          ),
          _buildNavItem(
            label: 'Settings',
            assetPath: 'assets/images/analytics.png',
          ),
        ],
      );
    } else {
      // Creator sidebar items
      return Column(
        children: [
          _buildNavItem(
            label: 'Dashboard',
            assetPath: 'assets/images/Dahboard.png',
          ),
          _buildNavItem(
            label: 'My Proposals',
            assetPath: 'assets/images/My_Proposals.png',
          ),
          _buildNavItem(
            label: 'Templates',
            assetPath: 'assets/images/content_library.png',
          ),
          _buildNavItem(
            label: 'Content Library',
            assetPath: 'assets/images/content_library.png',
          ),
          _buildNavItem(
            label: 'Client Management',
            assetPath: 'assets/images/collaborations.png',
          ),
          _buildNavItem(
            label: 'Approved Proposals',
            assetPath: 'assets/images/Time Allocation_Approval_Blue.png',
          ),
          _buildNavItem(
            label: 'Analytics (My Pipeline)',
            assetPath: 'assets/images/analytics.png',
          ),
        ],
      );
    }
  }

  Widget _buildNavItem({
    required String label,
    required String assetPath,
  }) {
    final bool isActive = currentPage == label;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => onNavigate(label),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFFCBD5E1),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: AssetService.buildImageWidget(
                  assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onNavigate(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0xFF2980B9), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFFCBD5E1),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
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
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
