import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../services/auth_service.dart';

/// Shared navigation and session actions for manager AppSideNav flows.
class ManagerSessionActions {
  ManagerSessionActions._();

  static const String accountProfileRoute = '/manager_account_profile';

  static void goToAccountProfile(BuildContext context) {
    Navigator.pushNamed(context, accountProfileRoute);
  }

  static Future<void> showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final app = context.read<AppState>();
    app.logout();
    AuthService.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}
