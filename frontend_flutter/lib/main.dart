import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'pages/creator/creator_dashboard_page.dart';
import 'pages/creator/compose_page.dart';
import 'pages/admin/govern_page.dart';
import 'pages/approver/approvals_page.dart';
import 'pages/shared/preview_page.dart';
import 'pages/creator/content_library_page.dart';
import 'pages/approver/approver_dashboard_page.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/client/client_portal_page.dart';
import 'pages/shared/login_page.dart';
import 'pages/shared/register_page.dart';
import 'pages/shared/email_verification_page.dart';
import 'pages/shared/proposals_page.dart';
import 'pages/creator/templates_page.dart';
import 'pages/creator/collaboration_page.dart';
import 'pages/admin/analytics_page.dart';
import 'services/auth_service.dart';
import 'api.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'Lukens',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          // Handle verification routes
          if (settings.name == '/verify-email' ||
              (settings.name != null &&
                  settings.name!.contains('verify-email'))) {
            // Extract token from current URL query parameters
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            final token = uri.queryParameters['token'];
            return MaterialPageRoute(
              builder: (context) => EmailVerificationPage(token: token),
            );
          }
          return null; // Let other routes be handled normally
        },
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/verify-email': (context) {
            // This will be handled by onGenerateRoute, but adding as fallback
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            final token = uri.queryParameters['token'];
            return EmailVerificationPage(token: token);
          },
          '/verify': (context) {
            // Direct verification route
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            final token = uri.queryParameters['token'];
            return EmailVerificationPage(token: token);
          },
          '/home': (context) => const HomeShell(),
          '/proposals': (context) => ProposalsPage(),
          '/compose': (context) => const ComposePage(),
          '/govern': (context) => const GovernPage(),
          '/preview': (context) => const PreviewPage(),
          '/creator_dashboard': (context) => const DashboardPage(),
          '/content_library': (context) => const ContentLibraryPage(),
          '/approvals': (context) => const ApprovalsPage(),
          '/approver_dashboard': (context) => const ApproverDashboardPage(),
          '/admin_dashboard': (context) => const AdminDashboardPage(),
          '/client_portal': (context) => const ClientPortalPage(),
          '/templates': (context) => const TemplatesPage(),
          '/collaboration': (context) => const CollaborationPage(),
          '/analytics': (context) => const AnalyticsPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check if we're on a verification URL
    _checkVerificationUrl();
  }

  void _checkVerificationUrl() {
    final currentUrl = web.window.location.href;
    final uri = Uri.parse(currentUrl);

    // Check if this is a verification URL
    if (uri.queryParameters.containsKey('verify') &&
        uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        // Navigate to verification page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationPage(token: token),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    if (AuthService.isLoggedIn) {
      // Initialize AppState when user is logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().init();
      });
      return const HomeShell();
    } else {
      return const LoginPage();
    }
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  final pages = [
    DashboardPage(), // Business Developer - Dashboard view
    ProposalsPage(), // Business Developer - Proposals view
    ComposePage(),
    GovernPage(),
    ApprovalsPage(),
    PreviewPage(),
    ContentLibraryPage(),
    ApproverDashboardPage(),
    AdminDashboardPage(),
    ClientPortalPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[idx],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Switch Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: const Text('Business Developer - Dashboard'),
                    onTap: () {
                      setState(() => idx = 0);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Business Developer - Proposals'),
                    onTap: () {
                      setState(() => idx = 1);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.approval_outlined),
                    title: const Text('Reviewer / Approver'),
                    onTap: () {
                      setState(() => idx = 7);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Admin'),
                    onTap: () {
                      setState(() => idx = 8);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('Client Portal'),
                    onTap: () {
                      setState(() => idx = 9);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.swap_horiz),
        tooltip: 'Switch Role',
      ),
    );
  }
}
