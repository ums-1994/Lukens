import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/collaboration_service.dart';
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/asset_service.dart';
import '../../widgets/role_switcher.dart';

class CollaborationPage extends StatefulWidget {
  const CollaborationPage({super.key});

  @override
  State<CollaborationPage> createState() => _CollaborationPageState();
}

class _CollaborationPageState extends State<CollaborationPage>
    with TickerProviderStateMixin {
  String _selectedTab = 'teams';
  bool _loading = false;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _workspaces = [];
  List<Map<String, dynamic>> _notifications = [];
  Stream<List<Map<String, dynamic>>>? _teamsStream;
  Stream<List<Map<String, dynamic>>>? _commentsStream;
  Stream<List<Map<String, dynamic>>>? _workspacesStream;
  Stream<List<Map<String, dynamic>>>? _notificationsStream;
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  String _currentPage = 'Collaboration';

  @override
  void initState() {
    super.initState();
    _ensureFirebaseUser();
    _refreshAll();
    _bindRealtime();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
      if (_isSidebarCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _ensureFirebaseUser() async {
    try {
      // Ensure we have a Firebase user for Firestore security rules
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
    });
    try {
      final results = await Future.wait([
        CollaborationService.listTeams(),
        CollaborationService.listComments(),
        CollaborationService.listWorkspaces(),
        CollaborationService.listNotifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _teams = results[0];
        _comments = results[1];
        _workspaces = results[2];
        _notifications = results[3];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _bindRealtime() {
    _teamsStream = CollaborationService.streamTeams();
    _commentsStream = CollaborationService.streamComments();
    _workspacesStream = CollaborationService.streamWorkspaces();
    _notificationsStream = CollaborationService.streamNotifications();

    _teamsStream!.listen((data) {
      if (!mounted) return;
      setState(() => _teams = data);
    });
    _commentsStream!.listen((data) {
      if (!mounted) return;
      setState(() => _comments = data);
    });
    _workspacesStream!.listen((data) {
      if (!mounted) return;
      setState(() => _workspaces = data);
    });
    _notificationsStream!.listen((data) {
      if (!mounted) return;
      setState(() => _notifications = data);
    });
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];
    return name ?? 'User';
  }

  void _handleLogout(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              if (app.currentUser != null) {
                app.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (app.currentUser != null) {
        app.logout();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _navigateToPage(BuildContext context, String label) {
    setState(() {
      _currentPage = label;
    });
    switch (label) {
      case 'Dashboard':
        Navigator.pushNamed(context, '/creator_dashboard');
        break;
      case 'My Proposals':
        Navigator.pushNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushNamed(context, '/proposal-wizard');
        break;
      case 'Content Library':
        Navigator.pushNamed(context, '/content_library');
        break;
      case 'Collaboration':
        // Already on Collaboration page
        break;
      case 'Approvals Status':
        Navigator.pushNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushNamed(context, '/analytics');
        break;
      case 'Logout':
        _handleLogout(context, context.read<AppState>());
        break;
    }
  }

  Widget _buildNavItem(String title, String imagePath, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: InkWell(
        onTap: () => _navigateToPage(context, title),
        borderRadius: BorderRadius.circular(30),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 50 : 200,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE9293A).withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE9293A).withValues(alpha: 0.7)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: _isSidebarCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  AssetService.buildImageWidget(imagePath,
                      width: 28, height: 28, fit: BoxFit.contain),
                  if (!_isSidebarCollapsed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final userRole = app.currentUser?['role'] ?? 'Financial Manager';

    final unreadCount = _notifications.where((n) => n['read'] != true).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Collaboration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const CompactRoleSwitcher(),
                      const SizedBox(width: 20),
                      ClipOval(
                        child: Image.asset(
                          'assets/images/User_Profile.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getUserName(app.currentUser),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userRole,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'logout') {
                            _handleLogout(context, app);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Content with Sidebar
          Expanded(
            child: Row(
              children: [
                // Collapsible Sidebar
                GestureDetector(
                  onTap: () {
                    if (_isSidebarCollapsed) _toggleSidebar();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isSidebarCollapsed ? 90.0 : 250.0,
                        color: Colors.black.withValues(alpha: 0.32),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              // Toggle button
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: InkWell(
                                  onTap: _toggleSidebar,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: _isSidebarCollapsed
                                          ? MainAxisAlignment.center
                                          : MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (!_isSidebarCollapsed)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              'Navigation',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  _isSidebarCollapsed ? 0 : 8),
                                          child: Icon(
                                            _isSidebarCollapsed
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
                              _buildNavItem(
                                  'Dashboard',
                                  'assets/images/Dashboard.png',
                                  _currentPage == 'Dashboard'),
                              _buildNavItem(
                                  'My Proposals',
                                  'assets/images/My_Proposals.png',
                                  _currentPage == 'My Proposals'),
                              _buildNavItem(
                                  'Templates',
                                  'assets/images/Templates.png',
                                  _currentPage == 'Templates'),
                              _buildNavItem(
                                  'Content Library',
                                  'assets/images/Content_Library.png',
                                  _currentPage == 'Content Library'),
                              _buildNavItem(
                                  'Collaboration',
                                  'assets/images/Collaboration.png',
                                  _currentPage == 'Collaboration'),
                              _buildNavItem(
                                  'Approvals Status',
                                  'assets/images/Approval_Status.png',
                                  _currentPage == 'Approvals Status'),
                              _buildNavItem(
                                  'Analytics (My Pipeline)',
                                  'assets/images/Analytics.png',
                                  _currentPage == 'Analytics (My Pipeline)'),
                              const SizedBox(height: 20),
                              // Divider
                              if (!_isSidebarCollapsed)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  height: 1,
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              const SizedBox(height: 12),
                              // Logout button
                              _buildNavItem(
                                  'Logout', 'assets/images/Logout.png', false),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE9293A)
                                    .withValues(alpha: 0.5),
                                width: 1),
                          ),
                          child: RefreshIndicator(
                            onRefresh: _refreshAll,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Collaboration',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Manage teams, comments, and shared workspaces',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final nameController =
                                              TextEditingController();
                                          final membersController =
                                              TextEditingController();
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Create Team'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                    controller: nameController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Team name'),
                                                  ),
                                                  TextField(
                                                    controller:
                                                        membersController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Members (emails, comma-separated)'),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child:
                                                        const Text('Cancel')),
                                                ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child:
                                                        const Text('Create')),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            final members = membersController
                                                .text
                                                .split(',')
                                                .map((s) => s.trim())
                                                .where((s) => s.isNotEmpty)
                                                .toList();
                                            await CollaborationService
                                                .createTeam(
                                                    name: nameController.text
                                                        .trim(),
                                                    members: members);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content:
                                                        Text('Team created')),
                                              );
                                              _refreshAll();
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.group_add,
                                            size: 16),
                                        label: const Text('Create Team'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF4a6cf7),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Tab Navigation
                                  Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE9293A)
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildTab(
                                            'teams', 'Teams', Icons.group),
                                        _buildTab('comments', 'Comments',
                                            Icons.chat_bubble_outline),
                                        _buildTab('shared', 'Shared Workspaces',
                                            Icons.folder_shared),
                                        _buildTab(
                                            'notifications',
                                            unreadCount > 0
                                                ? 'Notifications ($unreadCount)'
                                                : 'Notifications',
                                            Icons.notifications_outlined),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Tab Content
                                  if (_selectedTab == 'teams')
                                    _buildTeamsContent(),
                                  if (_selectedTab == 'comments')
                                    _buildCommentsContent(),
                                  if (_selectedTab == 'shared')
                                    _buildSharedContent(),
                                  if (_selectedTab == 'notifications')
                                    _buildNotificationsContent(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String label, IconData icon) {
    final isActive = _selectedTab == tabId;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE9293A).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isActive
                    ? const Color(0xFFE9293A).withValues(alpha: 0.7)
                    : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My Teams',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _refreshAll,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFE9293A)))),
                if (!_loading)
                  ..._teams.map((t) => _buildTeamItem(
                        t['name']?.toString() ?? 'Team',
                        '${(t['members'] as List?)?.length ?? 0} members',
                        Icons.group,
                        const Color(0xFF00CED1),
                      )),
                if (!_loading && _teams.isEmpty)
                  const Text('No teams yet. Create one to get started.',
                      style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsContent() {
    final controller = TextEditingController();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        await CollaborationService.addComment(text: text);
                        controller.clear();
                        _refreshAll();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00CED1),
                          foregroundColor: Colors.white),
                      child: const Text('Post'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFE9293A)))),
                if (!_loading)
                  ..._comments.map((c) => _buildCommentItem(
                        c['author']?.toString() ?? 'User',
                        c['text']?.toString() ?? '',
                        ((c['createdAt'] as Timestamp?)?.toDate().toString() ??
                            ''),
                      )),
                if (!_loading && _comments.isEmpty)
                  const Text('No comments yet.',
                      style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Shared Workspaces',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final controller = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('New Workspace'),
                            content: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                  labelText: 'Workspace name',
                                  labelStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7)),
                                  hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5)),
                                  filled: true,
                                  fillColor:
                                      Colors.black.withValues(alpha: 0.12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none)),
                              style: const TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00CED1),
                                      foregroundColor: Colors.white),
                                  child: const Text('Create')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await CollaborationService.createWorkspace(
                              name: controller.text.trim());
                          _refreshAll();
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('New',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFE9293A)))),
                if (!_loading)
                  ..._workspaces.map((w) => _buildWorkspaceItem(
                        w['name']?.toString() ?? 'Workspace',
                        '${w['files'] ?? 0} files',
                        Icons.folder,
                        const Color(0xFF00CED1),
                      )),
                if (!_loading && _workspaces.isEmpty)
                  const Text('No workspaces yet.',
                      style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await CollaborationService.clearAllNotifications();
                        _refreshAll();
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00CED1)),
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFE9293A)))),
                if (!_loading)
                  ..._notifications.map((n) => _buildNotificationItem(
                        n['message']?.toString() ?? '',
                        ((n['createdAt'] as Timestamp?)?.toDate().toString() ??
                            ''),
                        n['read'] == true
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        id: n['id']?.toString(),
                        read: n['read'] == true,
                      )),
                if (!_loading && _notifications.isEmpty)
                  const Text('No notifications.',
                      style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamItem(
      String name, String members, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFE9293A).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  members,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/team_details',
                  arguments: {'teamId': name});
            },
            icon: const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(String author, String comment, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFE9293A).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF00CED1),
            child: Text(
              author[0],
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceItem(
      String name, String files, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFE9293A).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  files,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/workspace',
                  arguments: {'workspaceName': name});
            },
            icon: const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String message, String time, IconData icon,
      {String? id, bool read = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFE9293A).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: const Color(0xFF00CED1).withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (id != null)
            IconButton(
              onPressed: () async {
                await CollaborationService.markNotificationRead(id,
                    read: !read);
                _refreshAll();
              },
              icon: Icon(read ? Icons.mark_email_read : Icons.mark_email_unread,
                  color: const Color(0xFF00CED1).withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}
