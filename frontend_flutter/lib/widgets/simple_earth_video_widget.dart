import 'package:flutter/material.dart';
import 'dart:math' as math;

class SimpleEarthVideoWidget extends StatefulWidget {
  final double width;
  final double height;
  final String assetPath;

  const SimpleEarthVideoWidget({
    super.key,
    required this.width,
    required this.height,
    required this.assetPath,
  });

  @override
  State<SimpleEarthVideoWidget> createState() => _SimpleEarthVideoWidgetState();
}

class _SimpleEarthVideoWidgetState extends State<SimpleEarthVideoWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1.0,
            colors: [
              const Color(0xFF000000),
              const Color(0xFF0A0A0A),
              const Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Stars
            ...List.generate(100, (index) {
              final random = math.Random(index);
              return Positioned(
                left: random.nextDouble() * widget.width,
                top: random.nextDouble() * widget.height,
                child: Container(
                  width: random.nextDouble() * 3 + 1,
                  height: random.nextDouble() * 3 + 1,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(random.nextDouble() * 0.9 + 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 2,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Earth
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Container(
                        width: widget.width * 0.7,
                        height: widget.height * 0.7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.3),
                            radius: 1.0,
                            colors: [
                              const Color(0xFF87CEEB), // Sky blue
                              const Color(0xFF4682B4), // Steel blue
                              const Color(0xFF2E8B57), // Sea green
                              const Color(0xFF228B22), // Forest green
                              const Color(0xFF8B4513), // Saddle brown
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF87CEEB).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: const Color(0xFF4682B4).withOpacity(0.2),
                              blurRadius: 50,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Continents - North America
                            Positioned(
                              left: widget.width * 0.08,
                              top: widget.height * 0.12,
                              child: Container(
                                width: widget.width * 0.18,
                                height: widget.height * 0.12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF228B22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            // Europe/Africa
                            Positioned(
                              right: widget.width * 0.08,
                              top: widget.height * 0.15,
                              child: Container(
                                width: widget.width * 0.15,
                                height: widget.height * 0.2,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF228B22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            // Asia
                            Positioned(
                              right: widget.width * 0.02,
                              top: widget.height * 0.1,
                              child: Container(
                                width: widget.width * 0.2,
                                height: widget.height * 0.15,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF228B22),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                            // South America
                            Positioned(
                              left: widget.width * 0.15,
                              bottom: widget.height * 0.15,
                              child: Container(
                                width: widget.width * 0.12,
                                height: widget.height * 0.18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF228B22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            // Australia
                            Positioned(
                              right: widget.width * 0.1,
                              bottom: widget.height * 0.1,
                              child: Container(
                                width: widget.width * 0.08,
                                height: widget.height * 0.06,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF228B22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Atmospheric glow
            Center(
              child: Container(
                width: widget.width * 0.8,
                height: widget.height * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF87CEEB).withOpacity(0.1),
                      const Color(0xFF87CEEB).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Sunlight reflection
            Center(
              child: Transform.translate(
                offset: Offset(-widget.width * 0.1, -widget.height * 0.1),
                child: Container(
                  width: widget.width * 0.3,
                  height: widget.height * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFFFFF8DC).withOpacity(0.8),
                        const Color(0xFFFFF8DC).withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
