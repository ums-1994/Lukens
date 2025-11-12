import 'package:flutter/material.dart';
import '../services/asset_service.dart';

class AppSideNav extends StatelessWidget {
  const AppSideNav({
    super.key,
    required this.isCollapsed,
    required this.currentLabel,
    required this.onSelect,
    required this.onToggle,
  });

  final bool isCollapsed;
  final String currentLabel;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;

  static const double collapsedWidth = 90.0;
  static const double expandedWidth = 250.0;

  static const List<Map<String, String>> _items = [
    {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
    {'label': 'My Proposals', 'icon': 'assets/images/My_Proposals.png'},
    {'label': 'Templates', 'icon': 'assets/images/content_library.png'},
    {'label': 'Content Library', 'icon': 'assets/images/content_library.png'},
    {'label': 'Client Management', 'icon': 'assets/images/collaborations.png'},
    {'label': 'Approvals Status', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
    {'label': 'Analytics (My Pipeline)', 'icon': 'assets/images/analytics.png'},
  ];

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
        color: const Color(0xFF34495E),
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
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 8),
                          child: Icon(
                            isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Main icons
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final it in _items) _buildItem(it['label']!, it['icon']!),
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
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        height: 1,
                        color: const Color(0xFF2C3E50),
                      ),
                    _buildItem('Logout', 'assets/images/Logout_KhonoBuzz.png'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String label, String assetPath) {
    final bool active = label == currentLabel;
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
            color: active ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border.all(color: const Color(0xFF2980B9), width: 1) : null,
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
              if (active) const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedIcon(String assetPath, bool active) {
    return _buildWhiteCircleIcon(assetPath, active);
  }

  Widget _buildWhiteCircleIcon(String assetPath, bool active) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFFE74C3C) : const Color(0xFFCBD5E1),
          width: active ? 2 : 1,
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
        child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
      ),
    );
  }

}

