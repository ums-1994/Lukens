import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  Map<String, dynamic>? currentUser;
  String? authToken;

  Future<void> init() async {
    // Initialize app state here if needed
  }

  Future<void> restoreAllTrash() async {
    // TODO: Implement restore all trash functionality
  }

  Future<void> emptyTrash() async {
    // TODO: Implement empty trash functionality  
  }

  Future<String> getUniqueContentKey(String fileName) async {
    // TODO: Implement unique key generation
    return '${DateTime.now().millisecondsSinceEpoch}_$fileName';
  }
}