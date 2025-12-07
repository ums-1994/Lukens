import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

/// Helper for showing the "Collaborate on Proposal" dialog.
///
/// This keeps all collaboration UI in one place while allowing the
/// parent editor widget to own the underlying state and data.
class InviteUserDialog {
  const InviteUserDialog._();

  /// Shows the invite / collaboration dialog.
  ///
  /// The parent must provide:
  /// - [savedProposalId]: backend proposal ID (required to invite)
  /// - [getAuthToken]: retrieves the current auth token
  /// - [loadCollaborators]: reloads the collaborators list in the parent
  /// - [onCollaboratingChanged]: notifies parent when _isCollaborating changes
  /// - [getCollaborators]: returns the current collaborators list
  /// - [removeCollaborator]: removes a collaborator by invitation ID
  static void show({
    required BuildContext context,
    required int? savedProposalId,
    required Future<String?> Function() getAuthToken,
    required Future<void> Function() loadCollaborators,
    required void Function(bool isCollaborating) onCollaboratingChanged,
    required List<Map<String, dynamic>> Function() getCollaborators,
    required Future<void> Function(int invitationId) removeCollaborator,
  }) {
    final emailController = TextEditingController();
    bool isInviting = false;
    String selectedPermission = 'edit'; // all collaborators get full access

    // Load existing collaborators into parent state
    loadCollaborators();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final collaborators = getCollaborators();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                width: 600,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.people,
                            color: Color(0xFF27AE60),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Collaborate on Proposal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Invite others to collaborate on this proposal. They will receive an email with a secure link.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'colleague@example.com',
                                prefixIcon: const Icon(Icons.email, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              enabled: !isInviting,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isInviting
                                ? null
                                : () async {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(dialogContext);
                                    final email = emailController.text.trim();

                                    if (email.isEmpty) {
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please enter an email address',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    // Validate email format
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(email)) {
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please enter a valid email address',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    if (savedProposalId == null) {
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please save the proposal first',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() {
                                      isInviting = true;
                                    });

                                    try {
                                      final token = await getAuthToken();
                                      if (token == null) {
                                        throw Exception(
                                          'Authentication required',
                                        );
                                      }

                                      final response = await http.post(
                                        Uri.parse(
                                          '${ApiService.baseUrl}/api/proposals/$savedProposalId/invite',
                                        ),
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode({
                                          'email': email,
                                          'permission_level':
                                              selectedPermission,
                                        }),
                                      );

                                      if (response.statusCode == 201) {
                                        final result =
                                            jsonDecode(response.body) as Map;

                                        await loadCollaborators();
                                        onCollaboratingChanged(true);

                                        emailController.clear();

                                        final emailSent =
                                            result['email_sent'] == true;
                                        final emailError =
                                            result['email_error'];

                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              emailSent
                                                  ? '✅ Invitation sent to $email'
                                                  : emailError != null
                                                      ? '⚠️ Invitation created but email failed: ${emailError.toString().substring(0, 50)}...'
                                                      : '⚠️ Invitation created but email failed to send. Check SMTP configuration.',
                                            ),
                                            backgroundColor: emailSent
                                                ? Colors.green
                                                : Colors.orange,
                                            duration: Duration(
                                              seconds: emailSent ? 3 : 5,
                                            ),
                                          ),
                                        );
                                      } else {
                                        String errorMessage =
                                            'Failed to send invitation';
                                        try {
                                          final error = jsonDecode(
                                            response.body,
                                          ) as Map<String, dynamic>;
                                          errorMessage =
                                              error['detail'] ?? errorMessage;
                                        } catch (_) {
                                          errorMessage =
                                              'Server error: ${response.statusCode}';
                                        }
                                        throw Exception(errorMessage);
                                      }
                                    } catch (e) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error inviting collaborator: ${e.toString()}',
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    } finally {
                                      setDialogState(() {
                                        isInviting = false;
                                      });
                                    }
                                  },
                            icon: isInviting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label: Text(
                              isInviting ? 'Sending...' : 'Send Invite',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (collaborators.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Current Collaborators (${collaborators.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: collaborators.length,
                          itemBuilder: (context, index) {
                            final collaborator = collaborators[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF27AE60),
                                    child: Text(
                                      collaborator['name']
                                          .toString()
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          collaborator['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          collaborator['email'] ?? '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      collaborator['role'] ?? 'Full Access',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (collaborator['status'] == 'accepted')
                                              ? Colors.green[50]
                                              : Colors.orange[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (collaborator['status'] == 'accepted')
                                          ? 'Active'
                                          : 'Pending',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: (collaborator['status'] ==
                                                'accepted')
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    tooltip: 'Remove collaborator',
                                    onPressed: () async {
                                      final invitationId = collaborator['id'];
                                      if (invitationId != null) {
                                        Navigator.pop(dialogContext);
                                        await removeCollaborator(invitationId);
                                        // Re-open dialog to show updated list
                                        show(
                                          context: context,
                                          savedProposalId: savedProposalId,
                                          getAuthToken: getAuthToken,
                                          loadCollaborators: loadCollaborators,
                                          onCollaboratingChanged:
                                              onCollaboratingChanged,
                                          getCollaborators: getCollaborators,
                                          removeCollaborator:
                                              removeCollaborator,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No collaborators yet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
