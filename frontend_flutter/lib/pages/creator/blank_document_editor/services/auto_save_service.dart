import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../document_editor/models/document_section.dart';

/// Service for handling auto-save functionality
class AutoSaveService {
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  /// Get current unsaved changes state
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// Set unsaved changes flag
  void setUnsavedChanges(bool value) {
    _hasUnsavedChanges = value;
  }

  /// Setup auto-save listeners for sections and title controller
  void setupAutoSaveListeners({
    required TextEditingController titleController,
    required List<DocumentSection> sections,
    required VoidCallback onContentChanged,
  }) {
    // Listen to title changes
    titleController.addListener(onContentChanged);

    // Listen to all section changes
    for (var section in sections) {
      section.controller.addListener(onContentChanged);
      section.titleController.addListener(onContentChanged);
    }
  }

  /// Trigger content changed - will debounce and auto-save
  void onContentChanged({
    required VoidCallback onSave,
    Duration debounceDuration = const Duration(seconds: 3),
  }) {
    _hasUnsavedChanges = true;

    // Cancel existing timer
    _autoSaveTimer?.cancel();

    // Start new timer (debounced auto-save)
    _autoSaveTimer = Timer(debounceDuration, () {
      if (_hasUnsavedChanges) {
        onSave();
      }
    });
  }

  /// Cancel auto-save timer
  void cancel() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// Clear unsaved changes flag
  void clearUnsavedChanges() {
    _hasUnsavedChanges = false;
  }

  /// Dispose of the service
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }
}

