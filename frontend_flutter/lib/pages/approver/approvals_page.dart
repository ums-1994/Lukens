import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  List<dynamic> pendingProposals = [];
  bool isLoading = true;

  final ScrollController _scrollController = ScrollController();
  String _currentPage = 'Approvals Status';
  bool _isSidebarCollapsed = true;

  static const Color _navSurface = Color(0xFF1A1F2B);
  static const Color _navBorder = Color(0xFF1F2A3D);

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingApprovals() async {
    final app = context.read<AppState>();
    final userRole = app.currentUser?['role'] ?? '';

    if (userRole == 'CEO') {
      final proposals = await app.getPendingApprovals();
      setState(() {
        pendingProposals = proposals;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final userRole = app.currentUser?['role'] ?? '';

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: _buildHeader(app, userRole),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(context),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: _buildContentArea(userRole),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: const Footer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppState app, String userRole) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      gradientStart: const Color(0xFF0F172A),
      gradientEnd: const Color(0xFF1E293B),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending CEO Approvals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review and sign off proposals awaiting executive approval',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ClipOval(
            child: Image.asset(
              'assets/images/User_Profile.png',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getUserName(app.currentUser),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                userRole,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context);
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
    );
  }

  Widget _buildContentArea(String userRole) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: userRole == 'CEO'
            ? _buildCEOContent()
            : _buildLegacyApprovalContent(),
      ),
    );
  }

  Widget _buildCEOContent() {
    if (pendingProposals.isEmpty) {
      return const Center(
        child: Text(
          'No proposals pending approval',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      );
    }

    return CustomScrollbar(
      controller: _scrollController,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: pendingProposals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final proposal = pendingProposals[index];
          return _buildProposalCard(proposal);
        },
      ),
    );
  }

  Widget _buildLegacyApprovalContent() {
    final app = context.watch<AppState>();
    final proposal = app.currentProposal;

    if (proposal == null) {
      return const Center(
        child: Text(
          "Select a proposal to manage approvals.",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final status = proposal["status"];
    final approvals =
        Map<String, dynamic>.from(proposal["approval"]["approvals"] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Status: $status",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _stageChip(context, "Delivery", approvals["Delivery"] != null),
            _stageChip(context, "Legal", approvals["Legal"] != null),
            _stageChip(context, "Exec", approvals["Exec"] != null),
          ],
        ),
        const Spacer(),
        if (status == "Released" || status == "Sent to Client") SignPanel(),
      ],
    );
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal['title'] ?? 'Untitled',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Client: ${proposal['client'] ?? 'N/A'}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PremiumTheme.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              proposal['status'] ?? 'Pending',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                label: const Text('Reject'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                onPressed: () => _showRejectDialog(proposal['id']),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showApproveDialog(proposal['id']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isSidebarCollapsed) _toggleSidebar();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isSidebarCollapsed ? 90.0 : 250.0,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.35),
              Colors.black.withOpacity(0.2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: InkWell(
                  onTap: _toggleSidebar,
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
                      mainAxisAlignment: _isSidebarCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isSidebarCollapsed)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Navigation',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: _isSidebarCollapsed ? 0 : 8),
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
              const SizedBox(height: 16),
              _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                  _currentPage == 'Dashboard', context),
              _buildNavItem('My Proposals', 'assets/images/My_Proposals.png',
                  _currentPage == 'My Proposals', context),
              _buildNavItem('Templates', 'assets/images/content_library.png',
                  _currentPage == 'Templates', context),
              _buildNavItem(
                  'Content Library',
                  'assets/images/content_library.png',
                  _currentPage == 'Content Library',
                  context),
              _buildNavItem(
                  'Client Management',
                  'assets/images/collaborations.png',
                  _currentPage == 'Client Management',
                  context),
              _buildNavItem(
                  'Approvals Status',
                  'assets/images/Time Allocation_Approval_Blue.png',
                  _currentPage == 'Approvals Status',
                  context),
              _buildNavItem(
                  'Analytics (My Pipeline)',
                  'assets/images/analytics.png',
                  _currentPage == 'Analytics (My Pipeline)',
                  context),
              const SizedBox(height: 20),
              if (!_isSidebarCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: PremiumTheme.glassWhiteBorder.withValues(alpha: 0.6),
                ),
              const SizedBox(height: 12),
              _buildNavItem('Logout', 'assets/images/Logout_KhonoBuzz.png',
                  false, context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      String label, String assetPath, bool isActive, BuildContext context) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() => _currentPage = label);
              _navigateToPage(context, label);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isActive
                    ? PremiumTheme.purple.withValues(alpha: 0.3)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? PremiumTheme.purple
                      : PremiumTheme.glassWhiteBorder,
                  width: isActive ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: AssetService.buildImageWidget(assetPath,
                    fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? PremiumTheme.purple.withValues(alpha: 0.25)
                : _navSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? PremiumTheme.purple
                  : _navBorder.withValues(alpha: 0.7),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? PremiumTheme.purple.withValues(alpha: 0.3)
                      : _navSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? PremiumTheme.purple
                        : _navBorder.withValues(alpha: 0.6),
                    width: isActive ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath,
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isActive)
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSidebar() {
    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/home');
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
        Navigator.pushReplacementNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
        // Already on this page
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Logout':
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    final app = context.read<AppState>();
    app.logout();
    AuthService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) {
      return 'Guest';
    }

    final dynamic fullName =
        user['full_name'] ?? user['fullName'] ?? user['name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    final String first =
        (user['first_name'] ?? user['firstName'] ?? '').toString().trim();
    final String last =
        (user['last_name'] ?? user['lastName'] ?? '').toString().trim();
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }

    final email = user['email'];
    if (email is String && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'User';
  }

  void _showApproveDialog(String proposalId) {
    final commentsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Proposal'),
        content: TextField(
          controller: commentsCtrl,
          decoration: const InputDecoration(
            labelText: 'Comments (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final app = context.read<AppState>();
              final error = await app.approveProposal(proposalId,
                  comments: commentsCtrl.text);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Proposal approved!'),
                      backgroundColor: Colors.green),
                );
                _loadPendingApprovals();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71)),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String proposalId) {
    final commentsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: TextField(
          controller: commentsCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final app = context.read<AppState>();
              final error = await app.rejectProposal(proposalId,
                  comments: commentsCtrl.text);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Proposal rejected'),
                      backgroundColor: Colors.orange),
                );
                _loadPendingApprovals();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _stageChip(BuildContext context, String stage, bool approved) {
    final app = context.read<AppState>();
    return InputChip(
      label: Text("$stage ${approved ? "✓" : ""}"),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: approved
          ? PremiumTheme.teal.withValues(alpha: 0.2)
          : Colors.white.withOpacity(0.05),
      side: BorderSide(
        color: approved ? PremiumTheme.teal : Colors.white.withOpacity(0.2),
      ),
      onPressed: approved
          ? null
          : () async {
              await app.approveStage(stage);
            },
    );
  }
}

class SignPanel extends StatefulWidget {
  @override
  State<SignPanel> createState() => _SignPanelState();
}

class _SignPanelState extends State<SignPanel> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Signer Name (Client)",
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: PremiumTheme.purple.withValues(alpha: 0.8),
              ),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.draw_outlined),
          label: const Text("Client Sign-Off"),
          style: ElevatedButton.styleFrom(
            backgroundColor: PremiumTheme.purple,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final err = await app.signOff(ctrl.text);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err ?? "Signed successfully"),
              duration: const Duration(seconds: 3),
            ));
          },
        ),
      ],
    );
  }
}
