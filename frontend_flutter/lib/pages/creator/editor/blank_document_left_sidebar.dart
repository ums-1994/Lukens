part of '../blank_document_editor_page.dart';

/// Thin wrapper widget for the left navigation sidebar.
///
/// This keeps the main editor file smaller while still allowing the state
/// object to own all of the business logic via the provided [builder].
class BlankDocumentLeftSidebar extends StatelessWidget {
  final Widget Function() builder;

  const BlankDocumentLeftSidebar({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => builder();
}



