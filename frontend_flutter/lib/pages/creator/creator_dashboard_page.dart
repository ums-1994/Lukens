// ignore_for_file: unused_field, unused_element, unused_local_variable, deprecated_member_use

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../widgets/footer.dart';
import '../../widgets/custom_scrollbar.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/manager_theme_controller.dart';
import '../shared/proposal_insights_modal.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/manager_page_background.dart';
import '../../utils/manager_session_actions.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _isSidebarCollapsed = false;
  String _currentNavLabel = 'Dashboard';
  late AnimationController _animationController;
  String _currentPage = 'Dashboard';
  bool _isRefreshing = false;
  String _statusFilter = 'all'; // all, draft, published, pending, approved
  final ScrollController _scrollController = ScrollController();

  // AI Risk Gate mock data
  List<Map<String, dynamic>> _riskItems = [];

  /// Proposal checkboxes (Recent Proposals list)
  final Set<String> _selectedRecentProposalIds = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Start collapsed
    _animationController.value = 1.0;

    // Refresh data when dashboard loads (after AppState is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure AppState has the token before refreshing
      final app = context.read<AppState>();
      app.setCurrentNavLabel('Dashboard');
      if (app.authToken == null && AuthService.token != null) {
        print('Syncing token to AppState...');
        app.authToken = AuthService.token;
        app.currentUser = AuthService.currentUser;
      }
      await _refreshData();
      await _loadRiskData(app);
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final app = context.read<AppState>();

      // Double-check auth token is synced
      if (app.authToken == null && AuthService.token != null) {
        app.authToken = AuthService.token;
        app.currentUser = AuthService.currentUser;
        final t = AuthService.token ?? '';
        final preview = t.length > 20 ? t.substring(0, 20) : t;
        print('Synced token from AuthService: $preview...');
      }

      if (app.authToken == null) {
        print('No auth token available - cannot fetch data');
        return;
      }

      await Future.wait([
        app.fetchProposals(),
        app.fetchDashboard(),
        app.fetchNotifications(),
      ]);
      print(
          'Dashboard data refreshed - ${app.proposals.length} proposals loaded');

      // Reload risk data after refreshing proposals
      await _loadRiskData(app);
    } catch (e) {
      print('Error refreshing dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _loadRiskData(AppState app) async {
    if (app.authToken == null) return;

    final List<Map<String, dynamic>> risks = [];

    try {
      // Fetch risks for proposals that need review (draft or pending approval)
      final proposalsNeedingReview = app.proposals.where((proposal) {
        final status = (proposal['status'] ?? '').toString().toLowerCase();
        return status == 'draft' ||
            status == 'pending ceo approval' ||
            status == 'pending approval' ||
            status == 'in review' ||
            status == 'submitted';
      }).toList();

      // Analyze risks for each proposal using the AI risk analysis API
      for (var proposal in proposalsNeedingReview) {
        final proposalId = proposal['id']?.toString();
        final title = proposal['title'] ?? 'Untitled Proposal';

        if (proposalId == null) continue;

        try {
          // Call the real AI risk analysis API
          final riskAnalysis =
              await _fetchProposalRisks(app.authToken!, proposalId);

          if (riskAnalysis != null) {
            final riskScore = riskAnalysis['risk_score'] as int? ?? 0;
            final issues = riskAnalysis['issues'] as List<dynamic>? ?? [];
            final overallRiskLevel =
                riskAnalysis['overall_risk_level'] as String? ?? 'low';

            // Only show risks if there are issues and risk score is significant
            if (issues.isNotEmpty && riskScore > 0) {
              final riskDescriptions = issues
                  .map((issue) => issue['description']?.toString() ?? '')
                  .where((desc) => desc.isNotEmpty)
                  .take(5)
                  .toList();

              if (riskDescriptions.isNotEmpty) {
                risks.add({
                  'id': 'risk_$proposalId',
                  'proposalId': proposalId,
                  'proposalTitle': title,
                  'riskCount': issues.length,
                  'risks': riskDescriptions,
                  'riskScore': riskScore,
                  'severity': overallRiskLevel == 'critical' ||
                          overallRiskLevel == 'high'
                      ? 'high'
                      : 'medium',
                  'createdAt': DateTime.now().toIso8601String(),
                  'isDismissed': false,
                });
              }
            }
          }
        } catch (e) {
          print('Error fetching risks for proposal $proposalId: $e');
          // Continue to next proposal if one fails
        }
      }
    } catch (e) {
      print('Error loading risk data: $e');
    }

    if (mounted) {
      setState(() {
        _riskItems = risks.where((r) => r['isDismissed'] != true).toList();
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchProposalRisks(
      String token, String proposalId) async {
    try {
      final proposalIdInt = int.tryParse(proposalId);
      if (proposalIdInt == null) {
        return null;
      }

      // Fetch the full proposal data first
      final proposals = await ApiService.getProposals(token);
      final proposal = proposals.firstWhere(
        (p) => p['id'] == proposalIdInt,
        orElse: () => <String, dynamic>{},
      );

      if (proposal.isEmpty) {
        print('Proposal not found: $proposalId');
        return null;
      }

      // Build proposal data for AI analysis
      final proposalData = <String, dynamic>{
        'id': proposal['id'],
        'title': proposal['title'] ?? proposal['proposal_title'] ?? 'Proposal',
        'clientName': proposal['client_name'] ?? '',
        'clientEmail': proposal['client_email'] ?? '',
        'projectType': proposal['project_type'] ?? '',
        'estimatedValue': proposal['estimated_value'] ?? '',
        'timeline': proposal['timeline'] ?? '',
      };

      // Add content sections if available
      if (proposal['content'] != null) {
        final content = proposal['content'];
        if (content is Map) {
          content.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              proposalData[key] = value.toString();
            }
          });
        }
      }

      final raw = await ApiService.analyzeRisks(
        token: token,
        proposalData: proposalData,
      );
      if (raw == null) return null;

      final String status = (raw['status'] ?? '').toString().toUpperCase();
      final int riskScore = (raw['risk_score'] is num)
          ? (raw['risk_score'] as num).toInt()
          : int.tryParse((raw['risk_score'] ?? 0).toString()) ?? 0;
      final issues = raw['issues'] as List<dynamic>? ?? [];

      String overallRiskLevel;
      if (status == 'BLOCK') {
        overallRiskLevel = 'high';
      } else if (status == 'REVIEW') {
        overallRiskLevel = 'medium';
      } else if (status == 'PASS') {
        overallRiskLevel = 'low';
      } else if (riskScore >= 80) {
        overallRiskLevel = 'high';
      } else if (riskScore >= 40) {
        overallRiskLevel = 'medium';
      } else {
        overallRiskLevel = 'low';
      }

      return {
        'overallRiskLevel': overallRiskLevel,
        'riskScore': riskScore,
        'status': status,
        'issues': issues,
        'canRelease': status == 'PASS',
        'lastAnalyzed': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error fetching proposal risks: $e');
      return null;
    }
  }

  void _dismissRisk(String riskId) {
    setState(() {
      _riskItems = _riskItems.where((r) => r['id'] != riskId).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Risk dismissed'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF3498DB),
      ),
    );
  }

  void _navigateToRiskProposal(String? proposalId, String proposalTitle) {
    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal ID not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      '/blank-document',
      arguments: {
        'proposalId': proposalId,
        'proposalTitle': proposalTitle,
      },
    );
  }

  List<dynamic> _getFilteredProposals(List<dynamic> proposals) {
    if (_statusFilter == 'all') {
      // Return all proposals when filter is 'all'
      return proposals;
    }
    return proposals.where((proposal) {
      // Handle null/empty status - default to 'draft'
      final rawStatus = proposal['status'];
      if (rawStatus == null || rawStatus.toString().trim().isEmpty) {
        // If status is null/empty and filter is 'draft', include it
        return _statusFilter.toLowerCase() == 'draft';
      }
      // Normalize status for comparison (handle case variations)
      final status = rawStatus.toString().toLowerCase().trim();
      final filter = _statusFilter.toLowerCase().trim();

      // Special handling for draft status variations
      if (filter == 'draft') {
        return status == 'draft' || status.isEmpty;
      }

      // Special handling for "changes requested" - handle case variations
      if (filter == 'changes requested') {
        return status == 'changes requested' ||
            status.contains('changes requested');
      }

      // For other statuses, do exact match after normalization
      return status == filter;
    }).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
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

  /// Comment / mention / reaction notifications → Messages inbox
  static bool _notificationIsCommentMessage(Map<String, dynamic> n) {
    final t =
        (n['notification_type'] ?? n['type'] ?? '').toString().toLowerCase();
    return t.contains('comment') || t == 'mentioned' || t.contains('mention');
  }

  static Map<String, dynamic> _asNotificationMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return raw.cast<String, dynamic>();
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  int _unreadNotificationCount(AppState app, {required bool messagesOnly}) {
    var n = 0;
    for (final raw in app.notifications) {
      final item = _asNotificationMap(raw);
      if (item.isEmpty) continue;
      final isComment = _notificationIsCommentMessage(item);
      if (messagesOnly != isComment) continue;
      if (item['is_read'] != true) n++;
    }
    return n;
  }

  List<Map<String, dynamic>> _notificationsFiltered(
    AppState app, {
    required bool messagesOnly,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final raw in app.notifications) {
      final item = _asNotificationMap(raw);
      if (item.isEmpty) continue;
      if (messagesOnly != _notificationIsCommentMessage(item)) continue;
      out.add(item);
    }
    return out;
  }

  Widget _buildNotificationButton(AppState app, ManagerChromeTheme chrome) {
    final unread = _unreadNotificationCount(app, messagesOnly: false);
    return _buildIconButton(
      chrome: chrome,
      assetPath: 'assets/images/new icons for manager/notifications.png',
      badge: unread > 0 ? unread : null,
      onTap: () async {
        await app.fetchNotifications();
        if (!mounted) return;
        _showNotificationsSheet(app, messagesOnly: false);
      },
    );
  }

  void _showNotificationsSheet(AppState app, {bool messagesOnly = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final notifications =
                  _notificationsFiltered(app, messagesOnly: messagesOnly);
              final unreadCount =
                  _unreadNotificationCount(app, messagesOnly: messagesOnly);

              Future<void> markAllInSheet() async {
                for (final n
                    in List<Map<String, dynamic>>.from(notifications)) {
                  if (n['is_read'] == true) continue;
                  final idRaw = n['id'];
                  final id = idRaw is int
                      ? idRaw
                      : int.tryParse(idRaw?.toString() ?? '');
                  if (id != null) await app.markNotificationRead(id);
                }
                await app.fetchNotifications();
                if (context.mounted) setModalState(() {});
              }

              Future<void> deleteAllInSheet() async {
                for (final n
                    in List<Map<String, dynamic>>.from(notifications)) {
                  final idRaw = n['id'];
                  final id = idRaw is int
                      ? idRaw
                      : int.tryParse(idRaw?.toString() ?? '');
                  if (id != null) await app.deleteNotification(id);
                }
                await app.fetchNotifications();
                if (context.mounted) setModalState(() {});
              }

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C3E50),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            messagesOnly ? 'Messages' : 'Notifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              if (unreadCount > 0)
                                TextButton(
                                  onPressed: () async {
                                    await markAllInSheet();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              TextButton(
                                onPressed: notifications.isEmpty
                                    ? null
                                    : () async {
                                        await deleteAllInSheet();
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade200,
                                ),
                                child: const Text(
                                  'Delete all',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (notifications.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            messagesOnly
                                ? 'No comment messages yet.'
                                : 'No notifications yet.',
                            style: const TextStyle(
                              color: Color(0xFF4A4A4A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];

                            final title =
                                notification['title']?.toString().trim();
                            final message =
                                notification['message']?.toString().trim() ??
                                    '';
                            final proposalTitle = notification['proposal_title']
                                ?.toString()
                                .trim();
                            final isRead = notification['is_read'] == true;
                            final timeLabel = _formatNotificationTimestamp(
                                notification['created_at']);

                            final dynamic notificationIdRaw =
                                notification['id'];
                            final int? notificationId = notificationIdRaw is int
                                ? notificationIdRaw
                                : int.tryParse(
                                    notificationIdRaw?.toString() ?? '',
                                  );

                            return ListTile(
                              onTap: () async {
                                Navigator.of(bottomSheetContext).pop();
                                await _handleNotificationTap(
                                  app,
                                  notification,
                                  notificationId: notificationId,
                                  isAlreadyRead: isRead,
                                );
                              },
                              leading: Icon(
                                messagesOnly
                                    ? (isRead
                                        ? Icons.chat_bubble_outline
                                        : Icons.mark_chat_unread_outlined)
                                    : (isRead
                                        ? Icons.notifications_none_outlined
                                        : Icons.notifications_active),
                                color: isRead
                                    ? const Color(0xFF95A5A6)
                                    : const Color(0xFF3498DB),
                              ),
                              title: Text(
                                title?.isNotEmpty == true
                                    ? title!
                                    : 'Notification',
                                style: TextStyle(
                                  color: const Color(0xFF2C3E50),
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        message,
                                        style: const TextStyle(
                                          color: Color(0xFF4A4A4A),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (proposalTitle != null &&
                                      proposalTitle.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        proposalTitle,
                                        style: const TextStyle(
                                          color: Color(0xFF7F8C8D),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (timeLabel.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          color: Color(0xFF95A5A6),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: !isRead && notificationId != null
                                  ? Wrap(
                                      spacing: 4,
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            await app.markNotificationRead(
                                                notificationId);
                                            setModalState(() {});
                                          },
                                          child: const Text('Mark read'),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            await app.deleteNotification(
                                                notificationId);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    )
                                  : (notificationId != null
                                      ? IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            await app.deleteNotification(
                                                notificationId);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                        )
                                      : null),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<String, dynamic> _parseNotificationMetadata(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      try {
        return raw.cast<String, dynamic>();
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to decode notification metadata: $e');
      }
    }
    return <String, dynamic>{};
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  String? _asIdString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
        return null;
      }
      return trimmed;
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final counts = app.dashboardCounts;
    // Map backend role to display name
    final backendRole =
        app.currentUser?['role']?.toString().toLowerCase() ?? 'manager';
    final userRole = backendRole == 'manager' ||
            backendRole == 'financial manager' ||
            backendRole == 'creator'
        ? 'Manager'
        : backendRole == 'admin' || backendRole == 'ceo'
            ? 'Admin'
            : 'Manager'; // Default to Manager

    print('Dashboard - Current User: ${app.currentUser}');
    print('Dashboard - User Role: $userRole');
    print('Dashboard - Counts: $counts');
    print('Dashboard - Proposals: ${app.proposals}');

    final chrome = context.watch<ManagerThemeController>().chrome;
    final showManagerThemeFab = backendRole == 'manager' ||
        backendRole == 'financial manager' ||
        backendRole == 'creator';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: showManagerThemeFab
          ? FloatingActionButton(
              heroTag: 'manager_dashboard_theme_toggle',
              backgroundColor: ManagerChromeTheme.accentRed,
              onPressed: () {
                final ctrl = context.read<ManagerThemeController>();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ctrl.toggle();
                });
              },
              child: Icon(
                chrome.isDark
                    ? Icons.wb_sunny_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
            )
          : null,
      body: ManagerPageBackground(
        child: Row(
          children: [
            // Sidebar
            Consumer<AppState>(
              builder: (context, app, child) {
                final role = (app.currentUser?['role'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final isAdmin =
                    role == 'admin' || role == 'ceo' || role == 'approver';
                return AppSideNav(
                  isCollapsed: app.isSidebarCollapsed,
                  currentLabel: app.currentNavLabel,
                  isAdmin: isAdmin,
                  onToggle: app.toggleSidebar,
                  onSelect: (label) {
                    app.setCurrentNavLabel(label);
                    _navigateToPage(context, label);
                  },
                );
              },
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // ── Header bar ────────────────────────────────────────────
                  _buildHeaderBar(app, userRole, chrome),

                  // ── Scrollable body ───────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: CustomScrollbar(
                        controller: _scrollController,
                        child: RefreshIndicator(
                          onRefresh: _refreshData,
                          color: const Color(0xFFC10D00),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildRoleSpecificContent(
                                userRole, counts, app, chrome),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  const Footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
      AppState app, String userRole, ManagerChromeTheme chrome) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: chrome.headerBarFill,
        border: Border(
          bottom: BorderSide(
            color: chrome.divider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: title + greeting
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getHeaderTitle(userRole),
                  style: TextStyle(
                    color: chrome.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Hello, ',
                        style: TextStyle(
                          color: chrome.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: _getUserName(app.currentUser),
                        style: TextStyle(
                          color: chrome.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: messages (comments & mentions), notifications (everything else), profile
          _buildIconButton(
            chrome: chrome,
            assetPath: 'assets/images/new icons for manager/messages.png',
            onTap: () async {
              await app.fetchNotifications();
              if (!mounted) return;
              _showNotificationsSheet(app, messagesOnly: true);
            },
            badge: _unreadNotificationCount(app, messagesOnly: true) > 0
                ? _unreadNotificationCount(app, messagesOnly: true)
                : null,
          ),
          const SizedBox(width: 8),
          // Notifications icon (preserves existing functionality)
          _buildNotificationButton(app, chrome),
          const SizedBox(width: 12),
          // Profile avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC10D00).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/User_Profile.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: chrome.textSecondary, size: 28),
            onSelected: (value) {
              if (value == 'logout') {
                app.logout();
                AuthService.logout();
                Navigator.pushNamed(context, '/login');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
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

  Widget _buildIconButton({
    required ManagerChromeTheme chrome,
    required String assetPath,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: chrome.floatingFill,
              shape: BoxShape.circle,
            ),
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFC10D00),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                badge > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Messages + unread count (comment / mention notifications) for Recent Proposals header
  Widget _buildRecentProposalsMessagesTrailing(
      AppState app, ManagerChromeTheme chrome) {
    final c = _unreadNotificationCount(app, messagesOnly: true);
    return InkWell(
      onTap: () async {
        await app.fetchNotifications();
        if (!mounted) return;
        _showNotificationsSheet(app, messagesOnly: true);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: chrome.isDark
                    ? null
                    : Border.all(color: chrome.divider, width: 1),
              ),
              child: Image.asset(
                'assets/images/new icons for manager/messages.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$c',
              style: TextStyle(
                color: chrome.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall =
        screenWidth < 1200; // Increased breakpoint for better 100% zoom support
    final effectiveCollapsed = isSmall ? true : _isSidebarCollapsed;

    return AnimatedContainer(
      duration: AppColors.animationDuration,
      width: effectiveCollapsed
          ? AppColors.collapsedWidth
          : AppColors.expandedWidth,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundColor
                .withValues(alpha: AppColors.backgroundOpacity),
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
                        setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: AppColors.itemHeight,
                      decoration: BoxDecoration(
                        color: AppColors.hoverColor,
                        borderRadius: BorderRadius.circular(10),
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
                        assetPath: 'assets/images/Dahboard.png',
                        isSelected: _currentPage == 'Dashboard',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _navigateToPage(context, 'Dashboard'),
                      ),
                      _buildSidebarNavItem(
                        label: 'My Proposals',
                        assetPath: 'assets/images/My_Proposals.png',
                        isSelected: _currentPage == 'My Proposals',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _navigateToPage(context, 'My Proposals'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Templates',
                        assetPath: 'assets/images/content_library.png',
                        isSelected: _currentPage == 'Templates',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _navigateToPage(context, 'Templates'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Content Library',
                        assetPath: 'assets/images/content_library.png',
                        isSelected: _currentPage == 'Content Library',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Content Library'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Client Management',
                        assetPath: 'assets/images/collaborations.png',
                        isSelected: _currentPage == 'Client Management',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Client Management'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Approved Proposals',
                        assetPath:
                            'assets/images/Time Allocation_Approval_Blue.png',
                        isSelected: _currentPage == 'Approved Proposals',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Approved Proposals'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Analytics (My Pipeline)',
                        assetPath: 'assets/images/analytics.png',
                        isSelected: _currentPage == 'Analytics (My Pipeline)',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Analytics (My Pipeline)'),
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
                        assetPath: 'assets/images/Logout_KhonoBuzz.png',
                        isSelected: false,
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _handleLogout(context),
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
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: AppColors.animationDuration,
                height: AppColors.itemHeight,
                decoration: BoxDecoration(
                  color: _getItemColor(isSelected, hovering, isCollapsed),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isCollapsed
                    ? _buildCollapsedItem(
                        assetPath, isSelected, showProfileIndicator)
                    : _buildExpandedItem(label, assetPath, isSelected),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedItem(
      String assetPath, bool isSelected, bool showProfileIndicator) {
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
                isSelected
                    ? assetPath
                    : assetPath, // Use red asset when selected and collapsed
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
                assetPath, // Always use white asset when expanded
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
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

  List<BoxShadow> _getItemShadow(
      bool isSelected, bool hovering, bool isCollapsed) {
    return [];
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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFFCBD5E1),
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
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFFCBD5E1),
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
                    color: isActive ? Colors.white : const Color(0xFFECF0F1),
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

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        // Already on dashboard
        break;
      case 'My Proposals':
      case 'Proposals':
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
      case 'Account Profile':
        ManagerSessionActions.goToAccountProfile(context);
        break;
      case 'Logout':
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    ManagerSessionActions.showLogoutDialog(context);
  }

  // Legacy wrapper kept for CEO/Client dashboard branches
  Widget _buildSection(
      String title, Widget content, ManagerChromeTheme chrome) {
    return _buildDashboardSection(title: title, child: content, chrome: chrome);
  }

  Widget _buildDashboardSection({
    String? iconAsset,
    required String title,
    String? subtitle,
    int? badge,
    bool iconOnWhiteCircle = false,
    Widget? headerTrailing,
    required Widget child,
    required ManagerChromeTheme chrome,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: chrome.floatingPanelDecoration(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (iconAsset != null) ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconOnWhiteCircle
                        ? Colors.white
                        : const Color(0xFFC10D00).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: iconOnWhiteCircle && !chrome.isDark
                        ? Border.all(color: chrome.divider, width: 1)
                        : null,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(iconAsset, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: chrome.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null && badge > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC10D00),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: chrome.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (headerTrailing != null) ...[
                const SizedBox(width: 12),
                headerTrailing,
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: chrome.divider),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDashboardGrid(Map<String, dynamic> counts, BuildContext context,
      ManagerChromeTheme chrome) {
    final cards = [
      {
        'title': 'Draft Proposals',
        'subtitle': 'Additional description\ninformation can be included.',
        'value': counts['Draft']?.toString() ?? '0',
        'icon': 'assets/images/new icons for manager/Draft proposal.png',
      },
      {
        'title': 'Pending CEO Approval',
        'subtitle': 'Additional description\ninformation can be included.',
        'value':
            (counts['Pending CEO Approval'] ?? counts['Pending Approval'] ?? 0)
                .toString(),
        'icon': 'assets/images/new icons for manager/Pending Ceo approval.png',
      },
      {
        'title': 'Sent to Client',
        'subtitle': 'Additional description\ninformation can be included.',
        'value': counts['Sent to Client']?.toString() ?? '0',
        'icon': 'assets/images/new icons for manager/sent to client.png',
      },
      {
        'title': 'Signed',
        'subtitle': 'Additional description\ninformation can be included.',
        'value': counts['Signed']?.toString() ?? '0',
        'icon': 'assets/images/new icons for manager/signed.png',
      },
    ];

    return Row(
      children: cards
          .map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildStatCard(
                    card['title']!,
                    card['value']!,
                    card['subtitle']!,
                    card['icon']!,
                    context,
                    chrome,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    String iconAsset,
    BuildContext context,
    ManagerChromeTheme chrome,
  ) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/proposals'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: chrome.floatingPanelDecoration(radius: 10),
        child: Row(
          children: [
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: chrome.textSecondary,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Icon (~2× for visual prominence)
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC10D00).withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Image.asset(iconAsset, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflow(BuildContext context, ManagerChromeTheme chrome) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildWorkflowStep('1', 'Compose', context, chrome),
        _buildWorkflowStep('2', 'Govern', context, chrome),
        _buildWorkflowStep('3', 'AI Risk Gate', context, chrome),
        _buildWorkflowStep('4', 'Preview', context, chrome),
        _buildWorkflowStep('5', 'Internal Sign-off', context, chrome),
      ],
    );
  }

  Widget _buildWorkflowStep(String number, String label, BuildContext context,
      ManagerChromeTheme chrome) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _navigateToWorkflowStep(context, label);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFFC10D00),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: chrome.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToWorkflowStep(BuildContext context, String step) {
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $step...'),
        duration: const Duration(milliseconds: 500),
        backgroundColor: const Color(0xFF3498DB),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      switch (step) {
        case 'Compose':
          Navigator.pushNamed(context, '/compose');
          break;
        case 'Govern':
          Navigator.pushNamed(context, '/govern');
          break;
        case 'AI Risk Gate':
          // For now, navigate to approvals as AI risk gate might be part of approval process
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'Preview':
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'Internal Sign-off':
          Navigator.pushNamed(context, '/approvals');
          break;
        default:
          Navigator.pushNamed(context, '/creator_dashboard');
      }
    });
  }

  void _navigateToSystemComponent(BuildContext context, String component) {
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $component...'),
        duration: const Duration(milliseconds: 500),
        backgroundColor: const Color(0xFF3498DB),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      switch (component) {
        case 'Template Library':
          Navigator.pushNamed(context, '/compose');
          break;
        case 'Content Blocks':
          Navigator.pushNamed(context, '/content_library');
          break;
        case 'Client Management':
          Navigator.pushNamed(context, '/client_management');
          break;
        case 'E-Signature':
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'Analytics':
          Navigator.pushNamed(context, '/proposals');
          break;
        case 'User Management':
          Navigator.pushNamed(context, '/admin_dashboard');
          break;
        default:
          Navigator.pushNamed(context, '/creator_dashboard');
      }
    });
  }

  Future<void> _handleNotificationTap(
    AppState app,
    Map<String, dynamic> notification, {
    int? notificationId,
    bool isAlreadyRead = false,
  }) async {
    final metadata = _parseNotificationMetadata(notification['metadata']);

    String? proposalId = _asIdString(
      metadata['proposal_id'] ?? notification['proposal_id'],
    );

    // Fallback for legacy resource identifiers pointing to proposals
    proposalId ??= _asIdString(metadata['resource_id']);

    final proposalTitle =
        notification['proposal_title']?.toString().trim().isNotEmpty == true
            ? notification['proposal_title'].toString().trim()
            : notification['title']?.toString().trim();

    if (notificationId != null && !isAlreadyRead) {
      try {
        await app.markNotificationRead(notificationId);
      } catch (e) {
        debugPrint('⚠️ Failed to mark notification as read: $e');
      }
    }

    if (!mounted) return;

    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification is missing proposal details.'),
        ),
      );
      return;
    }

    final args = <String, dynamic>{
      'proposalId': proposalId,
      if (proposalTitle != null && proposalTitle.isNotEmpty)
        'proposalTitle': proposalTitle,
    };

    final sectionIndex = _asInt(metadata['section_index']);
    final commentId = _asInt(metadata['comment_id']);
    if (sectionIndex != null) {
      args['initialSectionIndex'] = sectionIndex;
    }
    if (commentId != null) {
      args['initialCommentId'] = commentId;
    }

    Navigator.of(context).pushNamed('/blank-document', arguments: args);
  }

  DateTime _toSast(DateTime dt) {
    final utc = dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
            dt.millisecond, dt.microsecond);
    return utc.add(const Duration(hours: 2));
  }

  String _formatNotificationTimestamp(dynamic value) {
    DateTime? timestamp;
    if (value is String) {
      timestamp = DateTime.tryParse(value);
    } else if (value is DateTime) {
      timestamp = value;
    }

    if (timestamp == null) {
      return '';
    }

    final sast = _toSast(timestamp);
    final now = _toSast(DateTime.now().toUtc());
    final difference = now.difference(sast);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    final month = sast.month.toString().padLeft(2, '0');
    final day = sast.day.toString().padLeft(2, '0');
    return '${sast.year}-$month-$day';
  }

  Widget _buildAISection(ManagerChromeTheme chrome) {
    if (_riskItems.isEmpty) {
      return _buildDashboardSection(
        chrome: chrome,
        iconAsset: 'assets/images/new icons for manager/risk_gate_tab.png',
        title: 'AI-Powered Compound Risk Gate',
        subtitle:
            'AI analyses multiple small deviations and flags combined risks.',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: chrome.isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: Color(0xFFC10D00),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 14),
              Text(
                'No Risks Detected',
                style: TextStyle(
                  color: chrome.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All proposals are risk-free.',
                style: TextStyle(
                  color: chrome.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildDashboardSection(
      chrome: chrome,
      iconAsset: 'assets/images/new icons for manager/risk_gate_tab.png',
      title: 'AI-Powered Compound Risk Gate',
      subtitle:
          'AI analyses multiple small deviations and flags combined risks.',
      badge: _riskItems.isNotEmpty ? _riskItems.length : null,
      child: Column(
        children:
            _riskItems.map((risk) => _buildRiskItem(risk, chrome)).toList(),
      ),
    );
  }

  Widget _buildRiskItem(Map<String, dynamic> risk, ManagerChromeTheme chrome) {
    final proposalTitle = risk['proposalTitle'] ?? 'Untitled Proposal';
    final riskCount = risk['riskCount'] ?? 0;
    final risks = (risk['risks'] as List<dynamic>?) ?? [];
    final severity = risk['severity'] ?? 'medium';
    final proposalId = risk['proposalId'] as String?;
    final riskId = risk['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: chrome.floatingPanelDecoration(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: proposalId != null
                      ? () => _navigateToRiskProposal(proposalId, proposalTitle)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            proposalTitle,
                            style: PremiumTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: chrome.textPrimary,
                            ),
                          ),
                          if (proposalId != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: ManagerChromeTheme.leftAccentBlue,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$riskCount ${riskCount == 1 ? 'risk' : 'risks'} detected: ${risks.join(', ')}',
                        style: PremiumTheme.bodyMedium
                            .copyWith(color: chrome.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: chrome.textSecondary,
                tooltip: 'Dismiss risk',
                onPressed: () => _dismissRisk(riskId),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: severity == 'high'
                      ? PremiumTheme.error.withOpacity(0.2)
                      : PremiumTheme.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: severity == 'high'
                        ? PremiumTheme.error.withOpacity(0.3)
                        : PremiumTheme.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  severity == 'high' ? 'High Priority' : 'Review Needed',
                  style: PremiumTheme.labelMedium.copyWith(
                    color: severity == 'high'
                        ? PremiumTheme.error
                        : PremiumTheme.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (proposalId != null)
                TextButton.icon(
                  onPressed: () =>
                      _navigateToRiskProposal(proposalId, proposalTitle),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Review Proposal'),
                  style: TextButton.styleFrom(
                    foregroundColor: ManagerChromeTheme.leftAccentBlue,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProposals(
      List<dynamic> proposals, ManagerChromeTheme chrome) {
    final filteredProposals = _getFilteredProposals(proposals);

    filteredProposals.sort((a, b) {
      DateTime? parseDate(dynamic value) {
        if (value == null) return null;
        final s = value.toString();
        if (s.isEmpty) return null;
        return DateTime.tryParse(s);
      }

      final aUpdated = parseDate(a['updated_at']);
      final bUpdated = parseDate(b['updated_at']);

      // Prefer updated_at when available
      if (aUpdated != null && bUpdated != null) {
        return bUpdated.compareTo(aUpdated);
      }
      if (aUpdated != null) return -1;
      if (bUpdated != null) return 1;

      final aCreated = parseDate(a['created_at']);
      final bCreated = parseDate(b['created_at']);

      if (aCreated != null && bCreated != null) {
        return bCreated.compareTo(aCreated);
      }
      if (aCreated != null) return -1;
      if (bCreated != null) return 1;

      // Fallback: sort by numeric id if dates are missing
      final aId = int.tryParse(a['id']?.toString() ?? '');
      final bId = int.tryParse(b['id']?.toString() ?? '');
      if (aId != null && bId != null) {
        return bId.compareTo(aId);
      }
      return 0;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTab('VIEW ALL', 'all', proposals.length, chrome),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'DRAFT',
                  'draft',
                  proposals.where((p) {
                    final status = (p['status'] ?? 'Draft')
                        .toString()
                        .toLowerCase()
                        .trim();
                    return status == 'draft' || status.isEmpty;
                  }).length,
                  chrome),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'SENT TO CLIENT',
                  'sent to client',
                  proposals
                      .where((p) =>
                          (p['status'] ?? '').toString().toLowerCase() ==
                          'sent to client')
                      .length,
                  chrome),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'PENDING CEO APPROVAL',
                  'pending ceo approval',
                  proposals
                      .where((p) => (() {
                            final s =
                                (p['status'] ?? '').toString().toLowerCase();
                            return s == 'pending ceo approval' ||
                                s == 'pending approval' ||
                                s == 'in review' ||
                                s == 'submitted';
                          })())
                      .length,
                  chrome),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'SIGNED',
                  'signed',
                  proposals
                      .where((p) =>
                          (p['status'] ?? '').toString().toLowerCase() ==
                          'signed')
                      .length,
                  chrome),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'CHANGES REQUESTED',
                  'changes requested',
                  proposals
                      .where((p) =>
                          (p['status'] ?? '').toString().toLowerCase() ==
                          'changes requested')
                      .length,
                  chrome),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filtered Proposals List
        if (filteredProposals.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: chrome.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No proposals found',
                    style: TextStyle(fontSize: 16, color: chrome.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredProposals.take(5).map((proposal) {
            String status = proposal['status'] ?? 'Draft';
            Color statusColor = _getStatusColor(status);
            Color textColor = _getStatusTextColor(status);

            return _buildProposalItem(
              proposal,
              status,
              statusColor,
              textColor,
              chrome,
            );
          }).toList(),
      ],
    );
  }

  Widget _buildFilterTab(
      String label, String value, int count, ManagerChromeTheme chrome) {
    final isActive = _statusFilter == value;
    final showCount = value == 'all' && count > 0;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC10D00) : chrome.filterInactiveBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: chrome.filterBorder,
            width: 1,
          ),
        ),
        child: Text(
          showCount ? '$label ($count)' : label,
          style: TextStyle(
            color: isActive ? Colors.white : chrome.textPrimary,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildProposalItem(Map<String, dynamic> proposal, String status,
      Color statusColor, Color textColor, ManagerChromeTheme chrome) {
    final title = (proposal['title'] ?? 'Untitled').toString();
    final clientName =
        (proposal['client_name'] ?? proposal['client'] ?? '').toString().trim();
    final isSentToClient = status.toLowerCase() == 'sent to client';
    final proposalId = proposal['id']?.toString();
    final selected =
        proposalId != null && _selectedRecentProposalIds.contains(proposalId);

    // Read-only for statuses where editing is not allowed
    final editableStatuses = {'draft', 'changes requested'};
    final isEditable = editableStatuses.contains(status.toLowerCase());

    void openProposal() {
      if (proposalId == null) return;
      Navigator.of(context).pushNamed(
        '/blank-document',
        arguments: {
          'proposalId': proposalId,
          'readOnly': !isEditable,
        },
      );
    }

    final checkboxIdleBorder = selected
        ? const Color(0xFFC10D00)
        : (chrome.isDark
            ? Colors.white.withOpacity(0.35)
            : ManagerChromeTheme.textDark.withOpacity(0.35));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: chrome.floatingPanelDecoration(radius: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (proposalId == null) return;
              setState(() {
                if (selected) {
                  _selectedRecentProposalIds.remove(proposalId);
                } else {
                  _selectedRecentProposalIds.add(proposalId);
                }
              });
            },
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checkboxIdleBorder,
                  width: 2,
                ),
                color: selected ? const Color(0xFFC10D00) : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: openProposal,
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: chrome.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: clientName.isNotEmpty
                          ? ' — $clientName'
                          : ' — Unknown Client',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: chrome.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _statusChipLabel(status),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: openProposal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF7F7F7F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'VIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          if (isSentToClient) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showInsightsModal(proposal),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child:
                    Icon(Icons.insights, size: 24, color: chrome.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getClientInitials(String clientName) {
    if (clientName.isEmpty) return '?';
    final parts = clientName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clientName[0].toUpperCase();
  }

  Future<Map<String, dynamic>?> _getLastActivity(String? proposalId) async {
    if (proposalId == null) return null;
    try {
      final app = context.read<AppState>();
      return await app.getProposalAnalytics(proposalId);
    } catch (e) {
      print('Error fetching analytics: $e');
      return null;
    }
  }

  String _formatLastActivity(Map<String, dynamic>? analytics) {
    if (analytics == null) return 'Not viewed';

    final events = analytics['events'] as List?;
    if (events == null || events.isEmpty) return 'Not viewed';

    // Find the most recent 'open' event
    final openEvents = events.where((e) => e['event_type'] == 'open').toList();
    if (openEvents.isEmpty) return 'Not viewed';

    final lastOpen = openEvents.first;
    final createdAt = lastOpen['created_at'] as String?;
    if (createdAt == null) return 'Not viewed';

    try {
      final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(createdAt);
      final parsedRaw = DateTime.parse(createdAt);
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

      final diff = now.difference(parsed);
      if (diff.inDays > 0) return 'Viewed ${diff.inDays}d ago';
      if (diff.inHours > 0) return 'Viewed ${diff.inHours}h ago';
      if (diff.inMinutes > 0) return 'Viewed ${diff.inMinutes}m ago';
      return 'Viewed just now';
    } catch (e) {
      return 'Viewed';
    }
  }

  void _showInsightsModal(Map<String, dynamic> proposal) {
    showDialog(
      context: context,
      builder: (context) => ProposalInsightsModal(
        proposalId: proposal['id']?.toString() ?? '',
        proposalTitle: proposal['title'] ?? 'Untitled',
      ),
    );
  }

  Widget _buildSystemComponents(ManagerChromeTheme chrome) {
    final components = [
      {
        'icon': 'assets/images/new icons for manager/Template_li`brary_tab.png',
        'label': 'Template Library',
      },
      {
        'icon': 'assets/images/new icons for manager/content_block_tab.png',
        'label': 'Content Blocks',
      },
      {
        'icon': 'assets/images/new icons for manager/client_management_tab.png',
        'label': 'Client Management',
      },
      {
        'icon': 'assets/images/new icons for manager/E-signature_tab.png',
        'label': 'E-Signature',
      },
      {
        'icon': 'assets/images/new icons for manager/analytics_tab.png',
        'label': 'Analytics',
      },
      {
        'icon': 'assets/images/new icons for manager/user_management_tab.png',
        'label': 'User Management',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];
        final label = component['label']!;
        final iconAsset = component['icon']!;
        return InkWell(
          onTap: () => _navigateToSystemComponent(context, label),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: chrome.floatingFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFC10D00).withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC10D00).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(iconAsset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: chrome.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return PremiumTheme.orange;
      case 'in review':
      case 'pending ceo approval':
        return PremiumTheme.purple;
      case 'sent to client':
        return const Color(0xFFEA990C); // Request Sent
      case 'signed':
        return const Color(0xFF6CA510);
      case 'changes requested':
        return Colors.orange;
      case 'resubmitted':
        return const Color(0xFF6095CC);
      default:
        return PremiumTheme.orange;
    }
  }

  String _statusChipLabel(String raw) {
    final s = raw.toString().trim().toLowerCase();
    switch (s) {
      case 'sent to client':
        return 'Request Sent';
      case '':
        return 'Draft';
      default:
        return raw
            .toString()
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .map((w) =>
                '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}')
            .join(' ');
    }
  }

  Color _getStatusTextColor(String status) {
    // For the new premium design, we use the same color for text
    // with opacity adjustments in the container
    return _getStatusColor(status);
  }

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
      } catch (_) {
        return date.toString();
      }
    }
    return date.toString();
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

  String _getHeaderTitle(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'ceo':
        return 'Admin Dashboard - Executive Overview';
      case 'manager':
      case 'financial manager':
        return 'Manager Dashboard';
      case 'client':
        return 'Client Portal - My Proposals';
      default:
        return 'Manager Dashboard';
    }
  }

  Widget _buildRoleSpecificContent(String role, Map<String, dynamic> counts,
      AppState app, ManagerChromeTheme chrome) {
    final roleLower = role.toLowerCase();
    switch (roleLower) {
      case 'admin':
      case 'ceo':
        return _buildCEODashboard(counts, app, chrome);
      case 'client':
        return _buildClientDashboard(counts, app, chrome);
      case 'manager':
      case 'financial manager':
      default:
        return _buildFinancialManagerDashboard(counts, app, chrome);
    }
  }

  Widget _buildCEODashboard(
      Map<String, dynamic> counts, AppState app, ManagerChromeTheme chrome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CEO Executive Dashboard',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: chrome.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Organization-wide overview and pending approvals',
          style: TextStyle(color: chrome.textSecondary),
        ),
        const SizedBox(height: 24),

        // CEO Dashboard Grid
        _buildSection(
          'Organization Overview',
          _buildDashboardGrid(counts, context, chrome),
          chrome,
        ),
        const SizedBox(height: 20),

        // Pending Approvals Section (CEO-specific)
        _buildSection(
          'Awaiting Your Approval',
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.pending_actions,
                    size: 48, color: Color(0xFFE67E22)),
                const SizedBox(height: 12),
                Text(
                  '${(counts['Pending CEO Approval'] ?? counts['Pending Approval'] ?? 0)} proposals pending your approval',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: chrome.textPrimary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.approval),
                  label: const Text('Review Pending Approvals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/approvals');
                  },
                ),
              ],
            ),
          ),
          chrome,
        ),
        const SizedBox(height: 20),

        // Recent Proposals
        _buildSection(
          'All Proposals (Organization-wide)',
          _buildRecentProposals(app.proposals, chrome),
          chrome,
        ),
      ],
    );
  }

  void _openProposalFromWidget(int proposalId, String status) {
    final editableStatuses = {'draft', 'changes requested'};
    final isEditable = editableStatuses.contains(status.toLowerCase());
    Navigator.of(context).pushNamed(
      '/blank-document',
      arguments: {
        'proposalId': proposalId,
        'readOnly': !isEditable,
      },
    );
  }

  Widget _buildFinancialManagerDashboard(
      Map<String, dynamic> counts, AppState app, ManagerChromeTheme chrome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat cards row (full width)
        _buildDashboardGrid(counts, context, chrome),
        const SizedBox(height: 16),

        // 2-column layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column (~60%)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildDashboardSection(
                    chrome: chrome,
                    iconAsset:
                        'assets/images/new icons for manager/proposals.png',
                    iconOnWhiteCircle: true,
                    title: 'Recent Proposals',
                    subtitle:
                        'Additional description can be included if required.',
                    headerTrailing:
                        _buildRecentProposalsMessagesTrailing(app, chrome),
                    child: _buildRecentProposals(app.proposals, chrome),
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardSection(
                    chrome: chrome,
                    iconAsset:
                        'assets/images/new icons for manager/available_tools.png',
                    title: 'Available Tools',
                    subtitle:
                        'Additional description can be included if required.',
                    child: _buildSystemComponents(chrome),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right column (~40%)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildDashboardSection(
                    chrome: chrome,
                    iconAsset:
                        'assets/images/new icons for manager/proposal_workflow.png',
                    title: 'Proposal Workflow',
                    subtitle:
                        'Additional description can be included if required.',
                    child: _buildWorkflow(context, chrome),
                  ),
                  const SizedBox(height: 16),
                  _buildAISection(chrome),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientDashboard(
      Map<String, dynamic> counts, AppState app, ManagerChromeTheme chrome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client Portal',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: chrome.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'View and manage proposals sent to you',
          style: TextStyle(color: chrome.textSecondary),
        ),
        const SizedBox(height: 24),

        // Simplified Dashboard for Clients
        _buildSection(
          'My Proposals Status',
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            children: [
              _buildStatCard(
                  'Active Proposals',
                  counts['Sent to Client']?.toString() ?? '0',
                  'For Review',
                  'assets/images/new icons for manager/sent to client.png',
                  context,
                  chrome),
              _buildStatCard(
                  'Signed',
                  counts['Signed']?.toString() ?? '0',
                  'Completed',
                  'assets/images/new icons for manager/signed.png',
                  context,
                  chrome),
            ],
          ),
          chrome,
        ),
        const SizedBox(height: 20),

        // Active Proposals
        _buildSection(
          'Proposals Sent to Me',
          app.proposals.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 64, color: chrome.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'No proposals yet',
                          style: TextStyle(
                              fontSize: 18, color: chrome.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildRecentProposals(app.proposals, chrome),
          chrome,
        ),
        const SizedBox(height: 20),

        // Quick Actions
        _buildSection(
          'Quick Actions',
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download Signed Documents'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature coming soon!')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Support'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Support: support@example.com')),
                  );
                },
              ),
            ],
          ),
          chrome,
        ),
      ],
    );
  }
}
