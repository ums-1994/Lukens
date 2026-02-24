import 'package:flutter/material.dart';
import '../models/document_table.dart';

class TableWidget extends StatelessWidget {
  final int? sectionIndex;
  final int? tableIndex;
  final DocumentTable table;
  final String currencySymbol;
  final bool readOnly;

  final VoidCallback? onAddRow;
  final VoidCallback? onAddColumn;
  final VoidCallback? onDeleteTable;
  final void Function(int rowIndex, int colIndex, String value)? onCellChanged;

  const TableWidget({
    super.key,
    required this.sectionIndex,
    required this.tableIndex,
    required this.table,
    required this.currencySymbol,
    required this.readOnly,
    this.onAddRow,
    this.onAddColumn,
    this.onDeleteTable,
    this.onCellChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return _buildReadOnlyTable();
    }
    return _buildEditableTable();
  }

  Widget _buildEditableTable() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header with controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${table.type == 'price' ? 'Price' : 'Text'} Table',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      onPressed: onAddRow,
                      tooltip: 'Add Row',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.view_column, size: 18),
                      onPressed: table.type == 'price' ? null : onAddColumn,
                      tooltip: table.type == 'price'
                          ? 'Price tables have fixed columns'
                          : 'Add Column',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: onDeleteTable,
                      tooltip: 'Delete Table',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Table content
          Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                border: TableBorder.all(color: Colors.grey[300]!),
                columns: List.generate(
                  table.cells[0].length,
                  (colIndex) => DataColumn(
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        table.cells[0][colIndex],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                ),
                rows: List.generate(
                  table.cells.length - 1,
                  (rowIndex) => DataRow(
                    cells: List.generate(
                      table.cells[rowIndex + 1].length,
                      (colIndex) => DataCell(
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            controller: TextEditingController(
                              text: table.cells[rowIndex + 1][colIndex],
                            ),
                            onChanged: (value) {
                              if (onCellChanged != null) {
                                onCellChanged!(rowIndex + 1, colIndex, value);
                              }
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(8),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              textBaseline: TextBaseline.alphabetic,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Price table footer
          if (table.type == 'price') ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Subtotal: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$currencySymbol${table.getSubtotal().toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'VAT (${(table.vatRate * 100).toStringAsFixed(0)}%): ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$currencySymbol${table.getVAT().toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Total: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$currencySymbol${table.getTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadOnlyTable() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              '${table.type == 'price' ? 'Price' : 'Text'} Table',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
              border: TableBorder.all(color: Colors.grey[300]!),
              columns: List.generate(
                table.cells[0].length,
                (colIndex) => DataColumn(
                  label: Text(
                    table.cells[0][colIndex],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              rows: List.generate(
                table.cells.length - 1,
                (rowIndex) => DataRow(
                  cells: List.generate(
                    table.cells[rowIndex + 1].length,
                    (colIndex) => DataCell(
                      Text(
                        table.cells[rowIndex + 1][colIndex],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (table.type == 'price') ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Subtotal: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$currencySymbol${table.getSubtotal().toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'VAT (${(table.vatRate * 100).toStringAsFixed(0)}%): ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$currencySymbol${table.getVAT().toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Total: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$currencySymbol${table.getTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
