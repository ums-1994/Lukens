import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lukens/pages/admin/approver_dashboard_page.dart';
import 'package:lukens/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:lukens/api.dart';

// Lightweight test AppState that avoids network calls
class TestAppState extends AppState {
  @override
  Future<void> fetchProposals() async {
    proposals = [];
    return;
  }

  @override
  Future<void> fetchNotifications() async {
    notifications = [];
    unreadNotifications = 0;
    return;
  }

  @override
  Future<void> fetchTemplates() async {
    templates = [];
    return;
  }

  @override
  Future<void> fetchContent() async {
    contentBlocks = [];
    return;
  }
}

void main() {
  testWidgets('Approver dashboard shows CTAs and hides Risk Gate', (WidgetTester tester) async {
    // Arrange: set an admin user session
    AuthService.setUserData({'role': 'admin', 'email': 'admin@example.com'}, 'token');

    await tester.pumpWidget(
      Provider<AppState>.value(
        value: TestAppState(),
        child: MaterialApp(
          home: Scaffold(body: ApproverDashboardPage()),
        ),
      ),
    );

    // Allow any async init work to run
    await tester.pumpAndSettle();

    // Assert: Risk Gate section should be absent (we removed it)
    expect(find.text('Risk Gate'), findsNothing);

    // Assert: View buttons exist for the attention rows
    expect(find.text('View'), findsWidgets);
  });
}
