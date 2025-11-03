import 'package:flutter/material.dart';

extension ColorExtension on Color {
  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
  }) {
    return Color.fromRGBO(
      // ignore: deprecated_member_use
      red != null ? red.toInt() : this.red,
      // ignore: deprecated_member_use
      green != null ? green.toInt() : this.green,
      // ignore: deprecated_member_use
      blue != null ? blue.toInt() : this.blue,
      // ignore: deprecated_member_use
      alpha != null ? alpha : this.opacity,
    );
  }
}
