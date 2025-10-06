import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'pages/creator_dashboard_page.dart';
import 'widgets/app_side_nav.dart';
import 'pages/compose_page.dart';
import 'pages/govern_page.dart';
import 'pages/approvals_page.dart';
import 'pages/preview_page.dart';
import 'pages/content_library_page.dart';
import 'pages/approver_dashboard_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/client_portal_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/email_verification_page.dart';
import 'pages/startup_page.dart';
import 'pages/proposals_page.dart';
import 'pages/templates_page.dart';
import 'pages/collaboration_page.dart';
import 'pages/analytics_page.dart';
import 'services/auth_service.dart';
import 'api.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      // Initialize Firebase for web using options matching web/firebase-config.js
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyC0WT1ArMcm6Ah8jM_hNaE9uffM1aTriBc',
          authDomain: 'lukens-e17d6.firebaseapp.com',
          databaseURL: 'https://lukens-e17d6-default-rtdb.firebaseio.com',
          projectId: 'lukens-e17d6',
          storageBucket: 'lukens-e17d6.firebasestorage.app',
          messagingSenderId: '940107272310',
          appId: '1:940107272310:web:bc6601706e2fe1d94d8f57',
          measurementId: 'G-QBLQ7YBNGQ',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // Ignore if already initialized or not required
  }
  // Restore persisted auth session on startup (web)
  AuthService.restoreSessionFromStorage();
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
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
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
          '/content': (context) => const ContentLibraryPage(), // Add missing route
          '/approvals': (context) => const ApprovalsPage(),
          '/approver_dashboard': (context) => const ApproverDashboardPage(),
          '/admin_dashboard': (context) => const AdminDashboardPage(),
          '/client_portal': (context) => const ClientPortalPage(),
          '/templates': (context) => const TemplatesPage(),
          '/collaboration': (context) => const CollaborationPage(),
          '/analytics': (context) => const AnalyticsPage(),
          '/team_details': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map?;
            final id = args != null ? (args['teamId'] ?? '') : '';
            return Scaffold(
              appBar: AppBar(title: const Text('Team')),
              body: Center(child: Text('Team: $id')),
            );
          },
          '/workspace': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map?;
            final name = args != null ? (args['workspaceName'] ?? '') : '';
            return Scaffold(
              appBar: AppBar(title: const Text('Workspace')),
              body: Center(child: Text('Workspace: $name')),
            );
          },
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
      return const StartupPage();
    }
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIdx});
  final int? initialIdx;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _isCollapsed = true;
  String _current = 'Dashboard';
  int idx = 0;
  final pages = [
    DashboardPage(),                 // 0
    ProposalsPage(),                 // 1
    TemplatesPage(),                 // 2
    ContentLibraryPage(),            // 3
    CollaborationPage(),             // 4
    ApprovalsPage(),                 // 5
    AnalyticsPage(),                 // 6
    PreviewPage(),                   // 7 (optional)
    ComposePage(),                   // 8 (optional)
    GovernPage(),                    // 9 (optional)
    ApproverDashboardPage(),         // 10 (optional)
    AdminDashboardPage(),            // 11 (optional)
    ClientPortalPage(),              // 12 (optional)
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.initialIdx != null && idx != widget.initialIdx) {
      // initialize once with desired index
      idx = widget.initialIdx!;
      _current = _labelForIdx(idx);
    }
    return Scaffold(
      body: Row(
        children: [
          AppSideNav(
            isCollapsed: _isCollapsed,
            currentLabel: _current,
            onToggle: () => setState(() => _isCollapsed = !_isCollapsed),
            onSelect: (label) {
              setState(() => _current = label);
              setState(() => idx = _idxForLabel(label));
            },
          ),
          Expanded(child: pages[idx]),
        ],
      ),
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

  int _idxForLabel(String label) {
    switch (label) {
      case 'Dashboard': return 0;
      case 'My Proposals': return 1;
      case 'Templates': return 2;
      case 'Content Library': return 3;
      case 'Collaboration': return 4;
      case 'Approvals Status': return 5;
      case 'Analytics (My Pipeline)': return 6;
      case 'Preview': return 7;
      default: return 0;
    }
  }

  String _labelForIdx(int i) {
    switch (i) {
      case 0: return 'Dashboard';
      case 1: return 'My Proposals';
      case 2: return 'Templates';
      case 3: return 'Content Library';
      case 4: return 'Collaboration';
      case 5: return 'Approvals Status';
      case 6: return 'Analytics (My Pipeline)';
      case 7: return 'Preview';
      default: return 'Dashboard';
    }
  }
}
