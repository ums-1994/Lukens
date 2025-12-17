import 'package:flutter/material.dart';

import 'inline_image.dart';
import 'document_table.dart';

class DocumentSection {
  String title;
  String content;
  final TextEditingController controller;
  final TextEditingController titleController;
  final FocusNode contentFocus;
  final FocusNode titleFocus;
  Color backgroundColor;
  String? backgroundImageUrl;
  String sectionType; // 'cover', 'content', 'appendix', etc.
  bool isCoverPage;
  List<InlineImage> inlineImages; // Inline content images (not backgrounds)
  List<DocumentTable> tables; // Tables in this section

  DocumentSection({
    required this.title,
    required this.content,
    this.backgroundColor = Colors.white,
    this.backgroundImageUrl,
    this.sectionType = 'content',
    this.isCoverPage = false,
    List<InlineImage>? inlineImages,
    List<DocumentTable>? tables,
  })  : controller = TextEditingController(text: content),
        titleController = TextEditingController(text: title),
        contentFocus = FocusNode(),
        titleFocus = FocusNode(),
        inlineImages = inlineImages ?? [],
        tables = tables ?? [];
}
