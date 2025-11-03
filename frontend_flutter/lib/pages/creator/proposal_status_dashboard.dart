// ignore_for_file: deprecated_member_use, dead_code
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';
import '../../api.dart';

class ProposalStatusDashboard extends StatefulWidget {
  const ProposalStatusDashboard({super.key});

  @override
  State<ProposalStatusDashboard> createState() =>
      _ProposalStatusDashboardState();
}

class _ProposalStatusDashboardState extends State<ProposalStatusDashboard>
    with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  String _sortBy = 'Date';
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _statusFilters = [
    'All',
    'Draft',
    'In Review',
    'Released',
    'Signed'
  ];
  final List<String> _sortOptions = ['Date', 'Client', 'Title', 'Status'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    final app = context.read<AppState>();
    await app.fetchProposals();

    setState(() {
      _isRefreshing = false;
    });
  }

  Map<String, int> _getStatusCounts(List<dynamic> proposals) {
    final counts = <String, int>{
      'Draft': 0,
      'In Review': 0,
      'Released': 0,
      'Signed': 0,
    };

    for (final proposal in proposals) {
      final status = proposal['status'] ?? 'Draft';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }

    return counts;
  }

  List<dynamic> _getFilteredProposals(List<dynamic> proposals) {
    List<dynamic> filtered = proposals;

    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered.where((p) => p['status'] == _selectedFilter).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'Date':
        filtered.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
          final dateB =
              DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        break;
      case 'Client':
        filtered.sort(
            (a, b) => (a['clientName'] ?? '').compareTo(b['clientName'] ?? ''));
        break;
      case 'Title':
        filtered.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
        break;
      case 'Status':
        filtered
            .sort((a, b) => (a['status'] ?? '').compareTo(b['status'] ?? ''));
        break;
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xFF6C757D); // Gray
      case 'In Review':
        return const Color(0xFFFD7E14); // Orange
      case 'Released':
        return const Color(0xFF0D6EFD); // Blue
      case 'Signed':
        return const Color(0xFF198754); // Green
      default:
        return const Color(0xFF6C757D);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Draft':
        return Icons.edit_outlined;
      case 'In Review':
        return Icons.visibility_outlined;
      case 'Released':
        return Icons.send_outlined;
      case 'Signed':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'Draft':
        return 'Being created or edited';
      case 'In Review':
        return 'Awaiting internal approval';
      case 'Released':
        return 'Sent to client';
      case 'Signed':
        return 'Client approved';
      default:
        return 'Unknown status';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final proposals = app.proposals;
    final statusCounts = _getStatusCounts(proposals);
    final filteredProposals = _getFilteredProposals(proposals);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: ClipRRect(
            // Added ClipRRect
            borderRadius: BorderRadius.circular(12), // Rounded corners for blur
            child: BackdropFilter(
              // Added BackdropFilter
              filter:
                  ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                      alpha: 0.12), // Translucent blackish background
                  borderRadius: BorderRadius.circular(
                      12), // Rounded corners for container
                  border: Border.all(
                      color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                      width: 1), // Red outline
                ),
                padding: const EdgeInsets.all(20), // Inner padding for content
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.dashboard_outlined,
                          size: 28,
                          color: Colors.white, // Changed text color to white
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Proposal Status Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Changed text color to white
                          ),
                        ),
                        const Spacer(),
                        if (_isRefreshing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(
                                    0xFFE9293A))), // Changed indicator color
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track and manage proposals through their lifecycle',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70, // Changed text color to white70
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Overview Cards
                    _buildStatusOverview(statusCounts),
                    const SizedBox(height: 24),

                    // Filters and Controls
                    _buildFiltersAndControls(),
                    const SizedBox(height: 20),

                    // Proposals List
                    _buildProposalsList(filteredProposals),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverview(Map<String, int> counts) {
    return Row(
      children: [
        Expanded(
          child:
              _buildStatusCard('Draft', counts['Draft']!, Icons.edit_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
              'In Review', counts['In Review']!, Icons.visibility_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
              'Released', counts['Released']!, Icons.send_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
              'Signed', counts['Signed']!, Icons.check_circle_outline),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String status, int count, IconData icon) {
    final color = _getStatusColor(status);
    return ClipRRect(
      // Added ClipRRect
      borderRadius: BorderRadius.circular(12), // Rounded corners for blur
      child: BackdropFilter(
        // Added BackdropFilter
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black
                .withValues(alpha: 0.12), // Translucent blackish background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                width: 1), // Red outline
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.05), // Adjusted shadow opacity
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(
                          alpha: 0.12), // Adjusted opacity to 0.12
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: color.withValues(
                              alpha: 0.5)), // Adjusted border opacity
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: color.withValues(
                                alpha: 0.7)), // Adjusted icon color
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color.withValues(
                                alpha: 0.9), // Adjusted text color
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Proposal Title
              Text(
                '$count $status Proposals',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // Changed text color to white
                ),
              ),
              const SizedBox(height: 8),
              // Client and Date
              Text(
                _getStatusDescription(status),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70, // Changed text color to white70
                ),
              ),
              const SizedBox(height: 12),
              // Progress Bar (if in review)
              if (status == 'In Review') ...[
                LinearProgressIndicator(
                  value: 0.6, // Mock progress
                  backgroundColor: Colors.white
                      .withValues(alpha: 0.2), // Adjusted background color
                  valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.8)), // Adjusted value color
                ),
                const SizedBox(height: 8),
                Text(
                  'Review in progress...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70, // Changed text color to white70
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersAndControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter by Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      underline: Container(),
                      dropdownColor: Colors.black.withValues(alpha: 0.8),
                      style: const TextStyle(color: Colors.white),
                      items: _statusFilters.map((String filter) {
                        return DropdownMenuItem<String>(
                          value: filter,
                          child: Text(filter,
                              style: TextStyle(
                                  color: filter == 'All' &&
                                          _selectedFilter == 'All'
                                      ? const Color(0xFFC10D00)
                                      : Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFilter = newValue!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      underline: Container(),
                      dropdownColor: Colors.black.withValues(alpha: 0.8),
                      style: const TextStyle(color: Colors.white),
                      items: _sortOptions.map((String option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option,
                              style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _sortBy = newValue!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProposalsList(List<dynamic> proposals) {
    if (proposals.isEmpty) {
      return ClipRRect(
        // Added ClipRRect
        borderRadius: BorderRadius.circular(12), // Rounded corners for blur
        child: BackdropFilter(
          // Added BackdropFilter
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.black
                  .withValues(alpha: 0.12), // Translucent blackish background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                  width: 1), // Red outline
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.05), // Adjusted shadow opacity
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.white70, // Changed icon color to white70
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'All'
                        ? 'No proposals found'
                        : 'No $_selectedFilter proposals found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white, // Changed text color to white
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first proposal to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70, // Changed text color to white70
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Proposals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Changed text color to white
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: proposals.length,
          itemBuilder: (context, index) {
            final proposal = proposals[index];
            final status = proposal['status'] ?? 'Draft';
            final statusColor = _getStatusColor(status);

            return ClipRRect(
              // Added ClipRRect
              borderRadius:
                  BorderRadius.circular(12), // Rounded corners for blur
              child: BackdropFilter(
                // Added BackdropFilter
                filter: ImageFilter.blur(
                    sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                        alpha: 0.12), // Translucent blackish background
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE9293A).withValues(alpha: 0.5),
                        width: 1), // Red outline
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.05), // Adjusted shadow opacity
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                              alpha: 0.12), // Adjusted opacity to 0.12
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(
                                  alpha: 0.5)), // Adjusted border opacity
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(status),
                                size: 16,
                                color: statusColor.withValues(
                                    alpha: 0.7)), // Adjusted icon color
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor.withValues(
                                    alpha: 0.9), // Adjusted text color
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Proposal Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proposal['title'] ?? 'Untitled Proposal',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    Colors.white, // Changed text color to white
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              proposal['clientName'] ?? 'No Client',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors
                                    .white70, // Changed text color to white70
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(DateTime.tryParse(
                                      proposal['createdAt'] ?? '') ??
                                  DateTime.now()),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors
                                    .white70, // Changed text color to white70
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Quick Actions
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
