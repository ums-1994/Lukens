import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../services/asset_service.dart';
import '../theme/manager_theme_controller.dart';

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

  static const Color activeColor = Color(0xFFC10D00);
  static const Color leftAccentColor = Color(0xFF1565C0);

  static const double collapsedWidth = 80.0;
  static const double expandedWidth = 300.0;

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
    final chrome = context.watch<ManagerThemeController>().chrome;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isCollapsed
          ? AppSideNav.collapsedWidth
          : AppSideNav.expandedWidth,
      decoration: BoxDecoration(
        color: chrome.sidebarBackground,
        border: Border(
          left: const BorderSide(color: AppSideNav.leftAccentColor, width: 3),
          right: BorderSide(color: chrome.sidebarRightBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(widget.isCollapsed, chrome),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final item in AppSideNav._items)
                      _buildNavItem(
                        label: item['label']!,
                        assetPath: item['icon']!,
                        isCollapsed: widget.isCollapsed,
                        chrome: chrome,
                      ),
                  ],
                ),
              ),
            ),
            _buildBottom(widget.isCollapsed, chrome),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCollapsed, ManagerChromeTheme chrome) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: chrome.sidebarHoverFill,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_arrow_right,
              color: chrome.textPrimary,
              size: 24,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: chrome.sidebarHoverFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_left,
                  color: chrome.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 4),
              Image.asset(
                'assets/images/new icons for manager/khonology_logo.png',
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to',
                style: TextStyle(
                  color: chrome.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Proposal & SOW Builder',
                style: TextStyle(
                  color: chrome.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Container(
                height: 1,
                color: chrome.divider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String label,
    required String assetPath,
    required bool isCollapsed,
    required ManagerChromeTheme chrome,
  }) {
    final bool isActive = label == widget.currentLabel;
    final bool isHovering = _hoveringItem == label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveringItem = label),
      onExit: (_) => setState(() => _hoveringItem = null),
      child: Padding(
        padding: isCollapsed
            ? const EdgeInsets.symmetric(vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: InkWell(
            onTap: () => widget.onSelect(label),
            borderRadius: BorderRadius.circular(10),
            child: isCollapsed
                ? _buildCollapsedIcon(assetPath, isActive, isHovering, chrome)
                : _buildExpandedRow(label, assetPath, isActive, isHovering, chrome),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedRow(
    String label,
    String assetPath,
    bool isActive,
    bool isHovering,
    ManagerChromeTheme chrome,
  ) {
    final Color rowHover =
        isHovering ? chrome.sidebarHoverFill : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? AppSideNav.activeColor : rowHover,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.22)
                  : chrome.sidebarIconCircleFill,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(9),
            child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : chrome.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.2,
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
    bool isActive,
    bool isHovering,
    ManagerChromeTheme chrome,
  ) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive
              ? AppSideNav.activeColor
              : isHovering
                  ? chrome.sidebarHoverFill
                  : chrome.sidebarCollapsedIconIdle,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildBottom(bool isCollapsed, ManagerChromeTheme chrome) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          if (!isCollapsed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              height: 1,
              color: chrome.divider,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: InkWell(
              onTap: () =>
                  context.read<ManagerThemeController>().toggle(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 0 : 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: chrome.sidebarHoverFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isCollapsed
                    ? Center(
                        child: Icon(
                          chrome.isDark
                              ? Icons.wb_sunny_rounded
                              : Icons.dark_mode_rounded,
                          color: chrome.textPrimary,
                          size: 22,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            chrome.isDark
                                ? Icons.wb_sunny_rounded
                                : Icons.dark_mode_rounded,
                            color: chrome.textPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              chrome.isDark ? 'Light mode' : 'Dark mode',
                              style: TextStyle(
                                color: chrome.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            label: 'Account Profile',
            assetPath: 'assets/images/User_Profile.png',
            isCollapsed: isCollapsed,
            chrome: chrome,
          ),
          _buildNavItem(
            label: 'Logout',
            assetPath: 'assets/images/Logout_KhonoBuzz.png',
            isCollapsed: isCollapsed,
            chrome: chrome,
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: chrome.sidebarHoverFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppConstants.fullVersion,
                  style: TextStyle(
                    color: chrome.textSecondary,
                    fontSize: 11,
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
