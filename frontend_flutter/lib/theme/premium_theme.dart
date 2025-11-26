import 'package:flutter/material.dart';
import 'dart:ui';

/// Premium glassmorphic theme inspired by executive dashboards
class PremiumTheme {
  // Background colors - dark gradient
  static const darkBg1 = Color(0xFF0F1419);
  static const darkBg2 = Color(0xFF1A2332);
  static const darkBg3 = Color(0xFF243447);
  
  // Accent colors
  static const teal = Color(0xFF20E3B2);
  static const tealDark = Color(0xFF17B897);
  static const cyan = Color(0xFF00D9FF);
  static const purple = Color(0xFF9D4EDD);
  static const pink = Color(0xFFE91E63);
  static const orange = Color(0xFFFF6B35);
  
  // Status colors
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFEF5350);
  static const info = Color(0xFF42A5F5);
  
  // Text colors
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0BEC5);
  static const textTertiary = Color(0xFF78909C);
  
  // Glass effect colors
  static const glassWhite = Color(0x1AFFFFFF);
  static const glassWhiteBorder = Color(0x33FFFFFF);
  
  // Gradients
  static const tealGradient = LinearGradient(
    colors: [Color(0xFF20E3B2), Color(0xFF17B897)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const blueGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const purpleGradient = LinearGradient(
    colors: [Color(0xFF9D4EDD), Color(0xFF7209B7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const redGradient = LinearGradient(
    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const orangeGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Background gradient for pages
  static BoxDecoration get backgroundGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [darkBg1, darkBg2, darkBg3],
      stops: [0.0, 0.5, 1.0],
    ),
  );
  
  // Glass card decoration
  static BoxDecoration glassCard({
    double borderRadius = 20,
    Color? gradientStart,
    Color? gradientEnd,
  }) {
    return BoxDecoration(
      gradient: gradientStart != null && gradientEnd != null
          ? LinearGradient(
              colors: [
                gradientStart.withOpacity(0.15),
                gradientEnd.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : LinearGradient(
              colors: [
                glassWhite,
                const Color(0x0DFFFFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glassWhiteBorder,
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
  
  // Stat card with gradient
  static BoxDecoration statCard(Gradient gradient, {double borderRadius = 20}) {
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
  
  // Text styles
  static const displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -1,
  );
  
  static const displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.5,
  );
}

/// Glassmorphic container widget with blur effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? gradientStart;
  final Color? gradientEnd;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.gradientStart,
    this.gradientEnd,
    this.padding,
    this.width,
    this.height,
  });
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: PremiumTheme.glassCard(
            borderRadius: borderRadius,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Premium stat card with gradient and icon
class PremiumStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Gradient gradient;
  final VoidCallback? onTap;
  
  const PremiumStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    required this.gradient,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: PremiumTheme.statCard(gradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: PremiumTheme.displayMedium.copyWith(
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: PremiumTheme.labelMedium.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Alert/Critical issue card
class CriticalIssueCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onTap;
  
  const CriticalIssueCard({
    super.key,
    required this.title,
    required this.message,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: PremiumTheme.statCard(PremiumTheme.redGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: PremiumTheme.labelMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: PremiumTheme.titleLarge.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

