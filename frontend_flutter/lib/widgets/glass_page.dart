import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';

class GlassPage extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool scroll;

  const GlassPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.all(16),
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = GlassContainer(
      borderRadius: 24,
      padding: padding,
      child: child,
    );

    return SafeArea(
      child: Padding(
        padding: margin,
        child: scroll
            ? SingleChildScrollView(
                child: content,
              )
            : content,
      ),
    );
  }
}









































