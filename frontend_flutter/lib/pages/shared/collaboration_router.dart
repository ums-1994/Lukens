import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../client/client_dashboard_home.dart';
import '../guest/guest_collaboration_page.dart';
import '../creator/blank_document_editor_page.dart'
    show BlankDocumentEditorPage;
import '../../services/auth_service.dart';

/// Router that determines whether to show Client Dashboard or Guest Collaboration
/// based on the invitation type and permission level
class CollaborationRouter extends StatefulWidget {
  final String token;

  const CollaborationRouter({super.key, required this.token});

  @override
  State<CollaborationRouter> createState() => _CollaborationRouterState();
}

class _CollaborationRouterState extends State<CollaborationRouter> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _determineRoute();
  }

  Future<void> _determineRoute() async {
    try {
      print(
          '🔍 Checking collaboration type for token: ${(widget.token.length > 20 ? widget.token.substring(0, 20) : widget.token)}...');

      // First, try the secure proposal endpoint (for encrypted client proposals)
      print('   Trying secure proposal endpoint...');
      final secureProposalResponse = await http
          .get(
            Uri.parse(
                'http://localhost:8000/api/secure-proposal?token=${widget.token}'),
          )
          .timeout(const Duration(seconds: 5));

      if (secureProposalResponse.statusCode == 200) {
        final data = jsonDecode(secureProposalResponse.body);
        final proposal = data['proposal'] as Map<String, dynamic>?;
        
        print('✅ Secure encrypted proposal found');
        print('   Proposal ID: ${proposal?['id']}');
        print('   Title: ${proposal?['title']}');
        print('   Encrypted: ${data['proposal']?['is_encrypted'] ?? false}');
        
        // Route to a secure proposal viewer (read-only)
        // For now, route to client dashboard which can handle secure proposals
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ClientDashboardHome(),
            ),
          );
        }
        return;
      } else if (secureProposalResponse.statusCode == 401) {
        // Check if password is required
        final errorData = jsonDecode(secureProposalResponse.body);
        if (errorData['requires_password'] == true) {
          print('🔒 Password required for secure proposal');
          // Show password dialog
          if (mounted) {
            _showPasswordDialog();
          }
          return;
        }
      }

      // Second, try the collaborate endpoint (for collaborators)
      print('   Trying collaborate endpoint...');
      final collaborateResponse = await http
          .get(
            Uri.parse(
                'http://localhost:8000/api/collaborate?token=${widget.token}'),
          )
          .timeout(const Duration(seconds: 5));

      if (collaborateResponse.statusCode == 200) {
        final data = jsonDecode(collaborateResponse.body);
        final permissionLevel = data['permission_level'] as String?;
        final proposalData = data['proposal'] as Map<String, dynamic>?;
        final authToken = data['auth_token'] as String?;

        print('✅ Collaboration invitation found');
        print('   Permission level: $permissionLevel');
        print('   Can comment: ${data['can_comment']}');
        print('   Can edit: ${data['can_edit']}');

        // Route based on permission level
        if (permissionLevel == 'edit' && authToken != null) {
          // Full editing rights - set auth token and open in document editor
          print('→ Routing to Document Editor (can edit)');
          print('   Auth token received: ${(authToken.length > 20 ? authToken.substring(0, 20) : authToken)}...');

          if (mounted && proposalData != null) {
            // Store auth token and user data for the editor to use
            final collaboratorEmail = data['invited_email'] as String;
            AuthService.setUserData({
              'email': collaboratorEmail,
              'username': collaboratorEmail,
              'full_name': 'Collaborator ($collaboratorEmail)',
              'role': 'collaborator',
            }, authToken);
            print('   Token and user data stored in AuthService');

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BlankDocumentEditorPage(
                  proposalId: proposalData['id']?.toString(),
                  proposalTitle: proposalData['title'] ?? 'Untitled',
                  readOnly: false, // Full edit access
                ),
              ),
            );
          }
        } else if (permissionLevel == 'suggest' && authToken != null) {
          // Suggest mode - can propose changes for approval
          print('→ Routing to Document Editor (suggest mode)');
          print('   Auth token received: ${(authToken.length > 20 ? authToken.substring(0, 20) : authToken)}...');

          if (mounted && proposalData != null) {
            // Store auth token and user data for the editor to use
            final collaboratorEmail = data['invited_email'] as String;
            AuthService.setUserData({
              'email': collaboratorEmail,
              'username': collaboratorEmail,
              'full_name': 'Reviewer ($collaboratorEmail)',
              'role': 'reviewer',
            }, authToken);
            print('   Token and user data stored in AuthService');

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BlankDocumentEditorPage(
                  proposalId: proposalData['id']?.toString(),
                  proposalTitle: proposalData['title'] ?? 'Untitled',
                  readOnly: true, // Read-only in suggest mode
                  // TODO: Add suggest mode UI to show suggestions panel
                ),
              ),
            );
          }
        } else if (permissionLevel == 'view') {
          // View-only client access
          print('→ Routing to Client Dashboard (view-only)');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientDashboardHome(),
              ),
            );
          }
        } else {
          // Comment permission - view and comment only
          print('→ Routing to Guest Collaboration Page (can comment)');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const GuestCollaborationPage(),
              ),
            );
          }
        }
        return;
      }

      // If collaborate endpoint fails, try client portal endpoint
      print(
          '⚠️ Collaborate endpoint returned ${collaborateResponse.statusCode}');
      print('   Trying client portal endpoint...');

      final clientResponse = await http
          .get(
            Uri.parse(
                'http://localhost:8000/api/client/proposals?token=${widget.token}'),
          )
          .timeout(const Duration(seconds: 5));

      if (clientResponse.statusCode == 200) {
        print('✅ Client invitation found');
        print('→ Routing to Client Dashboard');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ClientDashboardHome(),
            ),
          );
        }
        return;
      }

      // If all fail, show error
      throw Exception('Invalid or expired token');
    } catch (e) {
      print('❌ Error determining route: $e');
      if (mounted) {
        setState(() {
          _error = 'Unable to access collaboration: $e';
        });
      }
    }
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔒 Password Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This proposal is password protected. Please enter the password to continue.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text;
              if (password.isEmpty) return;
              
              Navigator.pop(context);
              
              // Retry with password
              try {
                final response = await http.get(
                  Uri.parse('http://localhost:8000/api/secure-proposal?token=${widget.token}&password=$password'),
                ).timeout(const Duration(seconds: 5));
                
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  final proposal = data['proposal'] as Map<String, dynamic>?;
                  
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ClientDashboardHome(),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid password. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _showPasswordDialog(); // Retry
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _error = 'Error accessing secure proposal: $e';
                  });
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Access Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _determineRoute(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Loading collaboration...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Determining access type',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
