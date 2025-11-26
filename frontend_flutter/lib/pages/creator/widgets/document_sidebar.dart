import 'package:flutter/material.dart';

class DocumentSidebar extends StatelessWidget {
  final String? selectedPanel;
  final Function(String) onPanelSelected;
  final Widget signaturePanelContent;
  final Widget commentsPanelContent;

  const DocumentSidebar({
    super.key,
    required this.selectedPanel,
    required this.onPanelSelected,
    required this.signaturePanelContent,
    required this.commentsPanelContent,
  });

  @override
  Widget build(BuildContext context) {
    final active = selectedPanel ?? 'signatures';

    return Container(
      width: 300,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildTab(
                  context: context,
                  label: 'Signatures',
                  value: 'signatures',
                  isActive: active == 'signatures',
                ),
                const SizedBox(width: 8),
                _buildTab(
                  context: context,
                  label: 'Comments',
                  value: 'comments',
                  isActive: active == 'comments',
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: active == 'signatures'
                  ? signaturePanelContent
                  : active == 'comments'
                      ? commentsPanelContent
                      : const Center(child: Text('Select a panel')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required BuildContext context,
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onPanelSelected(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.blue : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
