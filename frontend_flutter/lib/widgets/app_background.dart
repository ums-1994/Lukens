import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background (from landing screen)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF000000),
                Color(0xFF0B0B0C),
                Color(0xFF1A1A1B),
              ],
            ),
          ),
        ),
        // Subtle radial glow bottom-right
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2C3E50).withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Page content
        child,
      ],
    );
  }
}


