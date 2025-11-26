import 'package:flutter/material.dart';

/// Simple mixin for the signature panel in the refactored editor.
///
/// This stays lightweight and delegates DocuSign behaviour back to the
/// hosting widget via a callback.
mixin SignaturePanelMixin {
  final List<String> _signatures = <String>[
    'Client Signature',
    'Authorized By',
    'Manager Approval',
  ];

  String _signatureSearchQuery = '';

  void initSignaturePanel() {}

  void disposeSignaturePanel() {}

  Widget buildSignaturePanel(
    BuildContext context, {
    required VoidCallback onSendForSignature,
  }) {
    final filtered = _signatures
        .where(
          (s) => s.toLowerCase().contains(
                _signatureSearchQuery.toLowerCase(),
              ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signatures',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search signatures...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            _signatureSearchQuery = value;
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No signatures found.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final sig = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text(sig),
                    );
                  },
                ),
        ),
        const Divider(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSendForSignature,
            icon: const Icon(Icons.edit_document),
            label: const Text('Send with DocuSign'),
          ),
        ),
      ],
    );
  }
}



