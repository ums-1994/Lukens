import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../client/proposal_viewer_page.dart';
import 'creator_dashboard_page.dart';
import '../../services/email_service.dart';
import '../../services/auto_draft_service.dart';
import '../../services/versioning_service.dart';
import '../shared/version_history_page.dart';

class EditingPage extends StatefulWidget {
  final String documentName;
  final String companyName;
  final String selectedClient;
  final List<String> selectedSnapshots;

  const EditingPage({
    super.key,
    required this.documentName,
    required this.companyName,
    required this.selectedClient,
    required this.selectedSnapshots,
  });

  @override
  State<EditingPage> createState() => _EditingPageState();
}

class _EditingPageState extends State<EditingPage> {
  // Current logged-in user information
  final String _currentUserName = 'Unathi Sibanda';
  final String _currentUserEmail = 'umsibanda.1994@gmail.com';
  final String _currentUserInitials = 'US';

  String _selectedTemplate = 'Default Send Email';
  bool _isPlainText = false;
  bool _isDesktopView = true;
  bool _ccOtherEmails = false;
  String _ccEmails = '';
  bool _isLoading = false;
  bool _isSharing = false;

  final EmailService _emailService = EmailService();
  final AutoDraftService _autoDraftService = AutoDraftService();
  final TextEditingController _addContactController = TextEditingController();

