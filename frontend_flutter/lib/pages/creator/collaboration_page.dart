import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/collaboration_service.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';

class CollaborationPage extends StatefulWidget {
  const CollaborationPage({super.key});

  @override
  State<CollaborationPage> createState() => _CollaborationPageState();
}

class _CollaborationPageState extends State<CollaborationPage> {
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
  late final List<Stream<List<Map<String, dynamic>>>?> _allStreams;

  @override
  void initState() {
    super.initState();
    _ensureFirebaseUser();
    _refreshAll();
    _bindRealtime();
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
        _teams = results[0] as List<Map<String, dynamic>>;
        _comments = results[1] as List<Map<String, dynamic>>;
        _workspaces = results[2] as List<Map<String, dynamic>>;
        _notifications = results[3] as List<Map<String, dynamic>>;
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

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final displayName =
        (user != null ? (user['full_name'] ?? user['email'] ?? 'User') : 'User')
            .toString();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final unreadCount = _notifications.where((n) => n['read'] != true).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
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
                    'Proposal & SOW Builder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3498DB),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(displayName,
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) async {
                          if (value == 'logout') {
                            AuthService.logout();
                            await FirebaseService.signOut();
                            if (mounted) {
                              Navigator.pushNamed(context, '/login');
                            }
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

          // Main Content
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Title
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF34495E), width: 1),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Color(0xFF3498DB),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Business Developer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem('📊', 'Dashboard', false, context),
                        _buildNavItem('📝', 'My Proposals', false, context),
                        _buildNavItem('📂', 'Templates', false, context),
                        _buildNavItem('🧩', 'Content Library', false, context),
                        _buildNavItem('👥', 'Collaboration', true, context),
                        _buildNavItem('📋', 'Approvals Status', false, context),
                        _buildNavItem(
                            '🔍', 'Analytics (My Pipeline)', false, context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Collaboration',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Manage teams, comments, and shared workspaces',
                                      style: TextStyle(
                                        color: Color(0xFF718096),
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
                                              decoration: const InputDecoration(
                                                  labelText: 'Team name'),
                                            ),
                                            TextField(
                                              controller: membersController,
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      'Members (emails, comma-separated)'),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Create')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      final members = membersController.text
                                          .split(',')
                                          .map((s) => s.trim())
                                          .where((s) => s.isNotEmpty)
                                          .toList();
                                      await CollaborationService.createTeam(
                                          name: nameController.text.trim(),
                                          members: members);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Team created')),
                                        );
                                        _refreshAll();
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.group_add, size: 16),
                                  label: const Text('Create Team'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4a6cf7),
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  _buildTab('teams', 'Teams', Icons.group),
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
                            if (_selectedTab == 'teams') _buildTeamsContent(),
                            if (_selectedTab == 'comments')
                              _buildCommentsContent(),
                            if (_selectedTab == 'shared') _buildSharedContent(),
                            if (_selectedTab == 'notifications')
                              _buildNotificationsContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            height: 50,
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: Color(0xFFDDD), style: BorderStyle.solid)),
            ),
            child: const Center(
              child: Text(
                'Khonology Proposal & SOW Builder | End-to-End Proposal Generation and Sign-Off',
                style: TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      String icon, String label, bool isActive, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: const Color(0xFF2980B9), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _navigateToPage(context, label);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: _navIconFor(label, isActive),
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
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : const Color(0xFF718096),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF718096),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIconFor(String label, bool isActive) {
    String path;
    switch (label) {
      case 'Dashboard':
        path = 'assets/images/Dahboard.png';
        break;
      case 'My Proposals':
        path = 'assets/images/My_Proposals.png';
        break;
      case 'Templates':
      case 'Content Library':
        path = 'assets/images/content_library.png';
        break;
      case 'Collaboration':
        path = 'assets/images/collaborations.png';
        break;
      case 'Approvals Status':
      case 'Analytics (My Pipeline)':
        path = 'assets/images/analytics.png';
        break;
      default:
        path = 'assets/images/Dahboard.png';
    }
    return Image.asset(path, fit: BoxFit.contain);
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushNamed(context, '/creator_dashboard');
        break;
      case 'My Proposals':
        Navigator.pushNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushNamed(context, '/content_library');
        break;
      case 'Collaboration':
        // Already on collaboration page
        break;
      case 'Approvals Status':
        Navigator.pushNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushNamed(context, '/analytics');
        break;
      default:
        Navigator.pushNamed(context, '/creator_dashboard');
    }
  }

  Widget _buildTeamsContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Teams',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshAll,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._teams.map((t) => _buildTeamItem(
                    t['name']?.toString() ?? 'Team',
                    '${(t['members'] as List?)?.length ?? 0} members',
                    Icons.group,
                    const Color(0xFF3498DB),
                  )),
            if (!_loading && _teams.isEmpty)
              const Text('No teams yet. Create one to get started.'),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsContent() {
    final controller = TextEditingController();
    return Card(
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
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(hintText: 'Add a comment...'),
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
                  child: const Text('Post'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._comments.map((c) => _buildCommentItem(
                    c['author']?.toString() ?? 'User',
                    c['text']?.toString() ?? '',
                    ((c['createdAt'] as Timestamp?)?.toDate().toString() ?? ''),
                  )),
            if (!_loading && _comments.isEmpty) const Text('No comments yet.'),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Shared Workspaces',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
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
                          decoration: const InputDecoration(
                              labelText: 'Workspace name'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
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
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._workspaces.map((w) => _buildWorkspaceItem(
                    w['name']?.toString() ?? 'Workspace',
                    '${w['files'] ?? 0} files',
                    Icons.folder,
                    const Color(0xFF3498DB),
                  )),
            if (!_loading && _workspaces.isEmpty)
              const Text('No workspaces yet.'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await CollaborationService.clearAllNotifications();
                    _refreshAll();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._notifications.map((n) => _buildNotificationItem(
                    n['message']?.toString() ?? '',
                    ((n['createdAt'] as Timestamp?)?.toDate().toString() ?? ''),
                    n['read'] == true
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    id: n['id']?.toString(),
                    read: n['read'] == true,
                  )),
            if (!_loading && _notifications.isEmpty)
              const Text('No notifications.'),
          ],
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
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
                  ),
                ),
                Text(
                  members,
                  style: const TextStyle(
                    color: Color(0xFF718096),
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
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF3498DB),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF718096),
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
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
                  ),
                ),
                Text(
                  files,
                  style: const TextStyle(
                    color: Color(0xFF718096),
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
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3498DB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF718096),
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
              icon:
                  Icon(read ? Icons.mark_email_read : Icons.mark_email_unread),
            ),
        ],
      ),
    );
  }
}

