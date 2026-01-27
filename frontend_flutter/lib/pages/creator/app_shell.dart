import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import 'content_library_page.dart';
import 'creator_dashboard_page.dart';
import 'settings_page.dart';
import 'templates_page.dart';

class AppShell extends StatefulWidget {
  final String initialPage;

  const AppShell({super.key, this.initialPage = 'Dashboard'});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late String _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: Row(
        children: [
          // Modern Navigation Sidebar
          _buildSidebar(),
          // Content Area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        border: Border(right: BorderSide(color: Colors.grey[900]!)),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00CED1),
                    const Color(0xFF20B2AA),
                  ],
                ),
              ),
              child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
            ),
          ),
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: _currentPage == 'Dashboard',
                    onTap: () => setState(() => _currentPage = 'Dashboard'),
                  ),
                  _buildNavItem(
                    icon: Icons.collections,
                    label: 'Content Library',
                    isActive: _currentPage == 'Content Library',
                    onTap: () =>
                        setState(() => _currentPage = 'Content Library'),
                  ),
                  _buildNavItem(
                    icon: Icons.description_outlined,
                    label: 'Templates',
                    isActive: _currentPage == 'Templates',
                    onTap: () => setState(() => _currentPage = 'Templates'),
                  ),
                  _buildNavItem(
                    icon: Icons.people_outline,
                    label: 'Team',
                    isActive: _currentPage == 'Team',
                    onTap: () => setState(() => _currentPage = 'Team'),
                  ),
                  _buildNavItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Analytics',
                    isActive: _currentPage == 'Analytics',
                    onTap: () => setState(() => _currentPage = 'Analytics'),
                  ),
                  _buildNavItem(
                    icon: Icons.trending_up_outlined,
                    label: 'Insights',
                    isActive: _currentPage == 'Insights',
                    onTap: () => setState(() => _currentPage = 'Insights'),
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isActive: _currentPage == 'Settings',
                    onTap: () => setState(() => _currentPage = 'Settings'),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Section
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                _buildNavItem(
                  icon: Icons.help_outline,
                  label: 'Help',
                  isActive: false,
                  onTap: () {},
                ),
                _buildNavItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  isActive: false,
                  onTap: () {
                    final app = context.read<AppState>();
                    app.logout();
                    Navigator.pushNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: const Color(0xFF00CED1), width: 2)
                : null,
          ),
          child: Tooltip(
            message: label,
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isActive ? const Color(0xFF00CED1) : Colors.grey[600],
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  label.split(' ')[0],
                  style: TextStyle(
                    fontSize: 9,
                    color:
                        isActive ? const Color(0xFF00CED1) : Colors.grey[600],
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentPage) {
      case 'Dashboard':
        return const DashboardPage();
      case 'Content Library':
        return const ContentLibraryPage();
      case 'Settings':
        return const SettingsPage();
      case 'Templates':
        return const TemplatesPage();
      case 'Team':
        return _buildPlaceholder('Team', Icons.people);
      case 'Analytics':
        return _buildPlaceholder('Analytics', Icons.bar_chart);
      case 'Insights':
        return _buildPlaceholder('Insights', Icons.trending_up);
      default:
        return _buildPlaceholder(_currentPage, Icons.dashboard);
    }
  }

  Widget _buildPlaceholder(String title, IconData icon) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              '$title is coming soon',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This feature is under development',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
