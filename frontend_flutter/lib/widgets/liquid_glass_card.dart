import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    this.onTap,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    required this.child,
    this.tint = const Color(0x33FFFFFF),
    this.borderColor = const Color(0x55FFFFFF),
    this.highlightColor = const Color(0x22FFFFFF),
    this.shadowColor = const Color(0x33000000),
    this.blurSigma = 20,
  });

  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Widget child;
  final Color tint;
  final Color borderColor;
  final Color highlightColor;
  final Color shadowColor;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          // Liquid gradient layer
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
          ),
          // Subtle moving highlight (static for now)
          Positioned(
            top: -40,
            left: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlightColor,
              ),
            ),
          ),
          // Frosted blur effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(color: tint),
          ),
          // Content
          Container(
            padding: padding,
            child: child,
          ),
          // Border
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: borderColor, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final elevated = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 24, offset: const Offset(0, 12)),
        ],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: card,
    );

    if (onTap == null) return elevated;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.05),
        child: elevated,
      ),
    );
  }
}









