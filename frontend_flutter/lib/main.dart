import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'pages/creator/creator_dashboard_page.dart';
import 'pages/creator/compose_page.dart';
import 'pages/creator/proposal_wizard.dart';
import 'pages/creator/new_proposal_page.dart';
import 'pages/creator/enhanced_compose_page.dart';
import 'pages/admin/govern_page.dart';
import 'pages/approver/approvals_page.dart';
import 'pages/shared/preview_page.dart';
import 'pages/creator/content_library_page.dart';
import 'pages/approver/approver_dashboard_page.dart';
import 'pages/approver/reviewer_proposals_page.dart';
import 'pages/approver/comments_feedback_page.dart';
import 'pages/approver/approval_history_page.dart';
import 'pages/approver/governance_checks_page.dart';
import 'pages/client/client_portal_page.dart';
import 'pages/client/enhanced_client_dashboard.dart';
import 'pages/test_signature_page.dart';
import 'pages/shared/login_page.dart';
import 'pages/shared/register_page.dart';
import 'pages/shared/email_verification_page.dart';
import 'pages/shared/startup_page.dart';
import 'pages/shared/proposals_page.dart';
import 'pages/creator/templates_page.dart';
import 'pages/creator/collaboration_page.dart';
import 'pages/admin/analytics_page.dart';
import 'pages/admin/ai_configuration_page.dart';
import 'pages/creator/settings_page.dart';
import 'services/auth_service.dart';
import 'services/ai_analysis_service.dart';
import 'api.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase for web (required before using Firebase Auth popup)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } catch (_) {
    // ignore if already initialized / hot-reload
  }
  // Initialize AI service with your OpenAI API key
  AIAnalysisService.initialize();
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

          // Handle client portal with token
          if (settings.name == '/client-portal' ||
              (settings.name != null &&
                  settings.name!.contains('client-portal'))) {
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            final token = uri.queryParameters['token'];
            return MaterialPageRoute(
              builder: (context) => ClientPortalPage(token: token),
            );
          }

          // Handle enhanced client dashboard with token
          if (settings.name == '/enhanced-client-dashboard' ||
              (settings.name != null &&
                  settings.name!.contains('enhanced-client-dashboard'))) {
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            final token = uri.queryParameters['token'];
            return MaterialPageRoute(
              builder: (context) => EnhancedClientDashboard(token: token),
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
          '/proposal-wizard': (context) => const ProposalWizard(),
          '/new-proposal': (context) => const NewProposalPage(),
          '/enhanced-compose': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;
            return EnhancedComposePage(
              proposalId: args?['proposalId'] ?? '',
              proposalTitle: args?['proposalTitle'] ?? 'Untitled Proposal',
              templateType: args?['templateType'] ?? 'proposal',
              selectedModules:
                  List<String>.from(args?['selectedModules'] ?? []),
            );
          },
          '/govern': (context) => const GovernPage(),
          '/preview': (context) => const PreviewPage(),
          '/creator_dashboard': (context) => const DashboardPage(),
          '/content_library': (context) => const ContentLibraryPage(),
          '/approvals': (context) => const ApprovalsPage(),
          '/approver_dashboard': (context) => const ApproverDashboardPage(),
          '/reviewer/proposals': (context) => const ReviewerProposalsPage(),
          '/approver/comments': (context) => const CommentsFeedbackPage(),
          '/approver/history': (context) => const ApprovalHistoryPage(),
          '/approver/governance': (context) => const GovernanceChecksPage(),
          '/admin_dashboard': (context) => const DashboardPage(),
          '/client_portal': (context) {
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            final token = uri.queryParameters['token'];
            return ClientPortalPage(token: token);
          },
          '/templates': (context) => const TemplatesPage(),
          '/collaboration': (context) => const CollaborationPage(),
          '/analytics': (context) => const AnalyticsPage(),
          '/ai-configuration': (context) => const AIConfigurationPage(),
          '/settings': (context) => const SettingsPage(),
          '/test-signature': (context) => const TestSignaturePage(),
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
    // Check if we're on a client dashboard route
    final currentUrl = web.window.location.href;
    final uri = Uri.parse(currentUrl);

    if (uri.path.contains('enhanced-client-dashboard') ||
        uri.path.contains('client-portal')) {
      final token = uri.queryParameters['token'];
      if (uri.path.contains('enhanced-client-dashboard')) {
        return EnhancedClientDashboard(token: token);
      } else {
        return ClientPortalPage(token: token);
      }
    }

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
    DashboardPage(), // Admin role entry
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
