import 'package:flutter/material.dart';

/// Custom visible scrollbar widget for consistent scrolling across all pages
class CustomScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final double thickness;
  final Color? thumbColor;
  final Color? trackColor;
  final Color? trackBorderColor;
  final ScrollbarOrientation? scrollbarOrientation;

  const CustomScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thickness = 16,
    // Use a vivid blue to make the scrollbar clearly visible
    this.thumbColor = const Color(0xFF3498DB),
    this.trackColor = const Color(0xFF1A1F26),
    this.trackBorderColor = const Color(0xFF2D3748),
    this.scrollbarOrientation,
  });

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: controller,
      thumbVisibility: true,
      thickness: thickness,
      radius: const Radius.circular(8),
      thumbColor: thumbColor,
      trackColor: trackColor,
      trackVisibility: true,
      trackBorderColor: trackBorderColor,
      scrollbarOrientation: scrollbarOrientation,
      child: child,
    );
  }
}
