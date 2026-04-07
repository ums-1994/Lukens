import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/manager_theme_controller.dart';

/// Full-bleed manager shell background (dark or light asset).
class ManagerPageBackground extends StatelessWidget {
  const ManagerPageBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<ManagerThemeController>().chrome;
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(chrome.backgroundAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
