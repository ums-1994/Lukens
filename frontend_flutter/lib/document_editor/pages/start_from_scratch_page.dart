import 'package:flutter/material.dart';
import '../../pages/creator/blank_document_editor_page.dart';
import '../../pages/creator/content_library_dialog.dart';

class StartFromScratchPage extends StatefulWidget {
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
  State<StartFromScratchPage> createState() => _StartFromScratchPageState();
}

class _StartFromScratchPageState extends State<StartFromScratchPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chooseCoverAndOpen());
  }

  Future<void> _chooseCoverAndOpen() async {
    if (!mounted || _navigated) return;
    _navigated = true;

    final String? effectiveProposalId =
        (widget.proposalId != null && widget.proposalId!.startsWith('temp-'))
            ? null
            : widget.proposalId;

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ContentLibrarySelectionDialog(
        parentFolderLabel: 'Cover',
        requireParentFolderMatch: true,
        imagesOnly: true,
        thumbnailsOnly: true,
        dialogTitle: 'Choose Cover (A4)',
      ),
    );

    final dynamic content = selected?['content'];
    final String? coverUrl = content is String ? content : null;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlankDocumentEditorPage(
          proposalId: effectiveProposalId,
          proposalTitle: widget.initialTitle ?? 'Untitled Document',
          initialTitle: widget.initialTitle ?? 'Untitled Document',
          aiGeneratedSections: null,
          initialCoverImageUrl: coverUrl,
          readOnly: widget.readOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
