import 'package:flutter/material.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.dashboard_outlined,
                    size: 28,
                    color: Color(0xFF2C3E50),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Proposal Status Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const Spacer(),
                  if (_isRefreshing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Track and manage proposals through their lifecycle',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getStatusDescription(status),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Status Filter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  underline: Container(),
                  items: _statusFilters.map((String filter) {
                    return DropdownMenuItem<String>(
                      value: filter,
                      child: Text(filter),
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
          // Sort By
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  underline: Container(),
                  items: _sortOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
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
          // Refresh Button
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsList(List<dynamic> proposals) {
    if (proposals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'All'
                    ? 'No proposals found'
                    : 'No $_selectedFilter proposals found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first proposal to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proposals (${proposals.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 12),
        ...proposals.map((proposal) => _buildProposalCard(proposal)).toList(),
      ],
    );
  }

  Widget _buildProposalCard(dynamic proposal) {
    final status = proposal['status'] ?? 'Draft';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Quick Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  // Handle quick actions
                  _handleQuickAction(value, proposal);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Archive'),
                      ],
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Proposal Title
          Text(
            proposal['title'] ?? 'Untitled Proposal',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          // Client and Date
          Row(
            children: [
              Icon(Icons.business_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                proposal['clientName'] ?? 'No Client',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 20),
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                _formatDate(DateTime.tryParse(proposal['createdAt'] ?? '') ??
                    DateTime.now()),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar (if in review)
          if (status == 'In Review') ...[
            LinearProgressIndicator(
              value: 0.6, // Mock progress
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Review in progress...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleQuickAction(String action, dynamic proposal) {
    switch (action) {
      case 'view':
        // Navigate to proposal view
        break;
      case 'edit':
        // Navigate to proposal edit
        break;
      case 'duplicate':
        // Duplicate proposal
        break;
      case 'archive':
        // Archive proposal
        break;
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
}
