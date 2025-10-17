import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';

class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  _ProposalsPageState createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage> {
  String _filterStatus = 'All Statuses';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> proposals = [];
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadProposals();
  }

  Future<void> _loadProposals() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        _token = await user.getIdToken();
        final data = await ApiService.getProposals(_token!);
        setState(() {
          proposals = List<Map<String, dynamic>>.from(data);
        });
      } else {
        proposals = [];
      }
    } catch (e) {
      print('Error loading proposals: $e');
      proposals = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = proposals.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final matchesSearch =
          title.contains(_searchController.text.toLowerCase()) ||
              client.contains(_searchController.text.toLowerCase());
      final matchesStatus = _filterStatus == 'All Statuses' ||
          (p['status'] ?? '') == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                Container(
                  height: 64,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'Proposify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SidebarNavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  selected: false,
                  onTap: () => Navigator.pushNamed(context, '/home'),
                ),
                SidebarNavItem(
                  icon: Icons.description_outlined,
                  label: 'Proposals',
                  selected: true,
                  onTap: () {},
                ),
                SidebarNavItem(
                  icon: Icons.library_books_outlined,
                  label: 'Templates',
                  selected: false,
                  onTap: () => Navigator.pushNamed(context, '/templates'),
                ),
                SidebarNavItem(
                  icon: Icons.shield_outlined,
                  label: 'Governance',
                  selected: false,
                  onTap: () => Navigator.pushNamed(context, '/governance'),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: const [
                      Icon(Icons.settings_outlined,
                          color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text('Settings', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: title, search, actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Proposals',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2c3e50))),
                            SizedBox(height: 6),
                            Text('Manage all your business proposals and SOWs',
                                style: TextStyle(color: Color(0xFF718096))),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Search proposals...',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                  context, '/proposal-wizard'),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New Proposal'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Filter card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('All Proposals',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2c3e50))),
                              Row(
                                children: [
                                  Container(
                                      width: 200,
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: const InputDecoration(
                                          hintText: 'Search proposals...',
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          border: OutlineInputBorder(),
                                        ),
                                      )),
                                  const SizedBox(width: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: const Color(0xFFe2e8f0)),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _filterStatus,
                                          items: [
                                            'All Statuses',
                                            'Draft',
                                            'Sent',
                                            'Approved',
                                            'Declined'
                                          ]
                                              .map((String value) =>
                                                  DropdownMenuItem<String>(
                                                      value: value,
                                                      child: Text(value)))
                                              .toList(),
                                          onChanged: (String? newValue) =>
                                              setState(() => _filterStatus =
                                                  newValue ?? 'All Statuses'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Proposals list / empty state
                          if (_isLoading)
                            const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator()))
                          else if (proposals.isEmpty)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 48.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined,
                                        size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text('No proposals yet',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700])),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Create your first proposal to get started',
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () => Navigator.pushNamed(
                                          context, '/proposal-wizard'),
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                          'Create Your First Proposal'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                    )
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final proposal = filtered[index];
                                return ProposalItem(
                                    proposal: proposal,
                                    onRefresh: _loadProposals);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    switch ((proposal['status'] ?? '').toString().toLowerCase()) {
      case 'draft':
        statusColor = const Color(0xFF856404);
        break;
      case 'sent':
        statusColor = const Color(0xFF004085);
        break;
      case 'approved':
        statusColor = const Color(0xFF155724);
        break;
      default:
        statusColor = Colors.grey;
    }

    Color statusBgColor;
    switch ((proposal['status'] ?? '').toString().toLowerCase()) {
      case 'draft':
        statusBgColor = const Color(0xFFffeeba);
        break;
      case 'sent':
        statusBgColor = const Color(0xFFb8daff);
        break;
      case 'approved':
        statusBgColor = const Color(0xFFc3e6cb);
        break;
      default:
        statusBgColor = Colors.grey[200]!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(proposal['title'] ?? 'Untitled Proposal',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF2c3e50))),
              const SizedBox(height: 8),
              Wrap(spacing: 16, children: [
                Text(
                    'Last modified: ${_formatDate(proposal['updated_at'] ?? proposal['updatedAt'])}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF718096))),
                if (proposal['client_name'] != null ||
                    proposal['client'] != null)
                  Text(
                      'Client: ${proposal['client_name'] ?? proposal['client']}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF718096))),
              ])
            ]),
          ),
          Row(children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(proposal['status'] ?? 'Unknown',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if ((proposal['status'] ?? '').toString().toLowerCase() ==
                    'draft') {
                  Navigator.pushNamed(context, '/compose', arguments: proposal);
                } else {
                  Navigator.pushNamed(context, '/preview', arguments: proposal);
                }
              },
              child: Text(
                  (proposal['status'] ?? '').toString().toLowerCase() == 'draft'
                      ? 'Edit'
                      : 'View'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4a6cf7),
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                              title: const Text('Delete proposal?'),
                              content: const Text(
                                  'Are you sure you want to delete this proposal?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'))
                              ]));
                  if (confirm == true) {
                    final token =
                        await FirebaseService.currentUser?.getIdToken();
                    if (token != null) {
                      final idVal = proposal['id'];
                      final intId = idVal is int
                          ? idVal
                          : int.tryParse(idVal.toString()) ?? 0;
                      if (intId != 0) {
                        await ApiService.deleteProposal(
                            token: token, id: intId);
                        if (onRefresh != null) onRefresh!();
                      }
                    }
                  }
                })
          ])
        ],
      ),
    );
  }
}

// Sidebar navigation item widget
class SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.white70, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
