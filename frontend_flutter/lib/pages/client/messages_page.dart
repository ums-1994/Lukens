import 'package:flutter/material.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String _selectedTab = 'Inbox';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'sender': 'Sarah Johnson',
      'subject': 'Proposal Update - Q4 Marketing Campaign',
      'preview': 'Hi! I wanted to update you on the progress of your Q4 marketing campaign proposal...',
      'timestamp': '2 hours ago',
      'isRead': false,
      'priority': 'High',
    },
    {
      'id': '2',
      'sender': 'Mike Wilson',
      'subject': 'Contract Review Request',
      'preview': 'Please review the attached contract for the software development project...',
      'timestamp': '1 day ago',
      'isRead': true,
      'priority': 'Medium',
    },
    {
      'id': '3',
      'sender': 'Emily Davis',
      'subject': 'Meeting Schedule',
      'preview': 'Let\'s schedule a meeting to discuss the next phase of our project...',
      'timestamp': '3 days ago',
      'isRead': true,
      'priority': 'Low',
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
              'Messages',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Communicate with your team and stay updated',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFB0B6BB),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 32),

            // Tabs
            LiquidGlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTab('Inbox', 'Inbox'),
                  ),
                  Expanded(
                    child: _buildTab('Sent', 'Sent'),
                  ),
                  Expanded(
                    child: _buildTab('Drafts', 'Drafts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Search Bar
            LiquidGlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(20),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
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
            const SizedBox(height: 24),

            // Compose Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _composeMessage,
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Compose', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE9293A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Messages List
            ..._getFilteredMessages().map((message) => _buildMessageCard(message)).toList(),
            const SizedBox(height: 20),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE9293A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        onTap: () => _openMessage(message),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: _getPriorityColor(message['priority']),
              child: Text(
                message['sender'][0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Message Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message['sender'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: message['isRead'] ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        message['timestamp'],
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message['subject'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: message['isRead'] ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message['preview'],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!message['isRead'])
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9293A),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
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

  List<Map<String, dynamic>> _getFilteredMessages() {
    return _messages.where((message) {
      final matchesSearch = message['subject'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           message['sender'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           message['preview'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();
  }

  void _openMessage(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: Text(message['subject'], style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${message['sender']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Time: ${message['timestamp']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text(
              'Message content would be displayed here...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9293A)),
            child: const Text('Reply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _composeMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: const Text('Compose Message', style: TextStyle(color: Colors.white)),
        content: const Text('Message composer would open here', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9293A)),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
