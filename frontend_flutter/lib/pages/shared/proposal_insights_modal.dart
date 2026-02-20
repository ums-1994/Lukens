import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';

class ProposalInsightsModal extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;

  const ProposalInsightsModal({
    super.key,
    required this.proposalId,
    required this.proposalTitle,
  });

  @override
  State<ProposalInsightsModal> createState() => _ProposalInsightsModalState();
}

class _ProposalInsightsModalState extends State<ProposalInsightsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final app = context.read<AppState>();
      final analytics = await app.getProposalAnalytics(widget.proposalId);
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PremiumTheme.info,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proposal Insights',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.proposalTitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: Colors.grey[100],
              child: TabBar(
                controller: _tabController,
                labelColor: PremiumTheme.info,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: PremiumTheme.info,
                tabs: const [
                  Tab(text: 'Activity'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAnalytics,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildActivityTab(),
                            _buildAnalyticsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    final events = _analytics?['events'] as List? ?? [];

    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index] as Map<String, dynamic>;
        return _buildActivityItem(event);
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> event) {
    final eventType = event['event_type'] as String? ?? 'unknown';
    final createdAt = event['created_at'] as String?;
    final metadata = event['metadata'] as Map? ?? {};
    final clientName = event['client_name'] as String? ?? 'Client';

    String eventDescription = _getEventDescription(eventType, metadata);
    String timeAgo = _formatTimeAgo(createdAt);

    IconData icon;
    Color iconColor;

    switch (eventType) {
      case 'open':
        icon = Icons.visibility;
        iconColor = PremiumTheme.info;
        break;
      case 'close':
        icon = Icons.close;
        iconColor = Colors.grey;
        break;
      case 'download':
        icon = Icons.download;
        iconColor = PremiumTheme.teal;
        break;
      case 'sign':
        icon = Icons.draw;
        iconColor = PremiumTheme.success;
        break;
      case 'comment':
        icon = Icons.comment;
        iconColor = PremiumTheme.orange;
        break;
      case 'view_section':
        icon = Icons.article;
        iconColor = PremiumTheme.purple;
        break;
      default:
        icon = Icons.circle;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventDescription,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeAgo â€¢ $clientName',
                  style: TextStyle(
                    color: Colors.grey[600],
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

  String _getEventDescription(String eventType, Map metadata) {
    switch (eventType) {
      case 'open':
        return 'Client opened the document';
      case 'close':
        return 'Client closed the document';
      case 'download':
        return 'Client downloaded PDF';
      case 'sign':
        return 'Client signed the proposal';
      case 'comment':
        return 'Client added a comment';
      case 'view_section':
        final section = metadata['section'] as String?;
        final duration = metadata['duration'] as int?;
        if (section != null && duration != null) {
          return 'Client viewed "$section" for ${duration}s';
        }
        return 'Client viewed a section';
      default:
        return 'Client activity: $eventType';
    }
  }

  Widget _buildAnalyticsTab() {
    final analytics = _analytics?['analytics'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Time Spent',
                  analytics['total_time_formatted'] as String? ?? '0s',
                  Icons.access_time,
                  PremiumTheme.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Views',
                  (analytics['views'] ?? 0).toString(),
                  Icons.visibility,
                  PremiumTheme.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Downloads',
                  (analytics['downloads'] ?? 0).toString(),
                  Icons.download,
                  PremiumTheme.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Sessions',
                  (analytics['sessions_count'] ?? 0).toString(),
                  Icons.history,
                  PremiumTheme.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Details
          _buildDetailRow('First Opened', _formatDate(analytics['first_open'])),
          const SizedBox(height: 12),
          _buildDetailRow('Last Opened', _formatDate(analytics['last_open'])),
          const SizedBox(height: 12),
          _buildDetailRow('Signs', (analytics['signs'] ?? 0).toString()),
          const SizedBox(height: 12),
          _buildDetailRow('Comments', (analytics['comments'] ?? 0).toString()),

          // Section Times
          if (analytics['section_times'] != null &&
              (analytics['section_times'] as Map).isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Time by Section',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...(analytics['section_times'] as Map<String, dynamic>)
                .entries
                .map((entry) => _buildSectionTimeItem(entry.key, entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTimeItem(String section, dynamic seconds) {
    final duration = _formatDuration(seconds is int ? seconds : 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            section,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            duration,
            style: TextStyle(color: PremiumTheme.info),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return 'Unknown time';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Never';
    if (date is String) {
      try {
        final dt = DateTime.parse(date);
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes < 60) {
      return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}
