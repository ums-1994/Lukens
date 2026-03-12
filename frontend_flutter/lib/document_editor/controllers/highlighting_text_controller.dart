import 'package:flutter/material.dart';

class HighlightRange {
  final int start;
  final int end;
  final Color color;
  final int? commentId;

  const HighlightRange({
    required this.start,
    required this.end,
    required this.color,
    this.commentId,
  });
}

class HighlightingTextController extends TextEditingController {
  List<HighlightRange> _highlights = const [];

  HighlightingTextController({String? text}) : super(text: text);

  List<HighlightRange> get highlights => _highlights;

  void setHighlights(List<HighlightRange> ranges) {
    _highlights = ranges;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textValue = text;
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;

    if (_highlights.isEmpty || textValue.isEmpty) {
      return TextSpan(style: effectiveStyle, text: textValue);
    }

    final ranges = List<HighlightRange>.from(_highlights)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    int index = 0;

    for (final range in ranges) {
      final start = range.start.clamp(0, textValue.length);
      final end = range.end.clamp(0, textValue.length);
      if (end <= start) continue;
      if (start < index) continue;

      if (start > index) {
        spans.add(
          TextSpan(
            style: effectiveStyle,
            text: textValue.substring(index, start),
          ),
        );
      }

      spans.add(
        TextSpan(
          style: effectiveStyle.copyWith(backgroundColor: range.color),
          text: textValue.substring(start, end),
        ),
      );

      index = end;
    }

    if (index < textValue.length) {
      spans.add(
        TextSpan(
          style: effectiveStyle,
          text: textValue.substring(index),
        ),
      );
    }

    return TextSpan(style: effectiveStyle, children: spans);
  }
}
