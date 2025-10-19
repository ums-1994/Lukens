import 'package:flutter/material.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _selectedRole = 'All';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _users = [
    {
      'id': '1',
      'name': 'John Smith',
      'email': 'john.smith@company.com',
      'role': 'CEO',
      'status': 'Active',
      'lastLogin': '2024-01-15',
      'avatar': 'assets/images/placeholder-user.jpg',
    },
    {
      'id': '2',
      'name': 'Sarah Johnson',
      'email': 'sarah.johnson@company.com',
      'role': 'Financial Manager',
      'status': 'Active',
      'lastLogin': '2024-01-14',
      'avatar': 'assets/images/placeholder-user.jpg',
    },
    {
      'id': '3',
      'name': 'Mike Wilson',
      'email': 'mike.wilson@company.com',
      'role': 'Reviewer',
      'status': 'Active',
      'lastLogin': '2024-01-13',
      'avatar': 'assets/images/placeholder-user.jpg',
    },
    {
      'id': '4',
      'name': 'Emily Davis',
      'email': 'emily.davis@company.com',
      'role': 'Client',
      'status': 'Inactive',
      'lastLogin': '2024-01-10',
      'avatar': 'assets/images/placeholder-user.jpg',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage users, roles, and permissions',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB0B6BB),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add User', style: TextStyle(color: Colors.white)),
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
                        hintText: 'Search users...',
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
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF1A1A1B),
                    style: const TextStyle(color: Colors.white),
                    items: ['All', 'CEO', 'Financial Manager', 'Reviewer', 'Client']
                        .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedRole = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Users List
            LiquidGlassCard(
              borderRadius: 16,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('User', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Email', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('Role', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('Last Login', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('Actions', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  // Table Rows
                  ..._getFilteredUsers().map((user) => _buildUserRow(user)).toList(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Footer(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredUsers() {
    return _users.where((user) {
      final matchesSearch = user['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == 'All' || user['role'] == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage(user['avatar']),
                ),
                const SizedBox(width: 12),
                Text(
                  user['name'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user['email'],
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(user['role']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getRoleColor(user['role'])),
              ),
              child: Text(
                user['role'],
                style: TextStyle(
                  color: _getRoleColor(user['role']),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user['status'] == 'Active' 
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: user['status'] == 'Active' ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                user['status'],
                style: TextStyle(
                  color: user['status'] == 'Active' ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              user['lastLogin'],
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _editUser(user),
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                ),
                IconButton(
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CEO':
        return const Color(0xFFE9293A);
      case 'Financial Manager':
        return const Color(0xFF00D4FF);
      case 'Reviewer':
        return const Color(0xFFFFD700);
      case 'Client':
        return const Color(0xFF14B3BB);
      default:
        return Colors.grey;
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: const Text('Add New User', style: TextStyle(color: Colors.white)),
        content: const Text('User creation form would go here', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9293A)),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: Text('Edit ${user['name']}', style: const TextStyle(color: Colors.white)),
        content: const Text('User edit form would go here', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9293A)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1B),
        title: const Text('Delete User', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${user['name']}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _users.removeWhere((u) => u['id'] == user['id']);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
