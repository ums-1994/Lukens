import 'package:flutter/material.dart';

class ProposalViewerPage extends StatefulWidget {
  final Map<String, dynamic>? proposalData;
  final String? proposalId;
  final String? documentName;
  final String? companyName;
  final String? selectedClient;
  final List<dynamic>? selectedSnapshots;

  const ProposalViewerPage({
    super.key,
    this.proposalData,
    this.proposalId,
    this.documentName,
    this.companyName,
    this.selectedClient,
    this.selectedSnapshots,
  });

  @override
  State<ProposalViewerPage> createState() => _ProposalViewerPageState();
}

class _ProposalViewerPageState extends State<ProposalViewerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentName ??
            widget.proposalData?['title'] ??
            'Proposal Viewer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Proposal Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.documentName ??
                          widget.proposalData?['title'] ??
                          'Business Proposal',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Proposal ID: ${widget.proposalId ?? 'N/A'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            widget.proposalData?['status'] ?? 'Draft',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor:
                              _getStatusColor(widget.proposalData?['status']),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Created: ${_formatDate(widget.proposalData?['created_at'])}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Proposal Content
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Executive Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.proposalData?['executive_summary'] ??
                          'Thank you for the opportunity to submit this proposal. We have carefully reviewed your requirements and are confident that our solution will meet your needs effectively and efficiently.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Project Scope
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Scope',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.proposalData?['scope'] ??
                          'Based on our analysis, we recommend the following approach:\n\n• Implementation of our premium software platform\n• Customization to integrate with your existing systems\n• Comprehensive training for your team members\n• Ongoing support and maintenance',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Timeline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Timeline',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.proposalData?['timeline'] ??
                          'Project Timeline:\n\n• Week 1-2: Planning and setup\n• Week 3-6: Implementation and customization\n• Week 7-8: Testing and quality assurance\n• Week 9-10: Training and go-live\n• Week 11-12: Support and handover',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Investment
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Investment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.proposalData?['investment'] ??
                          'Software License: \$9,999.00\nImplementation: \$4,500.00\nTraining: \$3,600.00\nSupport: \$2,000.00\n\nTotal: \$21,706.92',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Terms
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms & Conditions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.proposalData?['terms'] ??
                          'This agreement is valid for 30 days from the proposal date. Payment terms: 50% upon contract signing, 50% upon project completion. All work is subject to our standard terms and conditions.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement print functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Print functionality not implemented yet'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Print'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'in review':
        return Colors.orange;
      case 'released':
        return Colors.blue;
      case 'signed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
