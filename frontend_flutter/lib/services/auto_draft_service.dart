import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AutoDraftService extends ChangeNotifier {
  static const String baseUrl = 'http://localhost:8000';
  static const Duration _autoSaveInterval = Duration(seconds: 30);
  static const Duration _debounceDelay = Duration(seconds: 2);

  Timer? _autoSaveTimer;
  Timer? _debounceTimer;
  String? _currentProposalId;
  Map<String, dynamic>? _lastSavedData;
  bool _isAutoSaving = false;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSaveTime;
  String? _lastError;

  // Getters
  bool get isAutoSaving => _isAutoSaving;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  DateTime? get lastSaveTime => _lastSaveTime;
  String? get lastError => _lastError;

  /// Start auto-draft for a specific proposal
  void startAutoDraft(String proposalId, Map<String, dynamic> initialData) {
    _currentProposalId = proposalId;
    _lastSavedData = Map<String, dynamic>.from(initialData);
    _hasUnsavedChanges = false;
    _lastError = null;

    // Start the auto-save timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
      if (_hasUnsavedChanges && _currentProposalId != null) {
        _performAutoSave();
      }
    });

    notifyListeners();
  }

  /// Stop auto-draft
  void stopAutoDraft() {
    _autoSaveTimer?.cancel();
    _debounceTimer?.cancel();
    _currentProposalId = null;
    _lastSavedData = null;
    _hasUnsavedChanges = false;
    _isAutoSaving = false;
    _lastError = null;
    notifyListeners();
  }

  /// Mark data as changed and trigger debounced save
  void markChanged(Map<String, dynamic> newData) {
    if (_currentProposalId == null) return;

    // Update the last saved data with new data
    _lastSavedData = Map<String, dynamic>.from(newData);
    _hasUnsavedChanges = true;

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(_debounceDelay, () {
      if (_hasUnsavedChanges) {
        _performAutoSave();
      }
    });

    notifyListeners();
  }

  /// Force immediate save
  Future<bool> forceSave() async {
    if (_currentProposalId == null || !_hasUnsavedChanges) return true;

    _debounceTimer?.cancel();
    return await _performAutoSave();
  }

  /// Perform the actual auto-save
  Future<bool> _performAutoSave() async {
    if (_currentProposalId == null || _isAutoSaving) return false;

    _isAutoSaving = true;
    _lastError = null;
    notifyListeners();

    try {
      // Save as draft version (no authentication required for draft endpoints)
      final success =
          await _saveDraftVersion('', _currentProposalId!, _lastSavedData!);

      if (success) {
        _hasUnsavedChanges = false;
        _lastSaveTime = DateTime.now();
        _lastError = null;
      } else {
        _lastError = 'Failed to save draft';
      }

      return success;
    } catch (e) {
      _lastError = 'Auto-save error: $e';
      return false;
    } finally {
      _isAutoSaving = false;
      notifyListeners();
    }
  }

  /// Save draft version to backend
  Future<bool> _saveDraftVersion(
      String token, String proposalId, Map<String, dynamic> data) async {
    try {
      print('Auto-saving draft for proposal: $proposalId');
      print('Data to save: ${json.encode(data)}');

      final response = await http.post(
        Uri.parse('$baseUrl/proposals/$proposalId/autosave'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'sections': data['sections'] ?? {},
          'version': 'draft',
          'auto_saved': true,
          'timestamp': DateTime.now().toIso8601String(),
          'user_id':
              'current-user-id', // This should be replaced with actual user ID
        }),
      );

      print('Draft save response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving draft: $e');
      return false;
    }
  }

  /// Check if there are unsaved changes before navigation
  Future<bool> canNavigateAway() async {
    if (!_hasUnsavedChanges) return true;

    // Try to save before navigating away
    return await forceSave();
  }

  /// Get auto-save status message
  String getStatusMessage() {
    if (_isAutoSaving) return 'Auto-saving...';
    if (_hasUnsavedChanges) return 'Unsaved changes';
    if (_lastSaveTime != null) {
      final timeAgo = DateTime.now().difference(_lastSaveTime!);
      if (timeAgo.inMinutes < 1) {
        return 'Saved just now';
      } else if (timeAgo.inMinutes < 60) {
        return 'Saved ${timeAgo.inMinutes}m ago';
      } else {
        return 'Saved ${timeAgo.inHours}h ago';
      }
    }
    return 'No changes';
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// Mock user class for testing auto-save functionality
class MockUser {
  String get uid => 'mock-user-id';
  Future<String> getIdToken() async => 'mock-token';
}
