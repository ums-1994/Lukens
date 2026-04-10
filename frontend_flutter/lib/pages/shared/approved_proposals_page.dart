// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/premium_theme.dart';
import '../../theme/manager_theme_controller.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/manager_page_background.dart';
import '../../utils/manager_session_actions.dart';
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ApprovedProposalsPage extends StatefulWidget {
  const ApprovedProposalsPage({super.key});

  @override
  State<ApprovedProposalsPage> createState() => _ApprovedProposalsPageState();
}

class _ApprovedProposalsPageState extends State<ApprovedProposalsPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _approvedProposals = [];
  bool _isLoading = true;
  double _totalApprovedValue = 0;
  DateTime? _lastApprovedDate;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  bool _isSidebarCollapsed = false;
  String _currentNavLabel = 'Approved Proposals';

  Future<void> _openSignedProposal(Map<String, dynamic> proposal) async {
    final idRaw = proposal['id'];
    final proposalId =
        idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
    final status = (proposal['status'] ?? '').toString().toLowerCase().trim();

    if (proposalId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('❌ Could not open signed proposal (missing proposal id).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isSigned = status == 'signed' ||
        status == 'completed' ||
        status == 'client signed';
    if (!isSigned) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Proposal is not signed yet (status: "$status").'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AuthService.restoreSessionFromStorage();
    var token = AuthService.token;
    if (token == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      token = AuthService.token;
    }

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Session expired. Please login again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening signed proposal...'),
        backgroundColor: Colors.black87,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final url =
          '${ApiService.baseUrl}/api/proposals/$proposalId/signed-document';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Request timed out'),
      );

      if (response.statusCode != 200) {
        String detail = 'Failed to retrieve signed proposal.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          }
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $detail'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final bytes = response.bodyBytes;
      final blob = html.Blob([bytes], 'application/pdf');
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(objectUrl, '_blank');
      Timer(const Duration(seconds: 60), () {
        try {
          html.Url.revokeObjectUrl(objectUrl);
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Could not open signed proposal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set the current navigation label for consistent sidebar state
      context.read<AppState>().setCurrentNavLabel('Approved Proposals');
      _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('🔄 Approved Proposals: Loading data...');
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('🔄 Restoring session from storage...');
      AuthService.restoreSessionFromStorage();

      var token = AuthService.token;
      if (token == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        token = AuthService.token;
      }

      if (token == null) {
        print('❌ No token available');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Session expired. Please login again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('📡 Fetching proposals from API...');
      final proposals = await ApiService.getProposals(token).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Timeout! API call took too long');
          throw Exception('Request timed out');
        },
      );
      print('✅ API Response received!');
      print('✅ Number of proposals: ${proposals.length}');

      // Filter for client-approved/signed proposals
      final approved = proposals
          .where((p) {
            final status = (p['status'] ?? '').toString().toLowerCase();
            return status == 'signed' ||
                status == 'client signed' ||
                status == 'approved' ||
                status == 'completed';
          })
          .map((p) => p as Map<String, dynamic>)
          .toList();

      approved.sort((a, b) {
        final aDate = a['updated_at'] != null
            ? DateTime.tryParse(a['updated_at'].toString())
            : null;
        final bDate = b['updated_at'] != null
            ? DateTime.tryParse(b['updated_at'].toString())
            : null;
        return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
      });

      double totalValue = 0;
      DateTime? latestApproved;
      for (final proposal in approved) {
        final budget = proposal['budget'];
        if (budget is num) {
          totalValue += budget.toDouble();
        } else if (budget is String) {
          final cleaned = budget.replaceAll(RegExp(r'[^\d.]'), '');
          totalValue += double.tryParse(cleaned) ?? 0;
        }

        final approvedDate = proposal['updated_at'] != null
            ? DateTime.tryParse(proposal['updated_at'].toString())
            : null;
        if (approvedDate != null) {
          latestApproved =
              (latestApproved == null || approvedDate.isAfter(latestApproved))
                  ? approvedDate
                  : latestApproved;
        }
      }

      if (mounted) {
        setState(() {
          _approvedProposals = approved;
          _totalApprovedValue = totalValue;
          _lastApprovedDate = latestApproved;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading approved proposals: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToPage(BuildContext context, String page) {
    switch (page) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/creator-dashboard');
        break;
      case 'My Proposals':
      case 'Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content-library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/client-management');
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved-proposals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Account Profile':
        ManagerSessionActions.goToAccountProfile(context);
        break;
      case 'Logout':
        ManagerSessionActions.showLogoutDialog(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ManagerPageBackground(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
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
                  isAdmin: isAdmin,
                  onToggle: () => setState(
                    () => _isSidebarCollapsed = !_isSidebarCollapsed,
                  ),
                  onSelect: (label) {
                    setState(() => _currentNavLabel = label);
                    _navigateToPage(context, label);
                  },
                );
              },
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Header - Fixed at top
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildHeader(app, chrome),
                  ),
                  const SizedBox(height: 24),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Section
                          _buildHeroSection(),
                          const SizedBox(height: 24),

                          // Content
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildApprovedList(chrome),
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

  Widget _buildHeader(AppState app, ManagerChromeTheme chrome) {
    final user = AuthService.currentUser ?? app.currentUser ?? {};
    final email = user['email']?.toString() ?? 'user@example.com';
    final backendRole = user['role']?.toString().toLowerCase() ?? 'manager';
    final displayRole =
        backendRole == 'admin' || backendRole == 'ceo' ? 'Admin' : 'Manager';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: chrome.floatingPanelDecoration(radius: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approved Proposals',
                style: PremiumTheme.titleLarge.copyWith(
                  color: chrome.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'View proposals that have been approved and signed by clients',
                style: TextStyle(color: chrome.textSecondary, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/User_Profile.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    displayRole,
                    style: TextStyle(color: chrome.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PremiumTheme.teal, PremiumTheme.teal.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client-Approved Proposals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _approvedProposals.isEmpty
                      ? 'No proposals have been approved by clients yet.'
                      : '${_approvedProposals.length} proposal${_approvedProposals.length == 1 ? '' : 's'} approved by clients${_lastApprovedDate != null ? ' (last approved ${_formatRelativeDate(_lastApprovedDate!)})' : ''}.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Export List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: PremiumTheme.teal,
            ),
            onPressed:
                _approvedProposals.isEmpty ? null : _exportApprovedProposals,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedList(ManagerChromeTheme chrome) {
    if (_approvedProposals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: chrome.floatingFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: chrome.divider),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: chrome.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No approved proposals yet',
              style: TextStyle(
                color: chrome.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Proposals that clients approve and sign will appear here.',
              style: TextStyle(color: chrome.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Metrics Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Approved',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _approvedProposals.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Value',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFormatter.format(_totalApprovedValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Proposals List
        ..._approvedProposals.map(
            (proposal) => _buildProposalCard(proposal, chrome)),
      ],
    );
  }

  Widget _buildProposalCard(
      Map<String, dynamic> proposal, ManagerChromeTheme chrome) {
    final title = proposal['title']?.toString() ?? 'Untitled Proposal';
    final client = proposal['client_name']?.toString() ??
        proposal['client']?.toString() ??
        'Unknown Client';
    final budget = proposal['budget']?.toString() ?? '0';
    final status = (proposal['status'] ?? '').toString().toLowerCase().trim();
    final date = proposal['updated_at']?.toString();

    final statusLabel = (status == 'signed' ||
            status == 'completed' ||
            status == 'client signed' ||
            status == 'client approved')
        ? 'Signed'
        : 'Approved';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openSignedProposal(proposal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: chrome.floatingPanelDecoration(radius: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: chrome.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        client,
                        style: TextStyle(
                          color: chrome.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Value: ${_currencyFormatter.format(double.tryParse(budget.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0)}',
                  style: TextStyle(
                    color: chrome.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  date != null
                      ? _formatDate(DateTime.tryParse(date))
                      : 'No date',
                  style: TextStyle(
                    color: chrome.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _exportApprovedProposals() async {
    try {
      final csvData = [
        ['Title', 'Client', 'Budget', 'Status', 'Date Approved'],
        ..._approvedProposals.map((proposal) => [
              proposal['title']?.toString() ?? '',
              proposal['client_name']?.toString() ??
                  proposal['client']?.toString() ??
                  '',
              proposal['budget']?.toString() ?? '',
              proposal['status']?.toString() ?? '',
              proposal['updated_at']?.toString() ?? '',
            ]),
      ];

      final csv = csvData
          .map((row) => row
              .map((cell) => '"${cell.toString().replaceAll('"', '""')}"')
              .join(','))
          .join('\n');

      final bytes = const Utf8Encoder().convert(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download',
            'approved-proposals-${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();

      html.document.body?.append(anchor);
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Approved proposals exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
