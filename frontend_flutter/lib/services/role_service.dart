import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole {
  creator,
  approver,
  admin,
}

class RoleService extends ChangeNotifier {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  UserRole _currentRole = UserRole.creator;

  UserRole get currentRole => _currentRole;
  String get currentRoleName => _getRoleName(_currentRole);

  // Available roles for the current user (can be expanded based on permissions)
  List<UserRole> get availableRoles => [
        UserRole.creator,
        UserRole.approver,
        // UserRole.admin, // Uncomment when admin features are ready
      ];

  String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.creator:
        return 'Creator';
      case UserRole.approver:
        return 'Approver (CEO)';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String _getRoleName(UserRole role) =>
      getRoleName(role); // Keep for internal use

  String getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.creator:
        return '✍️';
      case UserRole.approver:
        return '✅';
      case UserRole.admin:
        return '👑';
    }
  }

  String getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.creator:
        return 'Create and manage proposals';
      case UserRole.approver:
        return 'Review and approve proposals';
      case UserRole.admin:
        return 'System administration';
    }
  }

  Future<void> switchRole(UserRole newRole) async {
    _currentRole = newRole;

    // Persist role selection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole.toString());

    print('🔄 Switched role to: ${_getRoleName(newRole)}');
    notifyListeners();
  }

  Future<void> loadSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRole = prefs.getString('user_role');

      if (savedRole != null) {
        if (savedRole.contains('creator')) {
          _currentRole = UserRole.creator;
        } else if (savedRole.contains('approver')) {
          _currentRole = UserRole.approver;
        } else if (savedRole.contains('admin')) {
          _currentRole = UserRole.admin;
        }
        print('✅ Loaded saved role: ${_getRoleName(_currentRole)}');
      }
    } catch (e) {
      print('⚠️ Could not load saved role: $e');
    }
    notifyListeners();
  }

  bool hasRole(UserRole role) {
    return availableRoles.contains(role);
  }

  bool isCreator() => _currentRole == UserRole.creator;
  bool isApprover() => _currentRole == UserRole.approver;
  bool isAdmin() => _currentRole == UserRole.admin;

  // Check if user has access to a feature based on role
  bool canCreateProposals() => isCreator() || isAdmin();
  bool canApproveProposals() => isApprover() || isAdmin();
  bool canAccessAdmin() => isAdmin();
}
