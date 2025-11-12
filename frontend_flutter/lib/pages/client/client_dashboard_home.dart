import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'client_proposal_viewer.dart';
import '../../theme/premium_theme.dart';

class ClientDashboardHome extends StatefulWidget {
  const ClientDashboardHome({super.key});

  @override
  State<ClientDashboardHome> createState() => _ClientDashboardHomeState();
}

class _ClientDashboardHomeState extends State<ClientDashboardHome> {
  bool _isLoading = true;
  String? _error;
  String? _accessToken;
  String? _clientEmail;
  List<Map<String, dynamic>> _proposals = [];
  Map<String, int> _statusCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'viewed': 0,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractTokenAndLoad();
    });
  }

  void _extractTokenAndLoad() {
    String? token;

    try {
      final currentUrl = web.window.location.href;
      final uri = Uri.parse(currentUrl);

      // Try multiple ways to extract token
      token = uri.queryParameters['token'];

      if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
        final fragment = uri.fragment;
        if (fragment.contains('token=')) {
          final queryStart = fragment.indexOf('?');
          if (queryStart != -1) {
            final queryString = fragment.substring(queryStart + 1);
            final params = Uri.splitQueryString(queryString);
            token = params['token'];
          }
        }
      }

      if (token == null || token.isEmpty) {
        final hash = web.window.location.hash;
        if (hash.contains('token=')) {
          final tokenMatch = RegExp(r'token=([^&]+)').firstMatch(hash);
          if (tokenMatch != null) {
            token = tokenMatch.group(1);
          }
        }
      }
    } catch (e) {
      print('❌ Error parsing URL: $e');
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _accessToken = token;
    });

    _loadClientProposals();
  }

  Future<void> _loadClientProposals() async {
    if (_accessToken == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/client/proposals?token=$_accessToken'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _clientEmail = data['client_email'];
          _proposals = (data['proposals'] as List)
              .map((p) => Map<String, dynamic>.from(p))
              .toList();

          // Calculate status counts
          _statusCounts = {
            'pending': 0,
            'approved': 0,
            'rejected': 0,
            'viewed': 0,
          };

          for (var proposal in _proposals) {
            final status = (proposal['status'] as String? ?? '').toLowerCase();
            if (status.contains('pending') ||
                status.contains('sent to client')) {
              _statusCounts['pending'] = (_statusCounts['pending'] ?? 0) + 1;
            } else if (status.contains('approved') ||
                status.contains('signed')) {
              _statusCounts['approved'] = (_statusCounts['approved'] ?? 0) + 1;
            } else if (status.contains('declined') ||
                status.contains('rejected')) {
              _statusCounts['rejected'] = (_statusCounts['rejected'] ?? 0) + 1;
            } else if (status.contains('viewed')) {
              _statusCounts['viewed'] = (_statusCounts['viewed'] ?? 0) + 1;
            }
          }

          _isLoading = false;
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _error = error['detail'] ?? 'Failed to load proposals';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _openProposal(Map<String, dynamic> proposal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientProposalViewer(
          proposalId: proposal['id'],
          accessToken: _accessToken!,
        ),
      ),
    ).then((_) {
      // Reload proposals when returning
      _loadClientProposals();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your proposals...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadClientProposals(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // Header
            _buildHeader(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  _buildStatsCards(),

                  const SizedBox(height: 32),

                  // Proposals Table
                  _buildProposalsSection(),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client Portal',
                  style: PremiumTheme.titleLarge.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back, ${_clientEmail ?? 'Client'}',
                  style: PremiumTheme.bodyMedium.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadClientProposals,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending Review',
            _statusCounts['pending'].toString(),
            Icons.pending_actions,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approved',
            _statusCounts['approved'].toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Rejected',
            _statusCounts['rejected'].toString(),
            Icons.cancel,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Proposals',
            _proposals.length.toString(),
            Icons.description,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    // Map colors to gradients
    Gradient gradient;
    if (color == Colors.orange) {
      gradient = PremiumTheme.orangeGradient;
    } else if (color == Colors.green) {
      gradient = PremiumTheme.tealGradient;
    } else if (color == Colors.red) {
      gradient = PremiumTheme.redGradient;
    } else {
      gradient = PremiumTheme.blueGradient;
    }
    
    return PremiumStatCard(
      title: title,
      value: value,
      icon: icon,
      gradient: gradient,
    );
  }

  Widget _buildProposalsSection() {
    return GlassContainer(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'Your Proposals',
                  style: PremiumTheme.titleMedium.copyWith(fontSize: 22),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: PremiumTheme.glassWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PremiumTheme.glassWhiteBorder,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_proposals.length} ${_proposals.length == 1 ? 'proposal' : 'proposals'}',
                    style: PremiumTheme.bodyMedium.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  PremiumTheme.glassWhiteBorder,
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Table
          if (_proposals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No proposals yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF8F9FA)),
                columns: const [
                  DataColumn(
                      label: Text('Proposal',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Status',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Last Updated',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Action',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _proposals.map((proposal) {
                  return DataRow(cells: [
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              proposal['title'] ?? 'Untitled',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${proposal['id']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                        _buildStatusBadge(proposal['status'] ?? 'Unknown')),
                    DataCell(
                      Text(
                        _formatDate(proposal['updated_at']),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _openProposal(proposal),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    final statusLower = status.toLowerCase();
    if (statusLower.contains('pending') ||
        statusLower.contains('sent to client')) {
      color = Colors.orange;
      icon = Icons.pending;
    } else if (statusLower.contains('approved') ||
        statusLower.contains('signed')) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (statusLower.contains('declined') ||
        statusLower.contains('rejected')) {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.blue;
      icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      return '${dt.day} ${_getMonth(dt.month)} ${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _getMonth(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }
}
