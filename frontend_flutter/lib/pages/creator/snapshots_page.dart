import 'package:flutter/material.dart';
import 'editing_page.dart';

class SnapshotsPage extends StatefulWidget {
  final String documentName;
  final String companyName;
  final String selectedClient;

  const SnapshotsPage({
    super.key,
    required this.documentName,
    required this.companyName,
    required this.selectedClient,
  });

  @override
  State<SnapshotsPage> createState() => _SnapshotsPageState();
}

class _SnapshotsPageState extends State<SnapshotsPage> {
  List<String> _selectedSnapshots = [];

  // Template blocks based on the template structure
  final List<Map<String, dynamic>> _templateBlocks = [
    {
      'id': 'header',
      'title': 'Header Section',
      'description': 'Document title, company info, and client details',
      'type': 'header',
      'content':
          'Professional Business Proposal\nDate: October 25, 2023 | Proposal #: ACME-2023-089',
      'thumbnail':
          'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': 'executive-summary',
      'title': 'Executive Summary',
      'description': 'Key highlights and overview of the proposal',
      'type': 'section',
      'content':
          'Thank you for the opportunity to submit this proposal. We have carefully reviewed your requirements and are confident that our solution will meet your needs effectively and efficiently.',
      'thumbnail':
          'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': 'proposed-solution',
      'title': 'Proposed Solution',
      'description': 'Detailed approach and methodology',
      'type': 'section',
      'content':
          'Based on our analysis, we recommend the following approach:\n• Implementation of our premium software platform\n• Customization to integrate with your existing systems\n• Comprehensive training for your team members\n• Ongoing support and maintenance',
      'thumbnail':
          'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': 'pricing-table',
      'title': 'Investment Summary',
      'description': 'Pricing details and cost breakdown',
      'type': 'table',
      'content':
          'Software License: \$9,999.00\nImplementation: \$4,500.00\nTraining: \$3,600.00\nSupport: \$2,000.00\nTotal: \$21,706.92',
      'thumbnail':
          'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': 'terms-conditions',
      'title': 'Terms & Conditions',
      'description': 'Legal terms and project agreements',
      'type': 'section',
      'content':
          'This proposal is valid for 30 days from the date of issue. Payment terms are 50% upon signing and 50% upon completion. The project timeline is 8-10 weeks from project kickoff.',
      'thumbnail':
          'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': 'signature-section',
      'title': 'Signatures',
      'description': 'Digital signature section for both parties',
      'type': 'signature',
      'content':
          'Digital signature section for both parties to sign the agreement.',
      'thumbnail':
          'https://images.unsplash.com/photo-1568992687947-868a62a9f521?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
    },
  ];

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
                    'Document Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Step 2 of 3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main Content - Full Document Preview
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
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: _buildFullDocumentPreview(),
                ),
              ),
            ),
          ),
          // Footer with Continue button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C757D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to editing page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditingPage(
                            documentName: widget.documentName,
                            companyName: widget.companyName,
                            selectedClient: widget.selectedClient,
                            selectedSnapshots: _selectedSnapshots,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullDocumentPreview() {
    return Column(
      children: [
        // Document blocks
        ..._templateBlocks.map((block) => _buildDocumentBlock(block)).toList(),
      ],
    );
  }

  Widget _buildDocumentBlock(Map<String, dynamic> block) {
    final isSelected = _selectedSnapshots.contains(block['id']);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSnapshots.remove(block['id']);
            } else {
              _selectedSnapshots.add(block['id']);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: _buildBlockContent(block, isSelected),
      ),
    );
  }

  Widget _buildBlockContent(Map<String, dynamic> block, bool isSelected) {
    switch (block['type']) {
      case 'header':
        return _buildHeaderBlock(block, isSelected);
      case 'section':
        return _buildSectionBlock(block, isSelected);
      case 'table':
        return _buildTableBlock(block, isSelected);
      case 'signature':
        return _buildSignatureBlock(block, isSelected);
      default:
        return _buildTextBlock(block, isSelected);
    }
  }

  Widget _buildHeaderBlock(Map<String, dynamic> block, bool isSelected) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C3E50),
            const Color(0xFF2C3E50).withOpacity(0.8)
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Background Image Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(block['thumbnail']),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    // Fallback to gradient if image fails
                  },
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
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
                  block['title'],
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
                  block['content'],
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
                    Expanded(
                      child: _buildCompanyInfo(),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: _buildClientInfo(),
                    ),
                  ],
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SELECTED - CLICK TO EDIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBlock(Map<String, dynamic> block, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSectionIcon(block['title']),
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                block['title'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            block['content'],
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

  Widget _buildTableBlock(Map<String, dynamic> block, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                block['title'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildSignatureBlock(Map<String, dynamic> block, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                block['title'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSignatureBox('For Acme Inc.'),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSignatureBox('For Global Enterprises'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextBlock(Map<String, dynamic> block, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Text Block',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            block['content'],
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1E293B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
          const Text(
            'Acme Inc.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildEditableInfoRow(Icons.location_on,
              '123 Business Ave, Suite 100', 'company_address1'),
          _buildEditableInfoRow(
              Icons.location_on, 'New York, NY 10001', 'company_address2'),
          _buildEditableInfoRow(
              Icons.email, 'contact@acmeinc.com', 'company_email'),
          _buildEditableInfoRow(Icons.phone, '(555) 123-4567', 'company_phone'),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
          const Text(
            'Global Enterprises',
            style: TextStyle(
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
          _buildEditableInfoRow(
              Icons.location_on, '456 Corporate Blvd', 'client_address1'),
          _buildEditableInfoRow(
              Icons.location_on, 'Chicago, IL 60601', 'client_address2'),
          _buildEditableInfoRow(
              Icons.email, 'john.smith@globalent.com', 'client_email'),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(IconData icon, String text, String textId) {
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
            color: Colors.black.withOpacity(0.1),
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
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
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
}
