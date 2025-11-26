import 'package:flutter/material.dart';
import '../../../theme/premium_theme.dart';

class DocumentToolbar extends StatelessWidget {
  final TextEditingController titleController;
  final bool isSaving;
  final DateTime? lastSaved;
  final VoidCallback onSave;
  final VoidCallback onCollaboratorsTap;
  final VoidCallback onLibraryTap;
  final bool readOnly;

  const DocumentToolbar({
    super.key,
    required this.titleController,
    required this.isSaving,
    this.lastSaved,
    required this.onSave,
    required this.onCollaboratorsTap,
    required this.onLibraryTap,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: PremiumTheme.darkBg2,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Proposal Editor',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: titleController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Document Title',
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              readOnly: readOnly,
            ),
          ),
          const SizedBox(width: 16),
          if (lastSaved != null)
            Text(
              'Last saved: ${_formatTime(lastSaved!)}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          if (!readOnly) ...[
            _buildHeaderButton(
              icon: Icons.bookmark_border,
              label: 'Library',
              onPressed: onLibraryTap,
            ),
            _buildHeaderButton(
              icon: Icons.people_outline,
              label: 'Share',
              onPressed: onCollaboratorsTap,
            ),
            _buildHeaderButton(
              icon: isSaving ? Icons.hourglass_top : Icons.save,
              label: isSaving ? 'Saving...' : 'Save',
              onPressed: isSaving ? () {} : onSave,
              isPrimary: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary
              ? PremiumTheme.purple
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}


