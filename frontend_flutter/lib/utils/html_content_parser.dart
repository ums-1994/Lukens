import '../document_editor/models/document_table.dart';

/// Result of parsing HTML content
class ParsedHtmlContent {
  final String plainText;
  final List<DocumentTable> tables;

  ParsedHtmlContent({
    required this.plainText,
    required this.tables,
  });
}

/// Result of table extraction
class _TableExtractionResult {
  final String contentWithoutTables;
  final List<DocumentTable> tables;

  _TableExtractionResult({
    required this.contentWithoutTables,
    required this.tables,
  });
}

/// Utility class for parsing HTML content from content library
class HtmlContentParser {
  /// Main parsing method - strips comments, extracts tables, and strips HTML tags
  static ParsedHtmlContent parseContent(String html) {
    if (html.isEmpty) {
      return ParsedHtmlContent(plainText: '', tables: []);
    }

    // Step 1: Remove HTML comments
    String content = _removeComments(html);

    // Step 2: Extract tables and replace with placeholders
    final tableExtractionResult = _extractTables(content);
    content = tableExtractionResult.contentWithoutTables;
    final List<DocumentTable> tables = tableExtractionResult.tables;

    // Step 3: Strip all remaining HTML tags to get plain text
    String plainText = _stripHtmlTags(content);

    // Clean up whitespace (multiple newlines to double newlines)
    plainText = plainText.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    plainText = plainText.trim();

    return ParsedHtmlContent(
      plainText: plainText,
      tables: tables,
    );
  }

  /// Remove HTML comments (<!-- ... -->)
  static String _removeComments(String html) {
    // Match HTML comments (including multi-line comments)
    final commentPattern = RegExp(r'<!--[\s\S]*?-->', multiLine: true);
    return html.replaceAll(commentPattern, '');
  }

  /// Extract HTML tables and convert to DocumentTable objects
  static _TableExtractionResult _extractTables(String html) {
    final List<DocumentTable> tables = [];
    String contentWithoutTables = html;

    // Pattern to match <table>...</table> including nested tags
    final tablePattern = RegExp(
      r'<table[^>]*>[\s\S]*?</table>',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = tablePattern.allMatches(html);
    int placeholderIndex = 0;

    for (final match in matches) {
      final tableHtml = match.group(0) ?? '';

      try {
        final table = _htmlTableToDocumentTable(tableHtml);
        if (table != null) {
          tables.add(table);
          // Replace table with placeholder to maintain position
          contentWithoutTables = contentWithoutTables.replaceFirst(
            tableHtml,
            '\n\n[TABLE_PLACEHOLDER_$placeholderIndex]\n\n',
          );
          placeholderIndex++;
        }
      } catch (e) {
        print('⚠️ Error parsing table: $e');
        // If table parsing fails, just remove it
        contentWithoutTables = contentWithoutTables.replaceFirst(tableHtml, '');
      }
    }

    return _TableExtractionResult(
      contentWithoutTables: contentWithoutTables,
      tables: tables,
    );
  }

  /// Convert HTML table to DocumentTable
  static DocumentTable? _htmlTableToDocumentTable(String tableHtml) {
    try {
      // Extract rows (handle thead and tbody)
      final rowPattern = RegExp(
        r'<tr[^>]*>[\s\S]*?</tr>',
        multiLine: true,
        caseSensitive: false,
      );

      final rowMatches = rowPattern.allMatches(tableHtml);
      final List<List<String>> rows = [];

      for (final rowMatch in rowMatches) {
        final rowHtml = rowMatch.group(0) ?? '';
        final cells = _extractCellsFromRow(rowHtml);
        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }

      if (rows.isEmpty) {
        return null;
      }

      // Check if it's a price table (look for price-related headers)
      bool isPriceTable = false;
      if (rows.isNotEmpty) {
        final firstRow = rows[0];
        final headerText = firstRow.join(' ').toLowerCase();
        isPriceTable = headerText.contains('price') ||
            headerText.contains('cost') ||
            headerText.contains('amount') ||
            headerText.contains('total') ||
            headerText.contains('quantity') ||
            headerText.contains('unit');
      }

      // Ensure all rows have same number of columns
      if (rows.isNotEmpty) {
        final maxCols =
            rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
        for (var row in rows) {
          while (row.length < maxCols) {
            row.add('');
          }
        }
      }

      // Determine table type and create DocumentTable
      if (isPriceTable) {
        // For price tables, ensure at least 5 columns (Item, Description, Quantity, Unit Price, Total)
        if (rows.isNotEmpty && rows[0].length < 5) {
          // Pad headers if needed
          final headers = rows[0];
          while (headers.length < 5) {
            headers.add('');
          }
          // Pad all other rows to match
          final maxCols = rows[0].length;
          for (var i = 1; i < rows.length; i++) {
            while (rows[i].length < maxCols) {
              rows[i].add('');
            }
          }
        }
        // Create price table with actual cells from HTML
        final table = DocumentTable.priceTable(vatRate: 0.15);
        table.cells = rows;
        return table;
      } else {
        // Text table - create with actual cells from HTML
        return DocumentTable(cells: rows);
      }
    } catch (e) {
      print('⚠️ Error converting HTML table to DocumentTable: $e');
      return null;
    }
  }

  /// Extract cells from a table row (<tr>)
  static List<String> _extractCellsFromRow(String rowHtml) {
    final List<String> cells = [];

    // Match both <th> and <td> elements
    final cellPattern = RegExp(
      r'<(?:th|td)[^>]*>([\s\S]*?)</(?:th|td)>',
      multiLine: true,
      caseSensitive: false,
    );

    final cellMatches = cellPattern.allMatches(rowHtml);
    for (final cellMatch in cellMatches) {
      final cellContent = cellMatch.group(1) ?? '';
      // Strip HTML tags from cell content and clean up whitespace
      final plainText = _stripHtmlTags(cellContent);
      cells.add(plainText.trim());
    }

    return cells;
  }

  /// Strip all HTML tags and return plain text
  static String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';

    // Remove script and style elements with their content
    String text = html.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );

    // Remove all HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode HTML entities
    text = _decodeHtmlEntities(text);

    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n');

    return text;
  }

  /// Decode common HTML entities
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
