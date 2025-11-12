import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleService>(
      builder: (context, roleService, child) {
        return PopupMenuButton<UserRole>(
          offset: const Offset(0, 50),
          tooltip: 'Switch Role',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3498DB),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roleService.getRoleIcon(roleService.currentRole),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Current Role',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                    Text(
                      roleService.currentRoleName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.swap_horiz,
                  size: 18,
                  color: Color(0xFF3498DB),
                ),
              ],
            ),
          ),
          itemBuilder: (context) {
            return roleService.availableRoles.map((role) {
              final isCurrentRole = role == roleService.currentRole;
              return PopupMenuItem<UserRole>(
                value: role,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isCurrentRole
                        ? const Color(0xFF3498DB).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        roleService.getRoleIcon(role),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  roleService.getRoleName(role),
                                  style: TextStyle(
                                    fontWeight: isCurrentRole
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isCurrentRole) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Color(0xFF2ECC71),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              roleService.getRoleDescription(role),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7F8C8D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
          onSelected: (role) async {
            if (role != roleService.currentRole) {
              print(
                  '🔄 Role switch requested from ${roleService.currentRole} to $role');
              print(
                  '🔑 Token before switch: ${AuthService.token != null ? "${AuthService.token!.substring(0, 20)}..." : "null"}');
              print(
                  '👤 User before switch: ${AuthService.currentUser?['email'] ?? "null"}');
              print('✅ isLoggedIn: ${AuthService.isLoggedIn}');

              await roleService.switchRole(role);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Text(roleService.getRoleIcon(role)),
                        const SizedBox(width: 12),
                        Text(
                            'Switched to ${roleService.getRoleName(role)} mode'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF3498DB),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );

                // Small delay to ensure state is updated
                await Future.delayed(const Duration(milliseconds: 100));

                print(
                    '🔑 Token after role switch: ${AuthService.token != null ? "${AuthService.token!.substring(0, 20)}..." : "null"}');

                // Navigate based on role
                if (context.mounted) {
                  if (role == UserRole.approver) {
                    print('➡️ Navigating to approver dashboard...');
                    Navigator.of(context)
                        .pushReplacementNamed('/approver_dashboard');
                  } else if (role == UserRole.creator) {
                    print('➡️ Navigating to creator dashboard...');
                    Navigator.of(context).pushReplacementNamed('/dashboard');
                  }
                }
              }
            }
          },
        );
      },
    );
  }
}

// Compact version for header/toolbar
class CompactRoleSwitcher extends StatelessWidget {
  const CompactRoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleService>(
      builder: (context, roleService, child) {
        return PopupMenuButton<UserRole>(
          tooltip: 'Switch Role',
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roleService.getRoleIcon(roleService.currentRole),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Color(0xFF3498DB),
                ),
              ],
            ),
          ),
          itemBuilder: (context) {
            return roleService.availableRoles.map((role) {
              final isCurrentRole = role == roleService.currentRole;
              return PopupMenuItem<UserRole>(
                value: role,
                child: Row(
                  children: [
                    Text(roleService.getRoleIcon(role)),
                    const SizedBox(width: 8),
                    Text(roleService.getRoleName(role)),
                    if (isCurrentRole) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check,
                          size: 16, color: Color(0xFF2ECC71)),
                    ],
                  ],
                ),
              );
            }).toList();
          },
          onSelected: (role) async {
            if (role != roleService.currentRole) {
              await roleService.switchRole(role);

              if (context.mounted) {
                // Small delay to ensure state is updated
                await Future.delayed(const Duration(milliseconds: 100));

                // Navigate based on role
                if (context.mounted) {
                  if (role == UserRole.approver) {
                    Navigator.of(context)
                        .pushReplacementNamed('/approver_dashboard');
                  } else if (role == UserRole.creator) {
                    Navigator.of(context).pushReplacementNamed('/dashboard');
                  }
                }
              }
            }
          },
        );
      },
    );
  }
}
