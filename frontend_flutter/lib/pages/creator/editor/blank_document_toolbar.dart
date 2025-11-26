part of '../blank_document_editor_page.dart';

/// Thin wrapper widget for the top formatting toolbar.
///
/// The actual toolbar layout and behavior live in the state class; this
/// widget simply delegates building to the provided [builder] callback.
class BlankDocumentToolbar extends StatelessWidget {
  final Widget Function() builder;

  const BlankDocumentToolbar({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => builder();
}



