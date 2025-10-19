import 'package:flutter/material.dart';
import '../services/asset_service.dart';
import '../services/auth_service.dart';

class AppSideNav extends StatefulWidget {
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

  @override
  State<AppSideNav> createState() => _AppSideNavState();
}

class _AppSideNavState extends State<AppSideNav> {
  @override
  void initState() {
    super.initState();
    // Force rebuild when role changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(AppSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when widget updates
    setState(() {});
  }
  static const double collapsedWidth = 90.0;
  static const double expandedWidth = 250.0;

  // Role-specific menu items
  static const Map<String, List<Map<String, String>>> _roleItems = {
    'CEO': [
      {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
      {'label': 'My Proposals', 'icon': 'assets/images/My_Proposals.png'},
      {'label': 'Analytics', 'icon': 'assets/images/analytics.png'},
      {'label': 'User Management', 'icon': 'assets/images/collaborations.png'},
      {'label': 'System Settings', 'icon': 'assets/images/content_library.png'},
      {'label': 'Govern', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
    ],
    'Financial Manager': [
      {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
      {'label': 'My Proposals', 'icon': 'assets/images/My_Proposals.png'},
      {'label': 'Templates', 'icon': 'assets/images/content_library.png'},
      {'label': 'Content Library', 'icon': 'assets/images/content_library.png'},
      {'label': 'Collaboration', 'icon': 'assets/images/collaborations.png'},
      {'label': 'Approvals Status', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
      {'label': 'Analytics', 'icon': 'assets/images/analytics.png'},
    ],
    'Reviewer': [
      {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
      {'label': 'Review Queue', 'icon': 'assets/images/My_Proposals.png'},
      {'label': 'Pending Reviews', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
      {'label': 'Quality Metrics', 'icon': 'assets/images/analytics.png'},
      {'label': 'Review History', 'icon': 'assets/images/content_library.png'},
    ],
    'Client': [
      {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
      {'label': 'My Proposals', 'icon': 'assets/images/My_Proposals.png'},
      {'label': 'Signed Documents', 'icon': 'assets/images/content_library.png'},
      {'label': 'Messages', 'icon': 'assets/images/collaborations.png'},
      {'label': 'Support', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
    ],
    'Approver': [
      {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
      {'label': 'Approvals', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
      {'label': 'Approval History', 'icon': 'assets/images/content_library.png'},
      {'label': 'Analytics', 'icon': 'assets/images/analytics.png'},
    ],
    'Admin': [
      {'label': 'Dashboard', 'icon': 'assets/images/Dahboard.png'},
      {'label': 'User Management', 'icon': 'assets/images/collaborations.png'},
      {'label': 'System Settings', 'icon': 'assets/images/content_library.png'},
      {'label': 'Analytics', 'icon': 'assets/images/analytics.png'},
      {'label': 'Govern', 'icon': 'assets/images/Time Allocation_Approval_Blue.png'},
    ],
  };

  List<Map<String, String>> get _items {
    final userRole = AuthService.currentUser?['role'] ?? 'CEO'; // Default to CEO for testing
    print('Current user role: $userRole'); // Debug print
    print('Available roles: ${_roleItems.keys}'); // Debug print
    final items = _roleItems[userRole] ?? _roleItems['CEO']!;
    print('Returning items for $userRole: ${items.map((e) => e['label']).toList()}'); // Debug print
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.isCollapsed) widget.onToggle();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: widget.isCollapsed ? collapsedWidth : expandedWidth,
        color: const Color(0xFF34495E),
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
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 8),
                          child: Icon(
                            widget.isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Role indicator
              if (!widget.isCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Role: ${AuthService.currentUser?['role'] ?? 'CEO'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

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
                    if (!widget.isCollapsed)
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
    final bool active = label == widget.currentLabel;
    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: InkWell(
          onTap: () => widget.onSelect(label),
          borderRadius: BorderRadius.circular(30),
          child: _buildCollapsedIcon(assetPath, active),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => widget.onSelect(label),
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

