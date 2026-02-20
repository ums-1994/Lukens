import 'dart:math';

class InlineImage {
  final String id;
  String url;
  double width;
  double height;
  double x; // X position
  double y; // Y position

  static String _generateId() {
    final rand = Random();
    final ts = DateTime.now().microsecondsSinceEpoch;
    // NOTE: Avoid using bit shifts like (1 << 32) because in dart2js this can
    // overflow/truncate to 0, which breaks Random.nextInt.
    const max32 = 4294967296; // 2^32
    return 'img_${ts}_${rand.nextInt(max32)}';
  }

  InlineImage({
    String? id,
    required this.url,
    this.width = 300,
    this.height = 200,
    this.x = 0,
    this.y = 0,
  }) : id = id ?? _generateId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'width': width,
        'height': height,
        'x': x,
        'y': y,
      };

  factory InlineImage.fromJson(Map<String, dynamic> json) => InlineImage(
        id: json['id'] as String?,
        url: json['url'] as String,
        width: (json['width'] as num?)?.toDouble() ?? 300,
        height: (json['height'] as num?)?.toDouble() ?? 200,
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
      );
}
