import 'package:flutter/material.dart';

import '../controllers/highlighting_text_controller.dart';

import 'inline_image.dart';
import 'document_table.dart';
import 'positioned_pricing_table.dart';

class DocumentSection {
  final String id;
  final GlobalKey<EditableTextState> contentEditableKey;
  String title;
  String content;
  final HighlightingTextController controller;
  final TextEditingController titleController;
  final FocusNode contentFocus;
  final FocusNode titleFocus;
  Color backgroundColor;
  String? backgroundImageUrl;
  String sectionType; // 'cover', 'content', 'appendix', etc.
  bool isCoverPage;
  List<InlineImage> inlineImages; // Inline content images (not backgrounds)
  List<DocumentTable> tables; // Tables in this section
  List<PositionedPricingTable> positionedPricingTables;

  static int _idCounter = 0;
  static String _newId() {
    _idCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-${_idCounter.toString()}';
  }

  DocumentSection({
    String? id,
    required this.title,
    required this.content,
    this.backgroundColor = Colors.white,
    this.backgroundImageUrl,
    this.sectionType = 'content',
    this.isCoverPage = false,
    List<InlineImage>? inlineImages,
    List<DocumentTable>? tables,
    List<PositionedPricingTable>? positionedPricingTables,
  })  : id = id ?? _newId(),
        contentEditableKey = GlobalKey<EditableTextState>(),
        controller = HighlightingTextController(text: content),
        titleController = TextEditingController(text: title),
        contentFocus = FocusNode(),
        titleFocus = FocusNode(),
        inlineImages = inlineImages ?? [],
        tables = tables ?? [],
        positionedPricingTables = positionedPricingTables ?? [];
}
