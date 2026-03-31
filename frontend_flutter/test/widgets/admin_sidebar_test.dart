import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lukens/widgets/admin/admin_sidebar.dart';
import 'package:lukens/services/auth_service.dart';

void main() {
  testWidgets('AdminSidebar hides Analytics for manager and shows for admin', (WidgetTester tester) async {
    // Set manager user
    AuthService.setUserData({'role': 'manager', 'email': 'mgr@example.com'}, 'token');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminSidebar(
          isCollapsed: false,
          currentPage: 'Dashboard',
          onToggle: () {},
          onSelect: (_) {},
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsNothing);

    // Set admin user
    AuthService.setUserData({'role': 'admin', 'email': 'admin@example.com'}, 'token');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminSidebar(
          isCollapsed: false,
          currentPage: 'Dashboard',
          onToggle: () {},
          onSelect: (_) {},
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
  });
}
