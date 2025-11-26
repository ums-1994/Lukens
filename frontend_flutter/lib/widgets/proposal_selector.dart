import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../theme/premium_theme.dart';
import 'custom_scrollbar.dart';

class ProposalSelector extends StatefulWidget {
  final String title;
  final String description;
  final void Function(Map<String, dynamic>) onSelect;
  final Future<void> Function(Map<String, dynamic>)? onRunRiskGate;

  const ProposalSelector({
    super.key,
    required this.title,
    required this.description,
    required this.onSelect,
    this.onRunRiskGate,
  });

  @override
  State<ProposalSelector> createState() => _ProposalSelectorState();
}

class _ProposalSelectorState extends State<ProposalSelector> {
  bool _loading = false;
  bool _requestedFetch = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedFetch) {
      _requestedFetch = true;
      _loadProposals();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProposals() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().fetchProposals();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final proposals = app.proposals;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (proposals.isEmpty) {
      return _buildEmptyState();
    }

    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: CustomScrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Premium header section with glass effect
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: PremiumTheme.purpleGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                                height: 1.4,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ...proposals.map((proposal) => _buildProposalCard(proposal)).toList(),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PremiumTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: PremiumTheme.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to Load Proposals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
        Text(
              _error ?? 'An error occurred while loading proposals',
          textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
        ),
            const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loadProposals,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Retry',
                style: TextStyle(decoration: TextDecoration.none),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
        ),
      ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PremiumTheme.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 64,
                color: PremiumTheme.purple,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Proposals Available',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
        const SizedBox(height: 12),
        const Text(
              'Create a draft proposal first, then return here to manage governance and run AI risk checks.',
          textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
        ),
            const SizedBox(height: 32),
        ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/proposals'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Create New Proposal',
                style: TextStyle(decoration: TextDecoration.none),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
        ),
      ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is String) {
      try {
        final parsed = DateTime.parse(date);
        final now = DateTime.now();
        final difference = now.difference(parsed);
        
        if (difference.inDays == 0) {
          return 'Today, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } else if (difference.inDays == 1) {
          return 'Yesterday, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else {
          return '${parsed.day}/${parsed.month}/${parsed.year}';
        }
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return PremiumTheme.purple;
      case 'pending':
      case 'pending approval':
        return PremiumTheme.orange;
      case 'sent':
      case 'sent to client':
        return PremiumTheme.pink;
      case 'approved':
        return PremiumTheme.success;
      case 'declined':
      case 'rejected':
        return PremiumTheme.error;
      default:
        return Colors.white70;
    }
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    final title = proposal['title'] ?? 'Untitled Proposal';
    final status = (proposal['status'] ?? 'Draft').toString();
    final client = proposal['client_name'] ??
        proposal['client'] ??
        proposal['client_email'] ??
        'Client not set';
    final updatedAt =
        proposal['updated_at'] ?? proposal['updatedAt'] ?? proposal['created_at'];

    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Padding(
            padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 1.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                // Title
            Text(
              title,
              style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.2,
                    decoration: TextDecoration.none,
              ),
            ),
                const SizedBox(height: 20),
                // Info Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.business_center_outlined,
                        label: 'Client',
                        value: client,
                        iconColor: PremiumTheme.cyan,
                      ),
            ),
            if (updatedAt != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.schedule_outlined,
                          label: 'Updated',
                          value: _formatDate(updatedAt),
                          iconColor: PremiumTheme.teal,
                        ),
              ),
            ],
                  ],
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
              children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: PremiumTheme.purpleGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: PremiumTheme.purple.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.playlist_add_check, size: 20),
                          label: const Text(
                            'Select for Governance',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                  onPressed: () => widget.onSelect(
                      Map<String, dynamic>.from(proposal)),
                ),
                      ),
                    ),
                    if (widget.onRunRiskGate != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.shield_outlined, size: 20),
                            label: const Text(
                              'Run AI Risk Gate',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                    onPressed: () =>
                        widget.onRunRiskGate?.call(Map<String, dynamic>.from(proposal)),
                  ),
                        ),
                      ),
                    ],
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

}




