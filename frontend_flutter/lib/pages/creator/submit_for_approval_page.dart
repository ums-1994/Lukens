import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class SubmitForApprovalPage extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;

  const SubmitForApprovalPage({
    Key? key,
    required this.proposalId,
    required this.proposalTitle,
  }) : super(key: key);

  @override
  State<SubmitForApprovalPage> createState() => _SubmitForApprovalPageState();
}

class _SubmitForApprovalPageState extends State<SubmitForApprovalPage> {
  List<dynamic> _workflows = [];
  String? _selectedWorkflowId;
  String _comments = '';
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final workflows = await ApiService.getApprovalWorkflows(token);
      setState(() {
        _workflows = workflows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading workflows: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Submit for Approval',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProposalInfoCard(),
                  const SizedBox(height: 24),
                  _buildWorkflowSelectionCard(),
                  const SizedBox(height: 24),
                  _buildCommentsCard(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProposalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Proposal Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Title', widget.proposalTitle),
            _buildInfoRow('ID', widget.proposalId),
            _buildInfoRow('Status', 'Draft'),
            _buildInfoRow('Submitted By', AuthService.currentUser?['username'] ?? 'Unknown'),
            _buildInfoRow('Date', _formatDate(DateTime.now())),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree,
                  color: Colors.green[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Approval Workflow',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_workflows.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 32,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No approval workflows available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A default workflow will be used',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _workflows.map((workflow) {
                  final isSelected = _selectedWorkflowId == workflow['id'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedWorkflowId = workflow['id'];
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: workflow['id'],
                              groupValue: _selectedWorkflowId,
                              onChanged: (value) {
                                setState(() {
                                  _selectedWorkflowId = value;
                                });
                              },
                              activeColor: Colors.blue[600],
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workflow['name'] ?? 'Unnamed Workflow',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.blue[800] : const Color(0xFF2C3E50),
                                    ),
                                  ),
                                  if (workflow['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      workflow['description'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected ? Colors.blue[600] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.account_tree,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Stages: ${(workflow['stages'] as List?)?.join(', ') ?? 'None'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.comment,
                  color: Colors.orange[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add any additional comments or notes for reviewers...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange[600]!),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _comments = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitForApproval,
        icon: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send),
        label: Text(_isSubmitting ? 'Submitting...' : 'Submit for Approval'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C3E50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _submitForApproval() async {
    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      setState(() {
        _isSubmitting = true;
      });

      final result = await ApiService.submitProposalForApproval(
        token: token,
        proposalId: widget.proposalId,
        workflowId: _selectedWorkflowId,
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal submitted for approval successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        throw Exception('Failed to submit proposal for approval');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
