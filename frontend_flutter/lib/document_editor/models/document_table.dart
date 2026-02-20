class DocumentTable {
  final String id;
  String type; // 'text' or 'price'
  List<List<String>> cells;
  double vatRate; // For price tables (default 15%)

  DocumentTable({
    String? id,
    this.type = 'text',
    List<List<String>>? cells,
    this.vatRate = 0.15,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        cells = cells ??
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

  int? _findHeaderIndex(List<String> headers, List<String> needles) {
    if (headers.isEmpty) return null;
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      for (final n in needles) {
        if (h == n || h.contains(n)) return i;
      }
    }
    return null;
  }

  int _fallbackIndex(int? index, int fallback) {
    return index ?? fallback;
  }

  int getPriceQuantityColumnIndex() {
    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    return _fallbackIndex(
      _findHeaderIndex(headers, ['quantity', 'qty', 'qnty', 'units']),
      2,
    );
  }

  int getPriceUnitPriceColumnIndex() {
    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    return _fallbackIndex(
      _findHeaderIndex(headers, ['unit price', 'price', 'rate', 'unit cost']),
      3,
    );
  }

  int getPriceTotalColumnIndex() {
    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    return _fallbackIndex(
      _findHeaderIndex(headers, ['total', 'amount', 'line total']),
      4,
    );
  }

  int getResolvedPriceTotalColumnIndex() {
    final base = getPriceTotalColumnIndex();
    if (cells.length < 2) return base;
    return _resolveNumericColumnIndex(cells[1], base);
  }

  int _resolveNumericColumnIndex(List<String> row, int preferredIndex) {
    if (preferredIndex < 0) return preferredIndex;
    if (preferredIndex >= row.length) return preferredIndex;

    final preferred = row[preferredIndex].trim();
    final preferredNumber = double.tryParse(preferred);

    if (preferredNumber != null) {
      return preferredIndex;
    }

    // Common library-table pattern: a placeholder/label column followed by the numeric column.
    if (preferredIndex + 1 < row.length) {
      final next = row[preferredIndex + 1].trim();
      if (double.tryParse(next) != null) {
        return preferredIndex + 1;
      }
    }

    return preferredIndex;
  }

  void recalculatePriceRowTotal(int rowIndex) {
    if (type != 'price') return;
    if (cells.isEmpty || rowIndex <= 0 || rowIndex >= cells.length) return;

    final qtyCol = getPriceQuantityColumnIndex();
    final unitCol = getPriceUnitPriceColumnIndex();
    final totalCol = getPriceTotalColumnIndex();

    final row = cells[rowIndex];
    if (row.isEmpty) return;

    final resolvedUnitCol = unitCol < row.length
        ? _resolveNumericColumnIndex(row, unitCol)
        : unitCol;
    final resolvedTotalCol = totalCol < row.length
        ? _resolveNumericColumnIndex(row, totalCol)
        : totalCol;

    if (row.length <= resolvedTotalCol) return;

    final qty = qtyCol < row.length ? double.tryParse(row[qtyCol]) ?? 0.0 : 0.0;
    final unit = resolvedUnitCol < row.length
        ? double.tryParse(row[resolvedUnitCol]) ?? 0.0
        : 0.0;

    row[resolvedTotalCol] = (qty * unit).toStringAsFixed(2);
  }

  double getSubtotal() {
    if (type != 'price' || cells.length < 2) return 0.0;

    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    final qtyCol = _fallbackIndex(
      _findHeaderIndex(headers, ['quantity', 'qty', 'qnty', 'units']),
      2,
    );
    final unitCol = _fallbackIndex(
      _findHeaderIndex(headers, ['unit price', 'price', 'rate', 'unit cost']),
      3,
    );
    final totalCol = _fallbackIndex(
      _findHeaderIndex(headers, ['total', 'amount', 'line total']),
      4,
    );

    double subtotal = 0.0;
    for (var i = 1; i < cells.length; i++) {
      final row = cells[i];

      double rowTotal = 0.0;
      if (totalCol < row.length) {
        rowTotal = double.tryParse(row[totalCol]) ?? 0.0;
      }

      if (rowTotal == 0.0) {
        final qty =
            qtyCol < row.length ? double.tryParse(row[qtyCol]) ?? 0.0 : 0.0;
        final unit =
            unitCol < row.length ? double.tryParse(row[unitCol]) ?? 0.0 : 0.0;
        rowTotal = qty * unit;
      }

      subtotal += rowTotal;
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
        'id': id,
        'type': type,
        'cells': cells,
        'vatRate': vatRate,
      };

  factory DocumentTable.fromJson(Map<String, dynamic> json) => DocumentTable(
        id: json['id']?.toString(),
        type: json['type'] as String? ?? 'text',
        cells: (json['cells'] as List<dynamic>?)
            ?.map((row) =>
                (row as List<dynamic>).map((cell) => cell.toString()).toList())
            .toList(),
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.15,
      );
}
