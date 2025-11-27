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
