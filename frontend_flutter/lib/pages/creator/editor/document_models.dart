part of '../blank_document_editor_page.dart';

class _DocumentSection {
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

  _DocumentSection({
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

class InlineImage {
  String url;
  double width;
  double height;
  double x; // X position
  double y; // Y position

  InlineImage({
    required this.url,
    this.width = 300,
    this.height = 200,
    this.x = 0,
    this.y = 0,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'width': width,
        'height': height,
        'x': x,
        'y': y,
      };

  factory InlineImage.fromJson(Map<String, dynamic> json) => InlineImage(
        url: json['url'] as String,
        width: (json['width'] as num?)?.toDouble() ?? 300,
        height: (json['height'] as num?)?.toDouble() ?? 200,
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
      );
}

class DocumentTable {
  String type; // 'text' or 'price'
  List<List<String>> cells;
  double vatRate; // For price tables (default 15%)

  DocumentTable({
    this.type = 'text',
    List<List<String>>? cells,
    this.vatRate = 0.15,
  }) : cells = cells ??
            [
              ['Header 1', 'Header 2', 'Header 3'],
              ['Row 1 Col 1', 'Row 1 Col 2', 'Row 1 Col 3'],
              ['Row 2 Col 1', 'Row 2 Col 2', 'Row 2 Col 3'],
            ];

  factory DocumentTable.priceTable({double vatRate = 0.15}) {
    return DocumentTable(
      type: 'price',
      vatRate: vatRate,
      cells: [
        ['Item', 'Description', 'Quantity', 'Unit Price', 'Total'],
        ['', '', '1', '0.00', '0.00'],
        ['', '', '1', '0.00', '0.00'],
      ],
    );
  }

  void addRow() {
    final newRow = List.generate(cells[0].length, (_) => '');
    cells.add(newRow);
  }

  void addColumn() {
    for (var row in cells) {
      row.add('');
    }
  }

  void removeRow(int index) {
    if (cells.length > 2 && index > 0) {
      // Keep at least header + 1 row
      cells.removeAt(index);
    }
  }

  void removeColumn(int index) {
    if (cells[0].length > 2) {
      // Keep at least 2 columns
      for (var row in cells) {
        if (index < row.length) {
          row.removeAt(index);
        }
      }
    }
  }

  double getSubtotal() {
    if (type != 'price' || cells.length < 2) return 0.0;

    double subtotal = 0.0;
    for (var i = 1; i < cells.length; i++) {
      final row = cells[i];
      if (row.length >= 5) {
        final total = double.tryParse(row[4]) ?? 0.0;
        subtotal += total;
      }
    }
    return subtotal;
  }

  double getVAT() {
    return getSubtotal() * vatRate;
  }

  double getTotal() {
    return getSubtotal() + getVAT();
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'cells': cells,
        'vatRate': vatRate,
      };

  factory DocumentTable.fromJson(Map<String, dynamic> json) => DocumentTable(
        type: json['type'] as String? ?? 'text',
        cells: (json['cells'] as List<dynamic>?)
            ?.map((row) =>
                (row as List<dynamic>).map((cell) => cell.toString()).toList())
            .toList(),
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.15,
      );
}

