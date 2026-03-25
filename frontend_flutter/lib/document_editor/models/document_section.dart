import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';

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
  final QuillController richController;
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
  String lineSpacing; // '1.0', '1.5', '2.0'
  String paragraphAlignment; // 'left', 'center', 'right', 'justify'
  List<Map<String, dynamic>> richParagraphs;

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
    this.lineSpacing = '1.0',
    this.paragraphAlignment = 'left',
    List<Map<String, dynamic>>? richParagraphs,
    String? richDeltaJson,
  })  : id = id ?? _newId(),
        contentEditableKey = GlobalKey<EditableTextState>(),
        controller = HighlightingTextController(text: content),
        richController = _buildRichController(content, richDeltaJson),
        titleController = TextEditingController(text: title),
        contentFocus = FocusNode(),
        titleFocus = FocusNode(),
        inlineImages = inlineImages ?? [],
        tables = tables ?? [],
        positionedPricingTables = positionedPricingTables ?? [],
        richParagraphs = richParagraphs ?? [];

  static QuillController _buildRichController(
    String plainText,
    String? richDeltaJson,
  ) {
    try {
      if (richDeltaJson != null && richDeltaJson.trim().isNotEmpty) {
        final decoded = jsonDecode(richDeltaJson);
        if (decoded is List) {
          final doc = Document.fromJson(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
          return QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      }
    } catch (_) {
      // Fallback to plain text document.
    }
    final doc = Document();
    if (plainText.isNotEmpty) {
      doc.insert(0, plainText);
    }
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  List<Map<String, dynamic>> exportRichDelta() {
    final delta = richController.document.toDelta().toJson();
    return delta.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void syncPlainTextFromRich() {
    final text = richController.document.toPlainText().replaceAll('\u0000', '');
    final richSel = richController.selection;
    final safeBase = richSel.baseOffset.clamp(0, text.length).toInt();
    final safeExtent = richSel.extentOffset.clamp(0, text.length).toInt();
    if (controller.text != text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: safeBase,
          extentOffset: safeExtent,
        ),
      );
    } else if (controller.selection.baseOffset != safeBase ||
        controller.selection.extentOffset != safeExtent) {
      controller.selection = TextSelection(
        baseOffset: safeBase,
        extentOffset: safeExtent,
      );
    }
    content = text;
  }

  void syncRichFromPlainText() {
    final plain = controller.text;
    final current = richController.document.toPlainText().replaceAll('\u0000', '');
    if (plain == current) return;
    final doc = Document();
    if (plain.isNotEmpty) {
      doc.insert(0, plain);
    }
    richController.document = doc;
    richController.updateSelection(
      TextSelection.collapsed(offset: plain.length),
      ChangeSource.local,
    );
  }
}
