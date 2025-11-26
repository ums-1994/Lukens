part of '../blank_document_editor_page.dart';

/// Wrapper for the main document area (sections/pages + right sidebar).
///
/// This keeps the top-level `build` method in `_BlankDocumentEditorPageState`
/// concise while the heavy UI is built via [builder].
class BlankDocumentBody extends StatelessWidget {
  final Widget Function() builder;

  const BlankDocumentBody({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => builder();
}



