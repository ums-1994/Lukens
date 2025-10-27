import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final isLoggedIn = AuthService.isLoggedIn;
    
    return Stack(
      children: [
        // Background image for logged-in users, gradient for others
        if (isLoggedIn)
          // Background image for authenticated screens
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Global BG.jpg'),
                fit: BoxFit.cover,
              ),
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
        // Subtle overlay for better readability on image
        if (isLoggedIn)
          Container(
            color: Colors.black.withOpacity(0.3),
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


