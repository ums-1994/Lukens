import 'package:flutter/material.dart';
import 'version_control_overlay.dart';
import 'version_control_config.dart';

class AppWrapper extends StatelessWidget {
  final Widget child;
  final bool? showVersionOverlay;

  const AppWrapper({
    super.key,
    required this.child,
    this.showVersionOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShow = showVersionOverlay ?? VersionControlConfig.shouldShow;
    
    return Stack(
      children: [
        child,
        if (shouldShow)
          const VersionControlOverlay(),
      ],
    );
  }
}
