import 'package:flutter/material.dart';
import '../../pages/creator/blank_document_editor_page.dart';

class StartFromScratchPage extends StatelessWidget {
  final String? proposalId;
  final String? initialTitle;
  final bool readOnly;

  const StartFromScratchPage({
    super.key,
    this.proposalId,
    this.initialTitle,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlankDocumentEditorPage(
      proposalId: proposalId,
      proposalTitle: initialTitle ?? 'Untitled Document',
      initialTitle: initialTitle ?? 'Untitled Document',
      aiGeneratedSections: null,
      readOnly: readOnly,
    );
  }
}
