import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final isLoggedIn = AuthService.isLoggedIn;
    
    final themedChild = Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        dialogBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      child: child,
    );

    return Stack(
      children: [
        // Background image for logged-in users, gradient for others
        if (isLoggedIn)
          // Background image for authenticated screens
          Positioned.fill(
            child: Image.asset(
              'assets/images/Global BG.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) {
                // Fallback: show a subtle gradient if asset fails to load
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1F2937),
                        Color(0xFF111827),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else
          // Gradient background for login/register pages
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
        // No overlay to ensure the image is clearly visible
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
        // Page content with transparent Scaffold background
        themedChild,
      ],
    );
  }
}


