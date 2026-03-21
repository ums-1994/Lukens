/// Word-style rich document formatting models.
///
/// Note: rendering should be driven by the editor's native rich delta
/// (`richContentDelta`). These models exist to make the formatting
/// serialization explicit and testable.

class DocumentModel {
  final List<ParagraphModel> paragraphs;

  DocumentModel({required this.paragraphs});

  Map<String, dynamic> toJson() => {
        'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      paragraphs: (json['paragraphs'] as List<dynamic>? ?? [])
          .map((e) => ParagraphModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ParagraphModel {
  final String alignment; // left|center|right|justify
  final String lineSpacing; // 1.0|1.5|2.0 (single|1.5|double)
  final String listType; // bullet|numbered|none
  final List<TextRun> spans;

  ParagraphModel({
    required this.alignment,
    required this.lineSpacing,
    required this.listType,
    required this.spans,
  });

  Map<String, dynamic> toJson() => {
        'alignment': alignment,
        'spacing': lineSpacing,
        'listType': listType,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  factory ParagraphModel.fromJson(Map<String, dynamic> json) {
    return ParagraphModel(
      alignment: (json['alignment'] ?? 'left').toString(),
      lineSpacing: (json['spacing'] ?? json['lineSpacing'] ?? '1.0').toString(),
      listType: (json['listType'] ?? 'none').toString(),
      spans: (json['spans'] as List<dynamic>? ?? [])
          .map((e) => TextRun.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class TextRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String fontFamily;
  final double fontSize;

  TextRun({
    required this.text,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strike,
    required this.fontFamily,
    required this.fontSize,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strike': strike,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
      };

  factory TextRun.fromJson(Map<String, dynamic> json) => TextRun(
        text: (json['text'] ?? '').toString(),
        bold: json['bold'] == true,
        italic: json['italic'] == true,
        underline: json['underline'] == true,
        strike: json['strike'] == true,
        fontFamily: (json['fontFamily'] ?? 'Arial').toString(),
        fontSize: (json['fontSize'] ?? 12).toDouble(),
      );
}

/// Convert a Quill delta exported by `flutter_quill` into an array of
/// [ParagraphModel] for explicit formatting persistence.
///
/// This is used for schema serialization/testing. Rendering should prefer
/// `richContentDelta`.
List<ParagraphModel> paragraphsFromQuillDelta(
  List<dynamic> deltaOps, {
  required String defaultFontFamily,
  required double defaultFontSize,
  String defaultAlignment = 'left',
  String defaultLineSpacing = '1.0',
}) {
  String currentAlignment = defaultAlignment;
  String currentLineSpacing = defaultLineSpacing;
  String currentListType = 'none';

  final paragraphs = <ParagraphModel>[];
  List<TextRun> currentSpans = <TextRun>[];

  void flushParagraph({required Map<String, dynamic> attrs}) {
    final hasMeaningfulText =
        currentSpans.any((s) => s.text.trim().isNotEmpty);
    if (!hasMeaningfulText) return;

    paragraphs.add(
      ParagraphModel(
        alignment: currentAlignment,
        lineSpacing: currentLineSpacing,
        listType: currentListType,
        spans: currentSpans,
      ),
    );
    currentSpans = <TextRun>[];

    // Update block attrs for the next paragraph line based on newline attrs.
    final align = attrs['align']?.toString();
    if (align != null && align.isNotEmpty) currentAlignment = align;

    final lh = attrs['line-height'];
    if (lh != null) {
      final v = lh is num ? lh.toString() : lh.toString();
      currentLineSpacing = v;
    }

    final list = attrs['list']?.toString();
    if (list != null) {
      currentListType =
          list == 'bullet' ? 'bullet' : (list == 'ordered' ? 'numbered' : 'none');
    } else {
      currentListType = 'none';
    }
  }

  for (final op in deltaOps) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is! String) continue;
    final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final isLast = i == parts.length - 1;

      if (part.isNotEmpty) {
        final fontFamily = attrs['font']?.toString() ?? defaultFontFamily;
        final fontSizeRaw = attrs['size'];
        final fontSize = fontSizeRaw == null
            ? defaultFontSize
            : (fontSizeRaw is num
                ? fontSizeRaw.toDouble()
                : double.tryParse(fontSizeRaw.toString()) ?? defaultFontSize);

        currentSpans.add(
          TextRun(
            text: part,
            bold: attrs['bold'] == true,
            italic: attrs['italic'] == true,
            underline: attrs['underline'] == true,
            strike: attrs['strike'] == true,
            fontFamily: fontFamily,
            fontSize: fontSize,
          ),
        );
      }

      if (!isLast) {
        flushParagraph(attrs: attrs);
      }
    }
  }

  // Remaining tail
  if (currentSpans.any((s) => s.text.trim().isNotEmpty)) {
    paragraphs.add(
      ParagraphModel(
        alignment: currentAlignment,
        lineSpacing: currentLineSpacing,
        listType: currentListType,
        spans: currentSpans,
      ),
    );
  }

  // Normalize spacing values to canonical set when possible.
  for (final p in paragraphs) {
    if (p.lineSpacing == '1' || p.lineSpacing == '1.0') {
      p; // no-op (kept as-is)
    }
  }
  return paragraphs;
}