/*
  Widget _buildCommentsContent() {

    final controller = TextEditingController();
    return Card(

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

                color: Color(0xFF2C3E50),

              ),

            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Add a comment...'),
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
                  child: const Text('Post'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._comments.map((c) => _buildCommentItem(
                    c['author']?.toString() ?? 'User',
                    c['text']?.toString() ?? '',
                    ((c['createdAt'] as Timestamp?)?.toDate().toString() ?? ''),
                  )),
            if (!_loading && _comments.isEmpty)
              const Text('No comments yet.'),
          ],

        ),

      ),

    );

  }



  Widget _buildSharedContent() {

    return Card(

      child: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(
              children: [
                const Expanded(
                  child: Text(
              'Shared Workspaces',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.w600,

                color: Color(0xFF2C3E50),

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
                          decoration: const InputDecoration(labelText: 'Workspace name'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Create')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await CollaborationService.createWorkspace(name: controller.text.trim());
                      _refreshAll();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._workspaces.map((w) => _buildWorkspaceItem(
                    w['name']?.toString() ?? 'Workspace',
                    '${w['files'] ?? 0} files',
                    Icons.folder,
                    const Color(0xFF3498DB),
                  )),
            if (!_loading && _workspaces.isEmpty)
              const Text('No workspaces yet.'),
          ],

        ),

      ),

    );

  }



  Widget _buildNotificationsContent() {

    return Card(

      child: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(
              children: [
                const Expanded(
                  child: Text(
              'Notifications',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.w600,

                color: Color(0xFF2C3E50),

              ),

                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await CollaborationService.clearAllNotifications();
                    _refreshAll();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              ..._notifications.map((n) => _buildNotificationItem(
                    n['message']?.toString() ?? '',
                    ((n['createdAt'] as Timestamp?)?.toDate().toString() ?? ''),
                    n['read'] == true ? Icons.notifications_none : Icons.notifications_active,
                    id: n['id']?.toString(),
                    read: n['read'] == true,
                  )),
            if (!_loading && _notifications.isEmpty)
              const Text('No notifications.'),
          ],

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

        color: const Color(0xFFF8F9FA),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: const Color(0xFFE2E8F0)),

      ),

      child: Row(

        children: [

          Container(

            width: 40,

            height: 40,

            decoration: BoxDecoration(

              color: color.withValues(alpha: 0.1),

              borderRadius: BorderRadius.circular(8),

            ),

            child: Icon(icon, color: color, size: 20),

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

                  ),

                ),

                Text(

                  members,

                  style: const TextStyle(

                    color: Color(0xFF718096),

                    fontSize: 12,

                  ),

                ),

              ],

            ),

          ),

          IconButton(

            onPressed: () {

              Navigator.pushNamed(context, '/team_details', arguments: {'teamId': name});
            },

            icon: const Icon(Icons.arrow_forward_ios, size: 16),

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

        color: const Color(0xFFF8F9FA),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: const Color(0xFFE2E8F0)),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          CircleAvatar(

            radius: 16,

            backgroundColor: const Color(0xFF3498DB),

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

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  comment,

                  style: const TextStyle(

                    color: Color(0xFF2C3E50),

                    fontSize: 14,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  time,

                  style: const TextStyle(

                    color: Color(0xFF718096),

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

        color: const Color(0xFFF8F9FA),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: const Color(0xFFE2E8F0)),

      ),

      child: Row(

        children: [

          Icon(icon, color: color, size: 24),

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

                  ),

                ),

                Text(

                  files,

                  style: const TextStyle(

                    color: Color(0xFF718096),

                    fontSize: 12,

                  ),

                ),

              ],

            ),

          ),

          IconButton(

            onPressed: () {

              Navigator.pushNamed(context, '/workspace', arguments: {'workspaceName': name});
            },

            icon: const Icon(Icons.arrow_forward_ios, size: 16),

          ),

        ],

      ),

    );

  }



  Widget _buildNotificationItem(String message, String time, IconData icon, {String? id, bool read = false}) {
    return Container(

      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: const Color(0xFFF8F9FA),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: const Color(0xFFE2E8F0)),

      ),

      child: Row(

        children: [

          Icon(icon, color: const Color(0xFF3498DB), size: 20),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  message,

                  style: const TextStyle(

                    fontSize: 14,

                    color: Color(0xFF2C3E50),

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  time,

                  style: const TextStyle(

                    color: Color(0xFF718096),

                    fontSize: 12,

                  ),

                ),

              ],

            ),

          ),

          if (id != null)
            IconButton(
              onPressed: () async {
                await CollaborationService.markNotificationRead(id, read: !read);
                _refreshAll();
              },
              icon: Icon(read ? Icons.mark_email_read : Icons.mark_email_unread),
          ),
        ],

      ),

    );

  }

}


*/
