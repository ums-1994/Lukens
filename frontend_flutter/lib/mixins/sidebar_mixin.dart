import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/fixed_sidebar.dart';

mixin SidebarMixin<T extends StatefulWidget> on State<T> {
  bool _isSidebarCollapsed = true;
  String _currentPage = '';

  // Get the current page name - override in each page
  String get currentPage;

  // Get custom assets for this page - override if needed
  Map<String, String>? get customAssets => null;

  @override
  void initState() {
    super.initState();
    _currentPage = currentPage;
  }

  void toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 'My Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/client_management');
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Logout':
        handleLogout(context);
        break;
    }
  }

  void handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final app = context.read<dynamic>();
                app.logout();
                AuthService.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget buildFixedSidebar(BuildContext context) {
    return FixedSidebar(
      currentPage: _currentPage,
      isCollapsed: _isSidebarCollapsed,
      onToggle: toggleSidebar,
      onNavigate: (label) => navigateToPage(context, label),
      onLogout: () => handleLogout(context),
      customAssets: customAssets,
    );
  }

  Widget buildWithSidebar(BuildContext context, Widget mainContent) {
    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            // Fixed Sidebar - Full Height
            buildFixedSidebar(context),

            // Main Content Area
            Expanded(
              child: mainContent,
            ),
          ],
        ),
      ),
    );
  }
}
