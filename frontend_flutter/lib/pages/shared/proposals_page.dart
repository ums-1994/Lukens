import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../theme/premium_theme.dart';
import '../../theme/manager_theme_controller.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/manager_page_background.dart';
import '../../utils/manager_session_actions.dart';

class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  _ProposalsPageState createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage>
    with TickerProviderStateMixin {
  String _filterStatus = 'All Statuses';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> proposals = [];
  bool _isLoading = true;
  String? _token;
  bool _isSidebarCollapsed = false;
  String _currentNavLabel = 'Proposals';

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 'My Proposals':
      case 'Proposals':
        // Already on proposals page
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
      case 'Account Profile':
        break;
      case 'Logout':
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    ManagerSessionActions.showLogoutDialog(context);
  }

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (appState.proposals.isNotEmpty) {
        setState(() {
          proposals = List<Map<String, dynamic>>.from(appState.proposals
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p)));
          _isLoading = false;
        });
      }
      _loadProposals(showLoader: appState.proposals.isEmpty);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProposals({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      // Get token from AuthService (backend JWT) - same as document editor
      final token = AuthService.token;

      // Fallback to AppState if token not in AuthService
      if (token == null || token.isEmpty) {
        if (mounted) {
          final appState = context.read<AppState>();
          _token = appState.authToken;
        }
      } else {
        _token = token;
      }

      if (_token != null && _token!.isNotEmpty) {
        print('Γ£à Loading proposals with token...');
        final data = await ApiService.getProposals(_token!);
        if (mounted) {
          setState(() {
            proposals = List<Map<String, dynamic>>.from(data);
            print('Γ£à Loaded ${proposals.length} proposals');
            _isLoading = false;
          });
        }
      } else {
        print('ΓÜá∩╕Å No authentication token found');
        if (mounted) {
          setState(() {
            proposals = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Γ¥î Error loading proposals: $e');
      if (mounted && showLoader) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateNewDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(height: 24),
              // Start from scratch option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    _navigateToBlankProposal();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3498DB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF3498DB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Start from scratch',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create a blank proposal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF718096)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Choose from template gallery option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/proposal-wizard')
                        .then((_) => _loadProposals());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2ECC71).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.library_books_outlined,
                            color: Color(0xFF2ECC71),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Choose from Template Gallery',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Select a template to get started',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF718096)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToBlankProposal() async {
    try {
      // Navigate directly to blank document editor
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/blank-document',
          arguments: {
            'proposalId': 'temp-${DateTime.now().millisecondsSinceEpoch}',
            'proposalTitle': 'Untitled Document',
          },
        ).then((_) => _loadProposals());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening blank document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final userRole = app.currentUser?['role'] ?? 'Financial Manager';

    final filtered = proposals.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final matchesSearch =
          title.contains(_searchController.text.toLowerCase()) ||
              client.contains(_searchController.text.toLowerCase());
      final matchesStatus = _filterStatus == 'All Statuses' ||
          (p['status'] ?? '') == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ManagerPageBackground(
          child: Row(
            children: [
              // Consistent Sidebar using AppSideNav
              Consumer<AppState>(
                builder: (context, app, child) {
                  final role = (app.currentUser?['role'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  final isAdmin = role == 'admin' || role == 'ceo';
                  return AppSideNav(
                    isCollapsed: _isSidebarCollapsed,
                    currentLabel: _currentNavLabel,
                    onSelect: (label) {
                      setState(() => _currentNavLabel = label);
                      _navigateToPage(context, label);
                    },
                    onToggle: () => setState(
                      () => _isSidebarCollapsed = !_isSidebarCollapsed,
                    ),
                    isAdmin: isAdmin,
                  );
                },
              ),

              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: _buildHeader(context, app, userRole, chrome),
                    ),

                    // Content Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildToolbar(chrome),
                            const SizedBox(height: 24),
                            Expanded(
                              child: CustomScrollbar(
                                controller: _scrollController,
                                thumbColor: chrome.scrollbarThumb,
                                trackColor: chrome.scrollbarTrack,
                                trackBorderColor: chrome.divider,
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _buildFilterPanel(filtered, chrome),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState app, String userRole,
      ManagerChromeTheme chrome) {
    return Container(
      decoration: chrome.floatingPanelDecoration(radius: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proposals',
                style: TextStyle(
                  color: chrome.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your business proposals and approvals',
                style: TextStyle(color: chrome.textSecondary, fontSize: 13),
              ),
            ],
          );

          // Ensure the header never overflows when the sidebar expands/collapses.
          final maxNameWidth = (constraints.maxWidth - 56 - 12 - 40 - 24)
              .clamp(140.0, isNarrow ? double.infinity : 240.0);

          final userBlock = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/User_Profile.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxNameWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getUserName(app.currentUser),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chrome.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      userRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: chrome.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: chrome.textSecondary),
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
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                userBlock,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              userBlock,
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar(ManagerChromeTheme chrome) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Proposals',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: chrome.textPrimary)),
              const SizedBox(height: 6),
              Text('Manage all your business proposals and SOWs',
                  style: TextStyle(color: chrome.textSecondary)),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: chrome.textPrimary),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search proposals...',
                filled: true,
                fillColor: chrome.fieldFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: chrome.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: chrome.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: PremiumTheme.purple.withValues(alpha: 0.8),
                  ),
                ),
                prefixIconColor: chrome.textSecondary,
                hintStyle: TextStyle(
                  color: chrome.textMuted,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: _showCreateNewDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(
      List<Map<String, dynamic>> filtered, ManagerChromeTheme chrome) {
    return Container(
      decoration: chrome.floatingPanelDecoration(radius: 10),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Proposals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: chrome.textPrimary,
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: chrome.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search proposals...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                        ),
                        hintStyle: TextStyle(color: chrome.textMuted),
                        filled: true,
                        fillColor: chrome.fieldFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: chrome.fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: chrome.fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: PremiumTheme.purple.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: chrome.fieldFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: chrome.fieldBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        dropdownColor: chrome.dropdownSurface,
                        iconEnabledColor: chrome.textSecondary,
                        style: TextStyle(
                            color: chrome.textPrimary, fontSize: 14),
                        items: [
                          'All Statuses',
                          'Draft',
                          'Sent',
                          'Approved',
                          'Declined'
                        ]
                            .map((String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (String? newValue) => setState(
                            () => _filterStatus = newValue ?? 'All Statuses'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(PremiumTheme.purple),
                ),
              ),
            )
          else if (proposals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64, color: chrome.textMuted),
                    const SizedBox(height: 16),
                    Text('No proposals yet',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: chrome.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Create your first proposal to get started',
                        style: TextStyle(color: chrome.textSecondary)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showCreateNewDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Your First Proposal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumTheme.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: chrome.divider),
              itemBuilder: (context, index) {
                final proposal = filtered[index];
                return ProposalItem(
                    proposal: proposal,
                    onRefresh: _loadProposals,
                    chrome: chrome);
              },
            ),
        ],
      ),
    );
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';

    // Try different possible field names for the user's name
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];

    return name ?? 'User';
  }
}

class ProposalItem extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback? onRefresh;
  final ManagerChromeTheme chrome;

  const ProposalItem({
    Key? key,
    required this.proposal,
    this.onRefresh,
    required this.chrome,
  }) : super(key: key);

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is String) {
      try {
        final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(date);
        final parsedRaw = DateTime.parse(date);
        final parsed = hasTimezone
            ? parsedRaw.toLocal()
            : DateTime.utc(
                parsedRaw.year,
                parsedRaw.month,
                parsedRaw.day,
                parsedRaw.hour,
                parsedRaw.minute,
                parsedRaw.second,
                parsedRaw.millisecond,
                parsedRaw.microsecond,
              ).toLocal();
        final now = DateTime.now();

        bool isSameDay(DateTime a, DateTime b) {
          return a.year == b.year && a.month == b.month && a.day == b.day;
        }

        final today = DateTime(now.year, now.month, now.day);
        final parsedDay = DateTime(parsed.year, parsed.month, parsed.day);

        if (isSameDay(parsedDay, today)) {
          return 'Today, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }

        final yesterday = today.subtract(const Duration(days: 1));
        if (isSameDay(parsedDay, yesterday)) {
          return 'Yesterday, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }

        return '${parsed.day}/${parsed.month}/${parsed.year}';
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    final status = (proposal['status'] ?? '').toString().toLowerCase().trim();
    final editableStatuses = {
      'draft',
      'changes requested',
      'resubmitted',
    };
    final isEditable = editableStatuses.contains(status);
    Color statusColor;
    switch (status) {
      case 'draft':
        statusColor = PremiumTheme.purple;
        break;
      case 'pending':
      case 'pending approval':
      case 'pending ceo approval':
        statusColor = PremiumTheme.orange;
        break;
      case 'sent':
      case 'sent to client':
        statusColor = PremiumTheme.pink;
        break;
      case 'approved':
        statusColor = PremiumTheme.teal;
        break;
      case 'declined':
      case 'rejected':
        statusColor = PremiumTheme.error;
        break;
      default:
        statusColor = chrome.textMuted;
    }

    const knownStatuses = {
      'draft',
      'pending',
      'pending approval',
      'pending ceo approval',
      'sent',
      'sent to client',
      'approved',
      'declined',
      'rejected',
    };
    final isNeutralStatus = !knownStatuses.contains(status);

    final Color statusBgColor = isNeutralStatus
        ? chrome.fieldFill
        : statusColor.withValues(alpha: chrome.isDark ? 0.2 : 0.18);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(proposal['title'] ?? 'Untitled Proposal',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: chrome.textPrimary)),
              const SizedBox(height: 8),
              Wrap(spacing: 16, children: [
                Text(
                    'Last modified: ${_formatDate(proposal['updated_at'] ?? proposal['updatedAt'])}',
                    style:
                        TextStyle(fontSize: 13, color: chrome.textSecondary)),
                if (proposal['client_name'] != null ||
                    proposal['client'] != null)
                  Text(
                      'Client: ${proposal['client_name'] ?? proposal['client']}',
                      style:
                          TextStyle(fontSize: 13, color: chrome.textSecondary)),
              ])
            ]),
          ),
          Row(children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(proposal['status'] ?? 'Unknown',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isNeutralStatus
                            ? chrome.textPrimary
                            : statusColor))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (isEditable) {
                  Navigator.pushNamed(context, '/compose', arguments: proposal)
                      .then((_) {
                    if (onRefresh != null) onRefresh!();
                  });
                } else {
                  // Ensure preview page knows which proposal to show
                  try {
                    context
                        .read<AppState>()
                        .selectProposal(Map<String, dynamic>.from(proposal));
                  } catch (_) {}
                  Navigator.pushNamed(context, '/preview', arguments: proposal)
                      .then((_) {
                    if (onRefresh != null) onRefresh!();
                  });
                }
              },
              child: Text(isEditable ? 'Edit' : 'View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
                icon: Icon(Icons.delete_outline, color: chrome.textSecondary),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                              title: const Text('Delete proposal?'),
                              content: const Text(
                                  'Are you sure you want to delete this proposal?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'))
                              ]));
                  if (confirm == true) {
                    // Use AuthService token (same as document editor)
                    final token = AuthService.token;
                    if (token != null && token.isNotEmpty) {
                      final idVal = proposal['id'];
                      final intId = idVal is int
                          ? idVal
                          : int.tryParse(idVal.toString()) ?? 0;
                      if (intId != 0) {
                        final success = await ApiService.deleteProposal(
                            token: token, id: intId);

                        if (success) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Proposal deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          if (onRefresh != null) onRefresh!();
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to delete proposal. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid proposal ID'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Authentication required. Please log in.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                })
          ])
        ],
      ),
    );
  }
}
