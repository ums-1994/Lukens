import 'package:flutter/material.dart';
import 'dart:math' as math;

class RealisticEarthWidget extends StatefulWidget {
  final double width;
  final double height;

  const RealisticEarthWidget({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<RealisticEarthWidget> createState() => _RealisticEarthWidgetState();
}

class _RealisticEarthWidgetState extends State<RealisticEarthWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _cloudController;
  late AnimationController _pulseController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _cloudAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Earth rotation (24 hours = 24 seconds for demo)
    _rotationController = AnimationController(
      duration: const Duration(seconds: 24),
      vsync: this,
    );
    
    // Cloud movement
    _cloudController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    // Subtle pulsing
    _pulseController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _cloudAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _cloudController,
      curve: Curves.linear,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationController.repeat();
    _cloudController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _cloudController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [
            const Color(0xFF000000),
            const Color(0xFF0A0A0A),
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Stars background
            ...List.generate(150, (index) {
              final random = math.Random(index);
              return Positioned(
                left: random.nextDouble() * widget.width,
                top: random.nextDouble() * widget.height,
                child: Container(
                  width: random.nextDouble() * 2 + 0.5,
                  height: random.nextDouble() * 2 + 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(random.nextDouble() * 0.8 + 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 1,
                        spreadRadius: 0.5,
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
                        width: widget.width * 0.75,
                        height: widget.height * 0.75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.2, -0.2),
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
                              blurRadius: 40,
                              spreadRadius: 15,
                            ),
                            BoxShadow(
                              color: const Color(0xFF4682B4).withOpacity(0.2),
                              blurRadius: 60,
                              spreadRadius: 25,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Continents with realistic shapes
                            _buildNorthAmerica(),
                            _buildEuropeAfrica(),
                            _buildAsia(),
                            _buildSouthAmerica(),
                            _buildAustralia(),
                            
                            // Clouds
                            AnimatedBuilder(
                              animation: _cloudAnimation,
                              builder: (context, child) {
                                return _buildClouds();
                              },
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
                width: widget.width * 0.85,
                height: widget.height * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.2),
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
                offset: Offset(-widget.width * 0.12, -widget.height * 0.12),
                child: Container(
                  width: widget.width * 0.25,
                  height: widget.height * 0.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFFFFF8DC).withOpacity(0.9),
                        const Color(0xFFFFF8DC).withOpacity(0.6),
                        const Color(0xFFFFF8DC).withOpacity(0.3),
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

  Widget _buildNorthAmerica() {
    return Positioned(
      left: widget.width * 0.05,
      top: widget.height * 0.1,
      child: Container(
        width: widget.width * 0.2,
        height: widget.height * 0.15,
        decoration: BoxDecoration(
          color: const Color(0xFF228B22),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            // Alaska
            Positioned(
              left: widget.width * 0.02,
              top: -widget.height * 0.02,
              child: Container(
                width: widget.width * 0.08,
                height: widget.height * 0.05,
                decoration: BoxDecoration(
                  color: const Color(0xFF228B22),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Greenland
            Positioned(
              right: widget.width * 0.01,
              top: widget.height * 0.02,
              child: Container(
                width: widget.width * 0.06,
                height: widget.height * 0.08,
                decoration: BoxDecoration(
                  color: const Color(0xFF228B22),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEuropeAfrica() {
    return Positioned(
      right: widget.width * 0.05,
      top: widget.height * 0.12,
      child: Container(
        width: widget.width * 0.12,
        height: widget.height * 0.25,
        decoration: BoxDecoration(
          color: const Color(0xFF228B22),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAsia() {
    return Positioned(
      right: widget.width * 0.01,
      top: widget.height * 0.08,
      child: Container(
        width: widget.width * 0.25,
        height: widget.height * 0.18,
        decoration: BoxDecoration(
          color: const Color(0xFF228B22),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildSouthAmerica() {
    return Positioned(
      left: widget.width * 0.12,
      bottom: widget.height * 0.12,
      child: Container(
        width: widget.width * 0.1,
        height: widget.height * 0.2,
        decoration: BoxDecoration(
          color: const Color(0xFF228B22),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildAustralia() {
    return Positioned(
      right: widget.width * 0.08,
      bottom: widget.height * 0.08,
      child: Container(
        width: widget.width * 0.08,
        height: widget.height * 0.06,
        decoration: BoxDecoration(
          color: const Color(0xFF228B22),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildClouds() {
    return Stack(
      children: [
        // Cloud 1
        Positioned(
          left: widget.width * 0.1,
          top: widget.height * 0.2,
          child: Transform.rotate(
            angle: _cloudAnimation.value * 0.5,
            child: Container(
              width: widget.width * 0.08,
              height: widget.height * 0.04,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // Cloud 2
        Positioned(
          right: widget.width * 0.15,
          top: widget.height * 0.25,
          child: Transform.rotate(
            angle: -_cloudAnimation.value * 0.3,
            child: Container(
              width: widget.width * 0.06,
              height: widget.height * 0.03,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        // Cloud 3
        Positioned(
          left: widget.width * 0.2,
          bottom: widget.height * 0.2,
          child: Transform.rotate(
            angle: _cloudAnimation.value * 0.7,
            child: Container(
              width: widget.width * 0.07,
              height: widget.height * 0.035,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}