  final List<Map<String, String>> _recipients = [];
  String? _currentProposalId;

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
                    'Edit & Send Proposal',
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
                      'Step 3 of 3',
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
          // Main Content - Two Panel Layout
          Expanded(
            child: Row(
              children: [
                // Left Panel - Email Configuration
                Container(
                  width: 400,
                  color: Colors.white,
                  child: _buildEmailConfigurationPanel(),
                ),
                // Right Panel - Email Preview
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8F9FA),
                    child: _buildEmailPreviewPanel(),
                  ),
                ),
              ],
            ),
          ),
          // Auto-save status bar
          Container(
            height: 40,
            color: const Color(0xFFF8F9FA),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  _autoDraftService.isAutoSaving
                      ? Icons.sync
                      : _autoDraftService.hasUnsavedChanges
                          ? Icons.warning
                          : Icons.check_circle,
                  size: 16,
                  color: _autoDraftService.isAutoSaving
                      ? Colors.orange
                      : _autoDraftService.hasUnsavedChanges
                          ? Colors.red
                          : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _autoDraftService.getStatusMessage(),
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                if (_autoDraftService.hasUnsavedChanges)
                  TextButton(
                    onPressed: _forceSave,
                    child: const Text('Save Now'),
                  ),
                TextButton(
                  onPressed: _openVersionHistory,
                  child: const Text('Version History'),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailConfigurationPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // General Section
          const Text(
            'General',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 20),

          // Share Proposal Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareProposal,
              icon: _isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow, size: 16),
              label: Text(_isSharing ? 'Sharing...' : 'Share this Proposal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C757D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Create Version Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createVersion,
              icon: const Icon(Icons.bookmark_add, size: 16),
              label: const Text('Create Version'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3498DB),
                side: const BorderSide(color: Color(0xFF3498DB)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // From Section
          const Text(
            'From',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ECDC4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _currentUserInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUserName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentUserEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You',
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
          const SizedBox(height: 20),

          // To Section
          const Text(
            'To',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),

          // Quick Email Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    color: Color(0xFF6C757D), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _addContactController,
                    decoration: const InputDecoration(
                      hintText: 'Enter email address (e.g., john@company.com)',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addQuickEmail(value.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_addContactController.text.trim().isNotEmpty) {
                      _addQuickEmail(_addContactController.text.trim());
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Recipients List
          ..._recipients
              .map((recipient) => _buildRecipientItem(recipient))
              .toList(),

          // Add Contact Button (for detailed contact info)
          if (_recipients.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddContactDialog,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('+ Add Contact with Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C757D),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // CC Checkbox
          Row(
            children: [
              Checkbox(
                value: _ccOtherEmails,
                onChanged: (value) {
                  setState(() {
                    _ccOtherEmails = value ?? false;
                  });
                  // Mark data as changed for auto-draft
                  _markDataChanged();
                },
                activeColor: const Color(0xFF3498DB),
              ),
              const Expanded(
                child: Text(
                  'CC other email addresses (separated by a comma)',
                  style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
                ),
              ),
            ],
          ),
          if (_ccOtherEmails) ...[
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                _ccEmails = value;
                // Mark data as changed for auto-draft
                _markDataChanged();
              },
              decoration: const InputDecoration(
                hintText: 'Enter email addresses...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Email Template Section
          const Text(
            'Select Send Email Template',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTemplate,
                isExpanded: true,
                items: _emailService
                    .getAvailableTemplates()
                    .map((String template) {
                  return DropdownMenuItem<String>(
                    value: template,
                    child: Text(template),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTemplate = newValue!;
                  });
                  // Mark data as changed for auto-draft
                  _markDataChanged();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Template Options
          ..._emailService
              .getAvailableTemplates()
              .map((template) =>
                  _buildTemplateOption(template, _selectedTemplate == template))
              .toList(),
          const SizedBox(height: 32),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _sendTestEmail,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.email, size: 16),
              label: Text(_isLoading ? 'Sending...' : 'Send me a test email'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C757D),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendEmailToClient,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, size: 16),
              label: Text(_isLoading ? 'Sending...' : 'Send to client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientItem(Map<String, String> recipient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF6C757D), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient['name']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  recipient['email']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
          ),
          // Percentage Button
          GestureDetector(
            onTap: () => _showPercentageDialog(recipient),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF3498DB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.percent, color: Color(0xFF3498DB), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    recipient['percentage']!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3498DB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Edit Button
          GestureDetector(
            onTap: () => _editRecipient(recipient),
            child: const Icon(Icons.edit, color: Color(0xFF6C757D), size: 16),
          ),
          const SizedBox(width: 8),
          // Delete Button
          GestureDetector(
            onTap: () => _deleteRecipient(recipient),
            child: const Icon(Icons.delete, color: Color(0xFFE74C3C), size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateOption(String title, bool isSelected,
      {bool isDisabled = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
        border: Border.all(
          color: isSelected ? const Color(0xFF3498DB) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color:
                isDisabled ? const Color(0xFFBDC3C7) : const Color(0xFF3498DB),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isDisabled
                    ? const Color(0xFFBDC3C7)
                    : const Color(0xFF2C3E50),
              ),
            ),
          ),
          if (isDisabled)
            const Text(
              'Disabled',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFBDC3C7),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailPreviewPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Header
          Row(
            children: [
              const Text(
                'Email Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              // Desktop/Mobile Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton('Desktop', _isDesktopView),
                    _buildToggleButton('Mobile', !_isDesktopView),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Email Preview Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: _isDesktopView
                  ? _buildDesktopPreview()
                  : _buildMobilePreview(),
            ),
          ),
          const SizedBox(height: 16),

          // Plain Text Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Send all emails as plain text',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _isPlainText,
                onChanged: (value) {
                  setState(() {
                    _isPlainText = value;
                  });
                },
                activeThumbColor: const Color(0xFF3498DB),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isDesktopView = label == 'Desktop';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3498DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF6C757D),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPreview() {
    return Column(
      children: [
        // Email Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmailField('To', _getRecipientEmails()),
              const SizedBox(height: 8),
              _buildEmailField(
                  'Subject', '${widget.documentName} - ${widget.companyName}'),
              const SizedBox(height: 8),
              _buildEmailField(
                  'From', '$_currentUserName <$_currentUserEmail>'),
            ],
          ),
        ),
        // Email Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi ${_getPrimaryRecipientName()},',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Take a look at our proposal and let me know if you have any questions:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 24),
                // Proposal Preview Button
                GestureDetector(
                  onTap: _openProposalViewer,
                  child: Container(
                    width: 200,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        'Click to view proposal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Document Preview
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 48,
                          color: Color(0xFF6C757D),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Proposal Preview',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Click to view full document',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                          ),
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
    );
  }

  Widget _buildMobilePreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmailField('To', _getRecipientEmails()),
          const SizedBox(height: 8),
          _buildEmailField(
              'Subject', '${widget.documentName} - ${widget.companyName}'),
          const SizedBox(height: 8),
          _buildEmailField('From', '$_currentUserName <$_currentUserEmail>'),
          const SizedBox(height: 16),
          Text(
            'Hi ${_getPrimaryRecipientName()},',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Take a look at our proposal and let me know if you have any questions:',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 24),
          // Mobile Proposal Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _openProposalViewer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Click to view proposal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6C757D),
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
    );
  }

  // Backend methods
  void _openProposalViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProposalViewerPage(
          documentName: widget.documentName,
          companyName: widget.companyName,
          selectedClient: widget.selectedClient,
          selectedSnapshots: widget.selectedSnapshots,
        ),
      ),
    );
  }

  Future<void> _shareProposal() async {
    setState(() {
      _isSharing = true;
    });

    try {
      // Simulate sharing process
      await Future.delayed(const Duration(seconds: 2));

      final proposalLink = _emailService.generateProposalLink(
        widget.documentName,
        widget.companyName,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proposal shared! Link: $proposalLink'),
          backgroundColor: const Color(0xFF2ECC71),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share proposal: $e'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  void _showAddContactDialog() {
    _addContactController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _addContactController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Store email value
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Company (Optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Store company value
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Add contact logic here
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact added successfully!'),
                    backgroundColor: Color(0xFF2ECC71),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showPercentageDialog(Map<String, String> recipient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        double percentage =
            double.parse(recipient['percentage']!.replaceAll('%', ''));
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Set percentage for ${recipient['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${percentage.round()}%'),
                  Slider(
                    value: percentage,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (value) {
                      setState(() {
                        percentage = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      recipient['percentage'] = '${percentage.round()}%';
                    });

                    // Mark data as changed for auto-draft
                    _markDataChanged();

                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editRecipient(Map<String, String> recipient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final nameController = TextEditingController(text: recipient['name']);
        final emailController = TextEditingController(text: recipient['email']);
        final companyController =
            TextEditingController(text: recipient['company']);

        return AlertDialog(
          title: const Text('Edit Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  recipient['name'] = nameController.text;
                  recipient['email'] = emailController.text;
                  recipient['company'] = companyController.text;
                });

                // Mark data as changed for auto-draft
                _markDataChanged();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact updated successfully!'),
                    backgroundColor: Color(0xFF2ECC71),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteRecipient(Map<String, String> recipient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Contact'),
          content:
              Text('Are you sure you want to delete ${recipient['name']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _recipients.remove(recipient);
                });

                // Mark data as changed for auto-draft
                _markDataChanged();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact deleted successfully!'),
                    backgroundColor: Color(0xFF2ECC71),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _addQuickEmail(String email) {
    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    // Check if email already exists
    if (_recipients.any((recipient) => recipient['email'] == email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This email address is already added'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    // Extract name from email (part before @)
    String name = email.split('@')[0];
    name = name.replaceAll('.', ' ').replaceAll('_', ' ');
    name = name
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');

    setState(() {
      _recipients.add({
        'name': name,
        'email': email,
        'company': 'Unknown',
        'percentage': '100%'
      });
      _addContactController.clear();
    });

    // Mark data as changed for auto-draft
    _markDataChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $email to recipients'),
        backgroundColor: const Color(0xFF27AE60),
      ),
    );
  }

  String _getRecipientEmails() {
    if (_recipients.isEmpty) {
      return 'No recipients added';
    }
    return _recipients.map((r) => r['email']!).join(', ');
  }

  String _getPrimaryRecipientName() {
    if (_recipients.isEmpty) {
      return 'Recipient';
    }
    return _recipients.first['name']!;
  }

  Future<void> _sendTestEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final proposalLink = _emailService.generateProposalLink(
        widget.documentName,
        widget.companyName,
      );

      // Prepare proposal data for PDF generation using actual template content
      final proposalData = _buildProposalDataFromSnapshots();

      final success = await _emailService.sendTestEmail(
        from: '$_currentUserName | $_currentUserEmail',
        testEmail: _currentUserEmail, // Send test email to current user
        template: _selectedTemplate,
        documentName: widget.documentName,
        companyName: widget.companyName,
        clientName: widget.selectedClient,
        proposalLink: proposalLink,
        proposalData: proposalData,
        includePdf: false,
        includeDashboardLink: true,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test email sent successfully!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );

        // Navigate back to Creator Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DashboardPage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send test email. Please try again.'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendEmailToClient() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final proposalLink = _emailService.generateProposalLink(
        widget.documentName,
        widget.companyName,
      );

      final recipientEmails = _recipients.map((r) => r['email']!).toList();
      final ccEmails = _ccOtherEmails && _ccEmails.isNotEmpty
          ? _ccEmails.split(',').map((e) => e.trim()).toList()
          : <String>[];

      // Prepare proposal data for PDF generation using actual template content
      final proposalData = _buildProposalDataFromSnapshots();

      final success = await _emailService.sendEmail(
        from: '$_currentUserName | $_currentUserEmail',
        to: recipientEmails,
        cc: ccEmails,
        template: _selectedTemplate,
        documentName: widget.documentName,
        companyName: widget.companyName,
        clientName: widget.selectedClient,
        proposalLink: proposalLink,
        proposalData: proposalData,
        includePdf: false,
        includeDashboardLink: true,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal sent to client successfully!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );

        // Navigate back to Creator Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DashboardPage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send proposal. Please try again.'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Build proposal data from selected snapshots
  Map<String, dynamic> _buildProposalDataFromSnapshots() {
    // This is a simplified version - in a real app, you'd parse the selectedSnapshots
    // and extract the actual content from the template blocks
    return {
      'title': widget.documentName,
      'client': widget.companyName,
      'executive_summary': _getSnapshotContent('executive-summary') ??
          'This proposal outlines our comprehensive solution for your business needs.',
      'scope': _getSnapshotContent('proposed-solution') ??
          'Our services include consultation, implementation, and ongoing support.',
      'timeline': _getSnapshotContent('timeline') ??
          'Project completion within 4-6 weeks from contract signing.',
      'investment': _getSnapshotContent('pricing-table') ??
          'Please refer to the detailed pricing in the attached proposal.',
      'terms': _getSnapshotContent('terms-conditions') ??
          'Standard terms and conditions apply. Payment terms: 50% upfront, 50% on completion.',
      'selected_snapshots': widget.selectedSnapshots,
    };
  }

  // Helper method to get content from snapshots
  String? _getSnapshotContent(String section) {
    // Template blocks with actual content (same as in snapshots_page.dart)
    final templateBlocks = [
      {
        'id': 'executive-summary',
        'content':
            'Thank you for the opportunity to submit this proposal. We have carefully reviewed your requirements and are confident that our solution will meet your needs effectively and efficiently.',
      },
      {
        'id': 'proposed-solution',
        'content':
            'Based on our analysis, we recommend the following approach:\n• Implementation of our premium software platform\n• Customization to integrate with your existing systems\n• Comprehensive training for your team members\n• Ongoing support and maintenance',
      },
      {
        'id': 'pricing-table',
        'content':
            'Software License: \$9,999.00\nImplementation: \$4,500.00\nTraining: \$3,600.00\nSupport: \$2,000.00\nTotal: \$21,706.92',
      },
      {
        'id': 'terms-conditions',
        'content':
            'This agreement is valid for 30 days from the proposal date. Payment terms: 50% upon contract signing, 50% upon project completion. All work is subject to our standard terms and conditions.',
      },
      {
        'id': 'timeline',
        'content':
            'Project Timeline:\n• Week 1-2: Planning and setup\n• Week 3-6: Implementation and customization\n• Week 7-8: Testing and quality assurance\n• Week 9-10: Training and go-live\n• Week 11-12: Support and handover',
      },
    ];

    // Find the content for the requested section
    for (final block in templateBlocks) {
      if (block['id'] == section) {
        return block['content'];
      }
    }

    return null;
  }

  // Auto-draft methods
  Future<void> _createProposalAndInitializeAutoDraft() async {
    try {
      // Create a real proposal in the backend
      final proposalId = await _createProposal();
      if (proposalId != null) {
        _currentProposalId = proposalId;
        _initializeAutoDraft();
      } else {
        // Fallback to temp ID if creation fails
        _currentProposalId =
            'temp-proposal-${DateTime.now().millisecondsSinceEpoch}';
        _initializeAutoDraft();
      }
    } catch (e) {
      print('Error creating proposal: $e');
      // Fallback to temp ID
      _currentProposalId =
          'temp-proposal-${DateTime.now().millisecondsSinceEpoch}';
      _initializeAutoDraft();
    }
  }

  Future<String?> _createProposal() async {
    try {
      print(
          'Creating proposal: ${widget.documentName} for client: ${widget.selectedClient}');
      final response = await http.post(
        Uri.parse('http://localhost:8000/proposals'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': widget.documentName,
          'client': widget.selectedClient,
          'dtype': 'Proposal',
        }),
      );

      print(
          'Proposal creation response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Created proposal with ID: ${data['id']}');
        return data['id'] as String?;
      }
    } catch (e) {
      print('Error creating proposal: $e');
    }
    return null;
  }

  void _initializeAutoDraft() {
    // Initialize with current proposal data
    if (_currentProposalId != null) {
      print('Initializing auto-draft for proposal: $_currentProposalId');
      final proposalData = {
        'sections': _buildProposalDataFromSnapshots(),
        'documentName': widget.documentName,
        'companyName': widget.companyName,
        'selectedClient': widget.selectedClient,
        'selectedSnapshots': widget.selectedSnapshots,
      };
      print('Proposal data: ${json.encode(proposalData)}');
      _autoDraftService.startAutoDraft(_currentProposalId!, proposalData);

      // Start periodic auto-save trigger
      _startPeriodicAutoSave();
    } else {
      print('No proposal ID available for auto-draft initialization');
    }
  }

  void _startPeriodicAutoSave() {
    // Trigger auto-save every 30 seconds to ensure data is saved
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentProposalId != null) {
        _markDataChanged();
      }
    });
  }

  void _openVersionHistory() {
    if (_currentProposalId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VersionHistoryPage(
            proposalId: _currentProposalId!,
            proposalTitle: widget.documentName,
          ),
        ),
      ).then((restored) {
        if (restored == true) {
          // Proposal was restored, refresh the page
          setState(() {});
        }
      });
    }
  }

  Future<void> _forceSave() async {
    final success = await _autoDraftService.forceSave();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_autoDraftService.lastError ?? 'Failed to save draft'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markDataChanged() {
    final proposalData = {
      'sections': _buildProposalDataFromSnapshots(),
      'documentName': widget.documentName,
      'companyName': widget.companyName,
      'selectedClient': widget.selectedClient,
      'selectedSnapshots': widget.selectedSnapshots,
    };
    _autoDraftService.markChanged(proposalData);
  }

  void _createVersion() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isMajor = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Version'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Version Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Major Version'),
                subtitle: const Text('Increment major version number'),
                value: isMajor,
                onChanged: (value) => setState(() => isMajor = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                // Force save current changes first
                await _autoDraftService.forceSave();

                // Create version with current proposal data
                final versioningService = VersioningService();
                final version = await versioningService.createVersion(
                  _currentProposalId!,
                  title: titleController.text.trim(),
                  sections: _buildProposalDataFromSnapshots(),
                  description: descriptionController.text.trim(),
                  isMajor: isMajor,
                );

                if (version != null) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Version created successfully'),
                      backgroundColor: Color(0xFF2ECC71),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(versioningService.lastError ??
                          'Failed to create version'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _createProposalAndInitializeAutoDraft();
  }

  @override
  void dispose() {
    _autoDraftService.stopAutoDraft();
    _addContactController.dispose();
    super.dispose();
  }
}
