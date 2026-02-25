import 'document_table.dart';

class PositionedPricingTable {
  DocumentTable table;
  double x;
  double y;
  double width;

  PositionedPricingTable({
    required this.table,
    this.x = 0,
    this.y = 0,
    this.width = 700,
  });

  Map<String, dynamic> toJson() => {
        'table': table.toJson(),
        'x': x,
        'y': y,
        'width': width,
      };

  factory PositionedPricingTable.fromJson(Map<String, dynamic> json) {
    final tableJson = json['table'];
    final table = tableJson is Map<String, dynamic>
        ? DocumentTable.fromJson(tableJson)
        : DocumentTable.fromJson(Map<String, dynamic>.from(tableJson as Map));

    return PositionedPricingTable(
      table: table,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 700,
    );
  }
}
