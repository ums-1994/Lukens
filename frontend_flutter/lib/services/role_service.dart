import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole {
  creator,
  finance,
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
        UserRole.finance,
        UserRole.approver,
        // UserRole.admin, // Uncomment when admin features are ready
      ];

  String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.creator:
        return 'CEO';
      case UserRole.finance:
        return 'Finance';
      case UserRole.approver:
        return 'Admin';
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
      case UserRole.finance:
        return '💰';
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
      case UserRole.finance:
        return 'Manage financial proposals and analytics';
      case UserRole.approver:
        return 'Review and approve proposals';
      case UserRole.admin:
        return 'System administration and approvals';
    }
  }

  // Map backend role to frontend UserRole
  UserRole mapBackendRoleToFrontendRole(String? backendRole) {
    if (backendRole == null) return UserRole.creator;

    final role = backendRole.toLowerCase().trim();

    // Admin roles → Approver (Admin Dashboard)
    if (role == 'admin' || role == 'ceo') {
      return UserRole.approver;
    }

    if (role == 'finance' || role == 'finance manager' || role == 'financial manager') {
      return UserRole.finance;
    }

    // Manager roles → Creator (Manager Dashboard)
    if (role == 'manager' || role == 'creator' || role == 'user') {
      return UserRole.creator;
    }

    // Default to creator
    return UserRole.creator;
  }

  // Initialize role from backend user data
  Future<void> initializeRoleFromUser(Map<String, dynamic>? userData) async {
    if (userData == null) return;

    final backendRole = userData['role']?.toString();
    final frontendRole = mapBackendRoleToFrontendRole(backendRole);

    _currentRole = frontendRole;

    // Persist role selection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', frontendRole.toString());

    print(
        '✅ Initialized role from backend: "$backendRole" → ${_getRoleName(frontendRole)}');
    notifyListeners();
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
        } else if (savedRole.contains('finance')) {
          _currentRole = UserRole.finance;
        } else if (savedRole.contains('approver')) {
          _currentRole = UserRole.approver;
        } else if (savedRole.contains('admin')) {
          _currentRole = UserRole.admin;
        } else if (savedRole.contains('finance')) {
          _currentRole = UserRole.finance;
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
  bool isFinance() => _currentRole == UserRole.finance;
  bool isApprover() => _currentRole == UserRole.approver;
  bool isAdmin() => _currentRole == UserRole.admin;

  // Check if user has access to a feature based on role
  bool canCreateProposals() => isCreator() || isAdmin();
  bool canApproveProposals() => isApprover() || isAdmin();
  bool canAccessAdmin() => isAdmin();
  bool canAccessFinance() => isFinance() || isAdmin();

  // Finance-specific permissions
  bool canReviewFinancials() => isFinance() || isAdmin();
  bool canEditPricing() => isFinance() || isAdmin();

  // General editing permissions (templates/content/proposals)
  bool canEditContentLibrary() => isCreator() || isAdmin();
  bool canEditTemplates() => isCreator() || isAdmin();
}
