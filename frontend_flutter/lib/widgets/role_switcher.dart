import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/role_service.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roleService.getRoleIcon(roleService.currentRole),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  roleService.currentRoleName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Color(0xFF7F8C8D),
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
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCurrentRole 
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            roleService.getRoleIcon(role),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          roleService.getRoleName(role),
                          style: TextStyle(
                            fontWeight: isCurrentRole
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 15,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      if (isCurrentRole)
                        const Icon(
                          Icons.check,
                          size: 20,
                          color: Color(0xFF4CAF50),
                        ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
          onSelected: (role) async {
            if (role != roleService.currentRole) {
              // Switch role immediately
              await roleService.switchRole(role);

              if (context.mounted) {
                // Navigate based on role - clear navigation stack for seamless switching
                String targetRoute;
                if (role == UserRole.approver) {
                  targetRoute = '/approver_dashboard';
                } else if (role == UserRole.creator) {
                  targetRoute = '/home';
                } else if (role == UserRole.admin) {
                  targetRoute = '/admin_dashboard';
                } else {
                  targetRoute = '/home';
                }

                // Clear stack and navigate to new dashboard
                Navigator.of(context).pushNamedAndRemoveUntil(
                  targetRoute,
                  (route) => false,
                );
              }
            }
          },
        );
      },
    );
  }
}

// Compact version for header/toolbar (uses same clean design)
class CompactRoleSwitcher extends StatelessWidget {
  const CompactRoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleService>(
      builder: (context, roleService, child) {
        return PopupMenuButton<UserRole>(
          tooltip: 'Switch Role',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roleService.getRoleIcon(roleService.currentRole),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Color(0xFF7F8C8D),
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
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCurrentRole 
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            roleService.getRoleIcon(role),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        roleService.getRoleName(role),
                        style: TextStyle(
                          fontWeight: isCurrentRole ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      if (isCurrentRole) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check, size: 16, color: Color(0xFF4CAF50)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList();
          },
          onSelected: (role) async {
            if (role != roleService.currentRole) {
              // Switch role immediately
              await roleService.switchRole(role);

              if (context.mounted) {
                // Navigate based on role - clear navigation stack for seamless switching
                String targetRoute;
                if (role == UserRole.approver) {
                  targetRoute = '/approver_dashboard';
                } else if (role == UserRole.creator) {
                  targetRoute = '/home';
                } else if (role == UserRole.admin) {
                  targetRoute = '/admin_dashboard';
                } else {
                  targetRoute = '/home';
                }

                // Clear stack and navigate to new dashboard
                Navigator.of(context).pushNamedAndRemoveUntil(
                  targetRoute,
                  (route) => false,
                );
              }
            }
          },
        );
      },
    );
  }
}
