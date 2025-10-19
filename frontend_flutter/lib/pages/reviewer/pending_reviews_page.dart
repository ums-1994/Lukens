import 'package:flutter/material.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';
import '../../services/currency_service.dart';
import '../../widgets/currency_picker.dart';

class PendingReviewsPage extends StatefulWidget {
  const PendingReviewsPage({super.key});

  @override
  State<PendingReviewsPage> createState() => _PendingReviewsPageState();
}

class _PendingReviewsPageState extends State<PendingReviewsPage> {
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _pendingReviews = [
    {
      'id': '1',
      'title': 'Q4 Marketing Campaign Proposal',
      'client': 'TechCorp Inc.',
      'author': 'Sarah Johnson',
      'priority': 'High',
      'dueDate': '2024-01-20',
      'status': 'Pending Review',
      'value': 45000,
      'createdDate': '2024-01-15',
    },
    {
      'id': '2',
      'title': 'Software Development SOW',
      'client': 'StartupXYZ',
      'author': 'Mike Wilson',
      'priority': 'Medium',
      'dueDate': '2024-01-22',
      'status': 'Under Review',
      'value': 78500,
      'createdDate': '2024-01-16',
    },
    {
      'id': '3',
      'title': 'Consulting Services Agreement',
      'client': 'Enterprise Solutions',
      'author': 'Emily Davis',
      'priority': 'Low',
      'dueDate': '2024-01-25',
      'status': 'Pending Review',
      'value': 32000,
      'createdDate': '2024-01-17',
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
              'Pending Reviews',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Review and approve proposals awaiting your attention',
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
                  child: _buildStatCard('Total Pending', '12', const Color(0xFFE9293A)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('High Priority', '3', const Color(0xFFFFD700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Overdue', '1', const Color(0xFF14B3BB)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Completed Today', '5', const Color(0xFF00D4FF)),
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
                        hintText: 'Search proposals...',
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
                    items: ['All', 'High Priority', 'Medium Priority', 'Low Priority', 'Overdue']
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

            // Reviews List
            ..._getFilteredReviews().map((review) => _buildReviewCard(review)).toList(),
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

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        onTap: () => _openReview(review),
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
                        review['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Client: ${review['client']} • Author: ${review['author']}',
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
                    color: _getPriorityColor(review['priority']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getPriorityColor(review['priority'])),
                  ),
                  child: Text(
                    review['priority'],
                    style: TextStyle(
                      color: _getPriorityColor(review['priority']),
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
                _buildCurrencyChip('Value', review['value'], const Color(0xFF00D4FF)),
                const SizedBox(width: 12),
                _buildInfoChip('Due Date', review['dueDate'], const Color(0xFFE9293A)),
                const SizedBox(width: 12),
                _buildInfoChip('Status', review['status'], const Color(0xFFFFD700)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _rejectReview(review),
                  child: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _approveReview(review),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B3BB),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Review', style: TextStyle(color: Colors.white)),
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFE9293A);
      case 'Medium':
        return const Color(0xFFFFD700);
      case 'Low':
        return const Color(0xFF14B3BB);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getFilteredReviews() {
    return _pendingReviews.where((review) {
      final matchesSearch = review['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           review['client'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' || review['priority'] == _selectedFilter.replaceAll(' Priority', '');
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _openReview(Map<String, dynamic> review) {
    Navigator.pushNamed(context, '/review_queue', arguments: review);
  }

  void _approveReview(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: const Text('Approve Review', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to approve "${review['title']}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pendingReviews.removeWhere((r) => r['id'] == review['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Proposal approved successfully'),
                  backgroundColor: Color(0xFF14B3BB),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B3BB)),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _rejectReview(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: const Text('Reject Review', style: TextStyle(color: Colors.white)),
        content: const Text('Please provide a reason for rejection:', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pendingReviews.removeWhere((r) => r['id'] == review['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Proposal rejected'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
