import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/asset_service.dart';
import '../theme/app_colors.dart';

class FixedSidebar extends StatefulWidget {
  final String currentPage;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Function(String) onNavigate;
  final VoidCallback onLogout;
  final Map<String, String>? customAssets;

  const FixedSidebar({
    super.key,
    required this.currentPage,
    required this.isCollapsed,
    required this.onToggle,
    required this.onNavigate,
    required this.onLogout,
    this.customAssets,
  });

  @override
  State<FixedSidebar> createState() => _FixedSidebarState();
}

class _FixedSidebarState extends State<FixedSidebar> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 768;
    final effectiveCollapsed = isSmall ? true : widget.isCollapsed;
    
    return AnimatedContainer(
      duration: AppColors.animationDuration,
      width: effectiveCollapsed ? AppColors.collapsedWidth : AppColors.expandedWidth,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundColor.withValues(alpha: AppColors.backgroundOpacity),
            border: Border(
              right: BorderSide(
                color: AppColors.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Header Section
              SizedBox(
                height: AppColors.headerHeight,
                child: Padding(
                  padding: AppSpacing.sidebarHeaderPadding,
                  child: InkWell(
                    onTap: () {
                      if (!isSmall) {
                        widget.onToggle();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: AppColors.itemHeight,
                      decoration: BoxDecoration(
                        color: AppColors.hoverColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: effectiveCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.spaceBetween,
                        children: [
                          if (!effectiveCollapsed)
                            Expanded(
                              child: Text(
                                'Navigation',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Icon(
                            effectiveCollapsed
                                ? Icons.keyboard_arrow_right
                                : Icons.keyboard_arrow_left,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Navigation Items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildSidebarNavItem(
                        label: 'Dashboard',
                        assetPath: widget.customAssets?['Dashboard'] ?? 'assets/images/Dahboard.png',
                        isSelected: widget.currentPage == 'Dashboard',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('Dashboard'),
                      ),
                      _buildSidebarNavItem(
                        label: 'My Proposals',
                        assetPath: widget.customAssets?['My Proposals'] ?? 'assets/images/My_Proposals.png',
                        isSelected: widget.currentPage == 'My Proposals',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('My Proposals'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Templates',
                        assetPath: widget.customAssets?['Templates'] ?? 'assets/images/content_library.png',
                        isSelected: widget.currentPage == 'Templates',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('Templates'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Content Library',
                        assetPath: widget.customAssets?['Content Library'] ?? 'assets/images/content_library.png',
                        isSelected: widget.currentPage == 'Content Library',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('Content Library'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Client Management',
                        assetPath: widget.customAssets?['Client Management'] ?? 'assets/images/collaborations.png',
                        isSelected: widget.currentPage == 'Client Management',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('Client Management'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Approved Proposals',
                        assetPath: widget.customAssets?['Approved Proposals'] ?? 'assets/images/Time Allocation_Approval_Blue.png',
                        isSelected: widget.currentPage == 'Approved Proposals',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('Approved Proposals'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Analytics (My Pipeline)',
                        assetPath: widget.customAssets?['Analytics (My Pipeline)'] ?? 'assets/images/analytics.png',
                        isSelected: widget.currentPage == 'Analytics (My Pipeline)',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => widget.onNavigate('Analytics (My Pipeline)'),
                      ),
                      const SizedBox(height: 20),
                      
                      // Divider
                      if (!effectiveCollapsed)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 1,
                          color: AppColors.borderColor,
                        ),
                      const SizedBox(height: 12),
                      
                      // Logout
                      _buildSidebarNavItem(
                        label: 'Logout',
                        assetPath: widget.customAssets?['Logout'] ?? 'assets/images/Logout_KhonoBuzz.png',
                        isSelected: false,
                        isCollapsed: effectiveCollapsed,
                        onTap: widget.onLogout,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required String label,
    required String assetPath,
    required bool isSelected,
    required bool isCollapsed,
    required VoidCallback onTap,
    bool showProfileIndicator = false,
  }) {
    bool hovering = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: MouseRegion(
            onEnter: (_) => setState(() => hovering = true),
            onExit: (_) => setState(() => hovering = false),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: AppColors.animationDuration,
                height: AppColors.itemHeight,
                decoration: BoxDecoration(
                  color: _getItemColor(isSelected, hovering, isCollapsed),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _getItemShadow(isSelected, hovering, isCollapsed),
                ),
                child: isCollapsed
                    ? _buildCollapsedItem(assetPath, isSelected, showProfileIndicator)
                    : _buildExpandedItem(label, assetPath, isSelected),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedItem(String assetPath, bool isSelected, bool showProfileIndicator) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: AssetService.buildImageWidget(
                assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (showProfileIndicator)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.activeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedItem(String label, String assetPath, bool isSelected) {
    return Padding(
      padding: AppSpacing.sidebarItemPadding,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
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
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textPrimary,
            ),
        ],
      ),
    );
  }

  Color _getItemColor(bool isSelected, bool hovering, bool isCollapsed) {
    if (isCollapsed) {
      return Colors.transparent; // All items transparent when collapsed
    }
    
    if (isSelected) {
      return AppColors.activeColor;
    }
    
    if (hovering) {
      return AppColors.hoverColor;
    }
    
    return Colors.transparent;
  }

  List<BoxShadow> _getItemShadow(bool isSelected, bool hovering, bool isCollapsed) {
    if (isCollapsed) {
      return []; // No shadow when collapsed
    }
    
    if (isSelected) {
      return [
        BoxShadow(
          color: AppColors.activeShadowColor,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
    }
    
    if (hovering) {
      return [
        BoxShadow(
          color: AppColors.hoverShadowColor,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
    }
    
    return [];
  }
}
