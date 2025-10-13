import 'package:flutter/material.dart';
import '../../services/versioning_service.dart';

class VersionHistoryPage extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;

  const VersionHistoryPage({
    super.key,
    required this.proposalId,
    required this.proposalTitle,
  });

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> {
  final VersioningService _versioningService = VersioningService();
  ProposalVersion? _selectedVersion1;
  ProposalVersion? _selectedVersion2;
  List<VersionDiff> _diffs = [];
  bool _isComparing = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    await _versioningService.loadVersions(widget.proposalId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Text('Version History - ${widget.proposalTitle}'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showCreateVersionDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Create New Version',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _versioningService,
        builder: (context, child) {
          if (_versioningService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_versioningService.lastError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading versions',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _versioningService.lastError!,
                    style: TextStyle(color: Colors.red[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadVersions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Compare versions section
              if (_versioningService.versions.length >= 2)
                _buildCompareSection(),

              // Versions list
              Expanded(
                child: _versioningService.versions.isEmpty
                    ? _buildEmptyState()
                    : _buildVersionsList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompareSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compare Versions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVersionDropdown(
                  'Version 1',
                  _selectedVersion1,
                  (version) => setState(() => _selectedVersion1 = version),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVersionDropdown(
                  'Version 2',
                  _selectedVersion2,
                  (version) => setState(() => _selectedVersion2 = version),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedVersion1 != null &&
                      _selectedVersion2 != null &&
                      !_isComparing
                  ? _compareVersions
                  : null,
              icon: _isComparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.compare_arrows),
              label: Text(_isComparing ? 'Comparing...' : 'Compare'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_diffs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDiffsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildVersionDropdown(
    String label,
    ProposalVersion? selectedVersion,
    Function(ProposalVersion?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ProposalVersion>(
          initialValue: selectedVersion,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: Text('Select $label'),
          items: _versioningService.versions.map((version) {
            return DropdownMenuItem<ProposalVersion>(
              value: version,
              child: Text(version.displayTitle),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDiffsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Changes (${_diffs.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          ..._diffs.map((diff) => _buildDiffItem(diff)),
        ],
      ),
    );
  }

  Widget _buildDiffItem(VersionDiff diff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _getDiffColor(diff.changeType),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getDiffIcon(diff.changeType),
                size: 16,
                color: _getDiffColor(diff.changeType),
              ),
              const SizedBox(width: 8),
              Text(
                diff.section,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getDiffColor(diff.changeType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getDiffLabel(diff.changeType),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDiffColor(diff.changeType),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (diff.oldContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Old: ${diff.oldContent}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (diff.newContent.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'New: ${diff.newContent}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVersionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _versioningService.versions.length,
      itemBuilder: (context, index) {
        final version = _versioningService.versions[index];
        return _buildVersionCard(version);
      },
    );
  }

  Widget _buildVersionCard(ProposalVersion version) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: version.isMajor
              ? const Color(0xFF3498DB)
              : const Color(0xFF95A5A6),
          child: Text(
            version.versionNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          version.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(version.description),
            const SizedBox(height: 4),
            Text(
              'Created ${_formatDate(version.createdAt)} by ${version.createdBy}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleVersionAction(value, version),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(Icons.restore, size: 16),
                  SizedBox(width: 8),
                  Text('Restore'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No versions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first version to start tracking changes',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateVersionDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Version'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3498DB),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _compareVersions() async {
    if (_selectedVersion1 != null && _selectedVersion2 != null) {
      setState(() {
        _diffs = [];
        _isComparing = true;
      });

      final diffs = await _versioningService.compareVersions(
        _selectedVersion1!.id,
        _selectedVersion2!.id,
      );

      setState(() {
        _diffs = diffs;
        _isComparing = false;
      });
    }
  }

  void _handleVersionAction(String action, ProposalVersion version) {
    switch (action) {
      case 'restore':
        _restoreVersion(version);
        break;
      case 'delete':
        _deleteVersion(version);
        break;
    }
  }

  Future<void> _restoreVersion(ProposalVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version'),
        content: Text(
            'Are you sure you want to restore "${version.title}"? This will overwrite the current proposal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _versioningService.restoreVersion(
        widget.proposalId,
        version.id,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Version restored successfully'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate restoration
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _versioningService.lastError ?? 'Failed to restore version'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteVersion(ProposalVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Version'),
        content: Text(
            'Are you sure you want to delete "${version.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _versioningService.deleteVersion(
        widget.proposalId,
        version.id,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Version deleted successfully'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _versioningService.lastError ?? 'Failed to delete version'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateVersionDialog() {
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

                // This would need to get current proposal data
                // For now, we'll create with empty sections
                final version = await _versioningService.createVersion(
                  widget.proposalId,
                  title: titleController.text.trim(),
                  sections: {}, // This should be current proposal sections
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
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDiffColor(ChangeType changeType) {
    switch (changeType) {
      case ChangeType.added:
        return Colors.green;
      case ChangeType.removed:
        return Colors.red;
      case ChangeType.modified:
        return Colors.orange;
    }
  }

  IconData _getDiffIcon(ChangeType changeType) {
    switch (changeType) {
      case ChangeType.added:
        return Icons.add_circle;
      case ChangeType.removed:
        return Icons.remove_circle;
      case ChangeType.modified:
        return Icons.edit;
    }
  }

  String _getDiffLabel(ChangeType changeType) {
    switch (changeType) {
      case ChangeType.added:
        return 'Added';
      case ChangeType.removed:
        return 'Removed';
      case ChangeType.modified:
        return 'Modified';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _versioningService.dispose();
    super.dispose();
  }
}
