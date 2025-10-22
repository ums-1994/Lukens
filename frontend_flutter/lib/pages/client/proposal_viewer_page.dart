import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ProposalViewerPage extends StatefulWidget {
  final String documentName;
  final String companyName;
  final String selectedClient;
  final List<String> selectedSnapshots;

  const ProposalViewerPage({
    super.key,
    required this.documentName,
    required this.companyName,
    required this.selectedClient,
    required this.selectedSnapshots,
  });

  @override
  State<ProposalViewerPage> createState() => _ProposalViewerPageState();
}

class _ProposalViewerPageState extends State<ProposalViewerPage> {
  List<dynamic> _versions = [];
  bool _loadingVersions = false;

  Future<void> _openVersionHistory() async {
    final token = AuthService.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view versions')),
      );
      return;
    }
    setState(() { _loadingVersions = true; });
    try {
      // NOTE: In this demo we don't have a real proposalId bound here.
      // If you pass the proposalId into this page, replace 'demo' accordingly.
      // For now, show empty with hint.
      _versions = await ApiService.listProposalVersions('demo-proposal-id', token);
    } catch (_) {
      _versions = [];
    } finally {
      setState(() { _loadingVersions = false; });
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Version History'),
          content: SizedBox(
            width: 480,
            child: _loadingVersions
                ? const Center(child: CircularProgressIndicator())
                : _versions.isEmpty
                    ? const Text('No versions found. (Bind proposalId to enable)')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Latest first',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 300,
                            child: ListView.builder(
                              itemCount: _versions.length,
                              itemBuilder: (context, i) {
                                final v = _versions[i] as Map<String,dynamic>;
                                return ListTile(
                                  dense: true,
                                  title: Text('v${v['version_number']}  •  ${v['created_at'] ?? ''}')
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Column(
        children: [
          // Header
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Proposal Viewer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _openVersionHistory,
                        icon: const Icon(Icons.history, color: Colors.white),
                        tooltip: 'Version History',
                      ),
                      IconButton(
                        onPressed: () {
                          _downloadProposal();
                        },
                        icon: const Icon(Icons.download, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () {
                          _printProposal();
                        },
                        icon: const Icon(Icons.print, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Main Content - Full Document
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  width: 800,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: _buildFullProposal(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullProposal() {
    return Column(
      children: [
        // Header Section
        _buildHeaderSection(),
        // Executive Summary
        if (widget.selectedSnapshots.contains('executive-summary'))
          _buildSection('Executive Summary', _getExecutiveSummaryContent()),
        // Proposed Solution
        if (widget.selectedSnapshots.contains('proposed-solution'))
          _buildSection('Proposed Solution', _getProposedSolutionContent()),
        // Investment Summary
        if (widget.selectedSnapshots.contains('pricing-table'))
          _buildPricingSection(),
        // Terms & Conditions
        if (widget.selectedSnapshots.contains('terms-conditions'))
          _buildSection('Terms & Conditions', _getTermsContent()),
        // Signatures
        if (widget.selectedSnapshots.contains('signature-section'))
          _buildSignatureSection(),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C3E50),
            const Color(0xFF2C3E50).withValues(alpha: 0.8)
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          // Content
          Container(
            padding: const EdgeInsets.all(35),
            child: Column(
              children: [
                // Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ProposeIt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                // Title
                Text(
                  widget.documentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                // Subtitle
                Text(
                  'Date: ${DateTime.now().toString().split(' ')[0]} | Proposal #: ${_generateProposalNumber()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                // Company and Client Info
                Row(
                  children: [
                    Expanded(child: _buildCompanyInfo()),
                    const SizedBox(width: 40),
                    Expanded(child: _buildClientInfo()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSectionIcon(title),
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Investment Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPricingTable(),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Signatures',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSignatureBox('For ${widget.companyName}')),
              const SizedBox(width: 24),
              Expanded(
                  child: _buildSignatureBox('For ${widget.selectedClient}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'From:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.companyName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on, '123 Business Ave, Suite 100'),
          _buildInfoRow(Icons.location_on, 'New York, NY 10001'),
          _buildInfoRow(Icons.email, 'contact@company.com'),
          _buildInfoRow(Icons.phone, '(555) 123-4567'),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'To:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.selectedClient,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Attn: John Smith, Procurement Manager',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on, '456 Corporate Blvd'),
          _buildInfoRow(Icons.location_on, 'Chicago, IL 60601'),
          _buildInfoRow(Icons.email, 'john.smith@client.com'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFDDD)),
        children: [
          // Header
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
            children: [
              _buildTableCell('Item', isHeader: true),
              _buildTableCell('Description', isHeader: true),
              _buildTableCell('Quantity', isHeader: true),
              _buildTableCell('Unit Price', isHeader: true),
              _buildTableCell('Total', isHeader: true),
            ],
          ),
          // Data rows
          _buildTableRow('Software License', 'Enterprise Plan (Annual)', '1',
              '\$9,999.00', '\$9,999.00'),
          _buildTableRow('Implementation', 'System Setup & Integration', '1',
              '\$4,500.00', '\$4,500.00'),
          _buildTableRow('Training', 'On-site Training Sessions', '3',
              '\$1,200.00', '\$3,600.00'),
          _buildTableRow('Support', 'Premium Support (Annual)', '1',
              '\$2,000.00', '\$2,000.00'),
          // Subtotal
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFE8F4FC)),
            children: [
              _buildTableCell('Subtotal'),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell('\$20,099.00', isBold: true),
            ],
          ),
          // Tax
          TableRow(
            children: [
              _buildTableCell('Tax'),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell('\$1,607.92'),
            ],
          ),
          // Total
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFE8F4FC)),
            children: [
              _buildTableCell('Total'),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell('\$21,706.92', isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String item, String description, String quantity,
      String unitPrice, String total) {
    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: [
        _buildTableCell(item),
        _buildTableCell(description),
        _buildTableCell(quantity),
        _buildTableCell(unitPrice),
        _buildTableCell(total),
      ],
    );
  }

  Widget _buildTableCell(String text,
      {bool isHeader = false, bool isBold = false}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: TextStyle(
            color: isHeader ? Colors.white : const Color(0xFF2C3E50),
            fontWeight:
                isHeader || isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isHeader ? 16 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureBox(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCC), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'Signature Area',
              style: TextStyle(
                color: Color(0xFF999),
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text('Name: _________________________'),
        const Text('Title: _________________________'),
        const Text('Date: _________________________'),
      ],
    );
  }

  IconData _getSectionIcon(String title) {
    switch (title.toLowerCase()) {
      case 'executive summary':
        return Icons.description;
      case 'proposed solution':
        return Icons.lightbulb;
      case 'terms & conditions':
        return Icons.assignment;
      default:
        return Icons.text_fields;
    }
  }

  String _generateProposalNumber() {
    final now = DateTime.now();
    return 'PROP-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getExecutiveSummaryContent() {
    return 'Thank you for the opportunity to submit this proposal. We have carefully reviewed your requirements and are confident that our solution will meet your needs effectively and efficiently. Our team brings extensive experience in delivering similar projects and we are committed to providing exceptional value and results.';
  }

  String _getProposedSolutionContent() {
    return 'Based on our analysis, we recommend the following approach:\n\n• Implementation of our premium software platform\n• Customization to integrate with your existing systems\n• Comprehensive training for your team members\n• Ongoing support and maintenance\n• Regular progress reporting and communication\n\nThis solution has been proven to deliver measurable results and will provide you with a competitive advantage in your market.';
  }

  String _getTermsContent() {
    return 'This proposal is valid for 30 days from the date of issue. Payment terms are 50% upon signing and 50% upon completion. The project timeline is 8-10 weeks from project kickoff.\n\nWe guarantee our work and provide a 12-month warranty on all deliverables. Any changes to the scope of work will be documented and may result in additional costs.';
  }

  void _downloadProposal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading proposal as PDF...'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  void _printProposal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening print dialog...'),
        backgroundColor: Color(0xFF3498DB),
      ),
    );
  }
}
