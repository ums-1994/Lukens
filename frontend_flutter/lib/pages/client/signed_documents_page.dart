import 'package:flutter/material.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';
import '../../services/currency_service.dart';
import '../../widgets/currency_picker.dart';

class SignedDocumentsPage extends StatefulWidget {
  const SignedDocumentsPage({super.key});

  @override
  State<SignedDocumentsPage> createState() => _SignedDocumentsPageState();
}

class _SignedDocumentsPageState extends State<SignedDocumentsPage> {
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _signedDocuments = [
    {
      'id': '1',
      'title': 'Q4 Marketing Campaign Proposal',
      'client': 'TechCorp Inc.',
      'signedDate': '2024-01-15',
      'status': 'Active',
      'value': 45000,
      'expiryDate': '2024-12-31',
      'documentType': 'Proposal',
    },
    {
      'id': '2',
      'title': 'Software Development SOW',
      'client': 'StartupXYZ',
      'signedDate': '2024-01-10',
      'status': 'Active',
      'value': 78500,
      'expiryDate': '2024-06-30',
      'documentType': 'SOW',
    },
    {
      'id': '3',
      'title': 'Consulting Services Agreement',
      'client': 'Enterprise Solutions',
      'signedDate': '2024-01-05',
      'status': 'Expired',
      'value': 32000,
      'expiryDate': '2024-01-31',
      'documentType': 'Agreement',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Signed Documents',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View and manage your signed contracts and agreements',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFB0B6BB),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 32),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total Signed', '12', const Color(0xFF14B3BB)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Active Contracts', '8', const Color(0xFF00D4FF)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Expiring Soon', '2', const Color(0xFFFFD700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Total Value', CurrencyService().formatLargeAmount(1200000), const Color(0xFFE9293A)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Filters
            LiquidGlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search documents...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.search, color: Colors.white60),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE9293A)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedFilter,
                    dropdownColor: const Color(0xFF1A1A1B),
                    style: const TextStyle(color: Colors.white),
                    items: ['All', 'Active', 'Expired', 'Expiring Soon']
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedFilter = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Documents List
            ..._getFilteredDocuments().map((document) => _buildDocumentCard(document)).toList(),
            const SizedBox(height: 20),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return LiquidGlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        onTap: () => _viewDocument(document),
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
                        document['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${document['documentType']} • Signed: ${document['signedDate']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(document['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(document['status'])),
                  ),
                  child: Text(
                    document['status'],
                    style: TextStyle(
                      color: _getStatusColor(document['status']),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCurrencyChip('Value', document['value'], const Color(0xFF00D4FF)),
                const SizedBox(width: 12),
                _buildInfoChip('Expires', document['expiryDate'], const Color(0xFFE9293A)),
                const SizedBox(width: 12),
                _buildInfoChip('Type', document['documentType'], const Color(0xFF14B3BB)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _downloadDocument(document),
                  icon: const Icon(Icons.download, color: Colors.white70, size: 18),
                  label: const Text('Download', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _viewDocument(document),
                  icon: const Icon(Icons.visibility, color: Colors.white, size: 18),
                  label: const Text('View', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B3BB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCurrencyChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          CurrencyDisplay(
            amount: value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return const Color(0xFF14B3BB);
      case 'Expired':
        return Colors.red;
      case 'Expiring Soon':
        return const Color(0xFFFFD700);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getFilteredDocuments() {
    return _signedDocuments.where((document) {
      final matchesSearch = document['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           document['documentType'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' || document['status'] == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _viewDocument(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: Text('View ${document['title']}', style: const TextStyle(color: Colors.white)),
        content: const Text('Document viewer would open here', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _downloadDocument(Map<String, dynamic> document) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${document['title']}...'),
        backgroundColor: const Color(0xFF14B3BB),
      ),
    );
  }
}
