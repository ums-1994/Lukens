import 'package:flutter/material.dart';
import '../services/auto_draft_service.dart';

class AutoSaveIndicator extends StatelessWidget {
  final AutoDraftService autoDraftService;

  const AutoSaveIndicator({
    super.key,
    required this.autoDraftService,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: autoDraftService,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(),
              const SizedBox(width: 6),
              _buildText(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    if (autoDraftService.isAutoSaving) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_getIconColor()),
        ),
      );
    }

    return Icon(
      _getIconData(),
      size: 12,
      color: _getIconColor(),
    );
  }

  Widget _buildText() {
    return Text(
      autoDraftService.getStatusMessage(),
      style: TextStyle(
        fontSize: 12,
        color: _getTextColor(),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Color _getBackgroundColor() {
    if (autoDraftService.isAutoSaving) {
      return const Color(0xFFE3F2FD); // Light blue
    }
    if (autoDraftService.hasUnsavedChanges) {
      return const Color(0xFFFFF3E0); // Light orange
    }
    return const Color(0xFFE8F5E8); // Light green
  }

  Color _getBorderColor() {
    if (autoDraftService.isAutoSaving) {
      return const Color(0xFF2196F3); // Blue
    }
    if (autoDraftService.hasUnsavedChanges) {
      return const Color(0xFFFF9800); // Orange
    }
    return const Color(0xFF4CAF50); // Green
  }

  Color _getIconColor() {
    if (autoDraftService.isAutoSaving) {
      return const Color(0xFF2196F3); // Blue
    }
    if (autoDraftService.hasUnsavedChanges) {
      return const Color(0xFFFF9800); // Orange
    }
    return const Color(0xFF4CAF50); // Green
  }

  Color _getTextColor() {
    if (autoDraftService.isAutoSaving) {
      return const Color(0xFF1976D2); // Dark blue
    }
    if (autoDraftService.hasUnsavedChanges) {
      return const Color(0xFFE65100); // Dark orange
    }
    return const Color(0xFF2E7D32); // Dark green
  }

  IconData _getIconData() {
    if (autoDraftService.hasUnsavedChanges) {
      return Icons.edit;
    }
    return Icons.check_circle;
  }
}
