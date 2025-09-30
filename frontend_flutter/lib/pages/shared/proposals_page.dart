import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';

class ProposalsPage extends StatefulWidget {
  @override
  _ProposalsPageState createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage> {
  String _filterStatus = 'All Statuses';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> proposals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProposals();
  }

  Future<void> _loadProposals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get Firebase token
      final user = FirebaseService.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        final data = await ApiService.getProposals(token!);
        setState(() {
          proposals = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading proposals: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSampleData() async {
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        final token = await user.getIdToken();

        // Call the sample data endpoint
        final response = await http.post(
          Uri.parse('http://localhost:8000/dev/sample-data'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'uid': user.uid,
          }),
        );

        if (response.statusCode == 200) {
          // Reload proposals after adding sample data
          await _loadProposals();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sample data added successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add sample data')),
          );
        }
      }
    } catch (e) {
      print('Error adding sample data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding sample data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ProposeIt'),
        backgroundColor: Color(0xFF2c3e50),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {},
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundColor: Color(0xFF4bc0c0),
              child: Text('JD', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proposals',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2c3e50),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage your proposals, create new ones, and track their status.',
                      style: TextStyle(
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Add sample data for testing
                        _addSampleData();
                      },
                      icon: Icon(Icons.data_object, size: 16),
                      label: Text('Add Sample Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF28a745),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to create new proposal
                        Navigator.pushNamed(context, '/compose');
                      },
                      icon: Icon(Icons.add, size: 16),
                      label: Text('New Proposal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4a6cf7),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24),

            // Filter and Search Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Proposals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2c3e50),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 200,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search proposals...',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide:
                                        BorderSide(color: Color(0xFFe2e8f0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide:
                                        BorderSide(color: Color(0xFFe2e8f0)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Color(0xFFe2e8f0)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _filterStatus,
                                    items: [
                                      'All Statuses',
                                      'Draft',
                                      'Sent',
                                      'Approved',
                                      'Declined'
                                    ].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _filterStatus = newValue!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Proposals List
                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (proposals.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No proposals yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create your first proposal to get started',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: proposals.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1),
                        itemBuilder: (context, index) {
                          final proposal = proposals[index];
                          return ProposalItem(
                            proposal: proposal,
                            onRefresh: _loadProposals,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProposalItem extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback? onRefresh;

  const ProposalItem({Key? key, required this.proposal, this.onRefresh})
      : super(key: key);

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
        } else {
          return '${parsed.day}/${parsed.month}/${parsed.year}';
        }
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (proposal['status']) {
      case 'Draft':
        statusColor = Color(0xFF856404);
        break;
      case 'Sent':
        statusColor = Color(0xFF004085);
        break;
      case 'Approved':
        statusColor = Color(0xFF155724);
        break;
      default:
        statusColor = Colors.grey;
    }

    Color statusBgColor;
    switch (proposal['status']) {
      case 'Draft':
        statusBgColor = Color(0xFFffeeba);
        break;
      case 'Sent':
        statusBgColor = Color(0xFFb8daff);
        break;
      case 'Approved':
        statusBgColor = Color(0xFFc3e6cb);
        break;
      default:
        statusBgColor = Colors.grey[200]!;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal['title'] ?? proposal['name'] ?? 'Untitled Proposal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2c3e50),
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    Text(
                      'Created: ${_formatDate(proposal['created_at'] ?? proposal['created'])}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF718096),
                      ),
                    ),
                    if (proposal['value'] != null)
                      Text(
                        'Value: \$${proposal['value'].toString()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF718096),
                        ),
                      ),
                    if (proposal['client_name'] != null ||
                        proposal['client'] != null)
                      Text(
                        'Client: ${proposal['client_name'] ?? proposal['client']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF718096),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  proposal['status'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Navigate to proposal details or edit
                  if (proposal['status'] == 'Draft') {
                    Navigator.pushNamed(context, '/compose',
                        arguments: proposal);
                  } else {
                    Navigator.pushNamed(context, '/preview',
                        arguments: proposal);
                  }
                },
                child: Text(
                  proposal['status'] == 'Draft'
                      ? 'Edit'
                      : proposal['status'] == 'Approved'
                          ? 'Download'
                          : 'View',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4a6cf7),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
