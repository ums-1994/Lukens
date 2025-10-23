import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'pages/creator/creator_dashboard_page.dart';
import 'pages/ceo_dashboard_page.dart';
import 'pages/financial_manager_dashboard_page.dart';
import 'pages/reviewer_dashboard_page.dart';
import 'pages/client_dashboard_page.dart';
import 'widgets/app_side_nav.dart';
import 'pages/creator/compose_page.dart';
import 'pages/admin/govern_page.dart';
import 'pages/approver/approvals_page.dart';
import 'pages/approver/approval_workflow_page.dart';
import 'pages/shared/preview_page.dart';
import 'pages/creator/content_library_page.dart';
import 'pages/creator/submit_for_approval_page.dart';
import 'pages/approver/approver_dashboard_page.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/client/client_portal_page.dart';
import 'pages/shared/login_page.dart';
import 'pages/shared/register_page.dart';
import 'pages/shared/email_verification_page.dart';
import 'pages/shared/startup_page.dart';
import 'pages/shared/proposals_page.dart';
import 'pages/creator/templates_page.dart';
import 'pages/creator/collaboration_page.dart';
import 'pages/admin/analytics_page.dart';
import 'pages/shared/cinematic_sequence_page.dart';
import 'pages/admin/admin_panel_page.dart';
import 'pages/admin/user_management_page.dart';
import 'pages/admin/system_settings_page.dart';
import 'pages/reviewer/pending_reviews_page.dart';
import 'pages/reviewer/review_queue_page.dart';
import 'pages/client/signed_documents_page.dart';
import 'pages/client/messages_page.dart';
import 'services/auth_service.dart';
import 'api.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/video_preload_service.dart';
import 'widgets/app_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize default role for testing
  AuthService.initializeDefaultRole();
  
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
  // Pre-initialize 3D earth video for fast first paint on CEO dashboard
  await VideoPreloadService.init('assets/images/3D earth.mp4');
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
          scaffoldBackgroundColor: Colors.transparent,
          canvasColor: Colors.transparent,
        ),
        builder: (context, child) {
          // Wrap every page with the landing-style background
          if (child == null) return const SizedBox.shrink();
          return AppBackground(child: child);
        },
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
          '/proposals': (context) => const HomeShell(initialIdx: 1),
          '/compose': (context) => const HomeShell(initialIdx: 8),
          '/govern': (context) => const HomeShell(initialIdx: 9),
          '/preview': (context) => const HomeShell(initialIdx: 7),
          '/creator_dashboard': (context) => const HomeShell(initialIdx: 0),
          '/content_library': (context) => const HomeShell(initialIdx: 3),
          '/content': (context) => const HomeShell(initialIdx: 3),
          '/approvals': (context) => const HomeShell(initialIdx: 5),
          '/approver_dashboard': (context) => const HomeShell(initialIdx: 10),
          '/admin_dashboard': (context) => const HomeShell(initialIdx: 11),
          '/client_portal': (context) => const HomeShell(initialIdx: 12),
          '/cinematic': (context) => const CinematicSequencePage(),
          '/templates': (context) => const HomeShell(initialIdx: 2),
          '/collaboration': (context) => const HomeShell(initialIdx: 4),
          '/analytics': (context) => const HomeShell(initialIdx: 6),
          '/user_management': (context) => const HomeShell(initialIdx: 10),
          '/system_settings': (context) => const HomeShell(initialIdx: 11),
          '/review_queue': (context) => const HomeShell(initialIdx: 1),
          '/pending_reviews': (context) => const HomeShell(initialIdx: 5),
          '/quality_metrics': (context) => const HomeShell(initialIdx: 6),
          '/review_history': (context) => const HomeShell(initialIdx: 3),
          '/signed_documents': (context) => const HomeShell(initialIdx: 3),
          '/messages': (context) => const HomeShell(initialIdx: 4),
          '/support': (context) => const HomeShell(initialIdx: 5),
          '/approval_history': (context) => const HomeShell(initialIdx: 3),
          '/approval_workflow': (context) => const ApprovalWorkflowPage(),
          '/submit_for_approval': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
            return SubmitForApprovalPage(
              proposalId: args?['proposalId'] ?? '',
              proposalTitle: args?['proposalTitle'] ?? 'Unknown Proposal',
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
  String? _lastRole;
  List<Widget> get pages {
    final userRole = AuthService.currentUser?['role'] ?? 'CEO';
    
    // Base pages that all roles can access
    final basePages = [
      _getDashboardForRole(userRole), // 0 - Role-specific dashboard
      ProposalsPage(), // 1
      TemplatesPage(), // 2
      ContentLibraryPage(), // 3
      CollaborationPage(), // 4
      ApprovalsPage(), // 5
      AnalyticsPage(), // 6
      PreviewPage(), // 7
      ComposePage(), // 8
      GovernPage(), // 9
      ApproverDashboardPage(), // 10
      AdminDashboardPage(), // 11
      ClientPortalPage(), // 12
    ];
    
    return basePages;
  }

  Widget _getDashboardForRole(String role) {
    switch (role) {
      case 'CEO':
        return const CEODashboardPage();
      case 'Financial Manager':
        return const FinancialManagerDashboardPage();
      case 'Reviewer':
        return const ReviewerDashboardPage();
      case 'Client':
        return const ClientDashboardPage();
      case 'Approver':
        return const ApproverDashboardPage();
      case 'Admin':
        return const AdminDashboardPage();
      default:
        return const CEODashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialIdx != null && idx != widget.initialIdx) {
      // initialize once with desired index
      idx = widget.initialIdx!;
      _current = _labelForIdx(idx);
    }
    
    // Force rebuild when role changes
    final currentRole = AuthService.currentUser?['role'] ?? 'CEO';
    if (_lastRole != currentRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _lastRole = currentRole;
          _current = 'Dashboard'; // Reset to dashboard when role changes
          idx = 0;
        });
      });
    }
    return Scaffold(
      body: Row(
        children: [
          AppSideNav(
            isCollapsed: _isCollapsed,
            currentLabel: _current,
            onToggle: () => setState(() => _isCollapsed = !_isCollapsed),
            onSelect: (label) {
              if (label == 'Logout') {
                _handleLogout();
                return;
              }
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
    final userRole = AuthService.currentUser?['role'] ?? 'Financial Manager';
    
    // Role-specific label mapping
    switch (userRole) {
      case 'CEO':
        switch (label) {
          case 'Dashboard': return 0;
          case 'My Proposals': return 1;
          case 'Analytics': return 6;
          case 'User Management': return 10;
          case 'System Settings': return 11;
          case 'Govern': return 9;
          default: return 0;
        }
      case 'Reviewer':
        switch (label) {
          case 'Dashboard': return 0;
          case 'Review Queue': return 1;
          case 'Pending Reviews': return 5;
          case 'Quality Metrics': return 6;
          case 'Review History': return 3;
          default: return 0;
        }
      case 'Client':
        switch (label) {
          case 'Dashboard': return 0;
          case 'My Proposals': return 1;
          case 'Signed Documents': return 3;
          case 'Messages': return 4;
          case 'Support': return 5;
          default: return 0;
        }
      case 'Approver':
        switch (label) {
          case 'Dashboard': return 0;
          case 'Approvals': return 5;
          case 'Approval History': return 3;
          case 'Analytics': return 6;
          default: return 0;
        }
      case 'Admin':
        switch (label) {
          case 'Dashboard': return 0;
          case 'User Management': return 10;
          case 'System Settings': return 11;
          case 'Analytics': return 6;
          case 'Govern': return 9;
          default: return 0;
        }
      default: // Financial Manager
        switch (label) {
          case 'Dashboard': return 0;
          case 'My Proposals': return 1;
          case 'Templates': return 2;
          case 'Content Library': return 3;
          case 'Collaboration': return 4;
          case 'Approvals Status': return 5;
          case 'Analytics': return 6;
          case 'Preview': return 7;
          default: return 0;
        }
    }
  }

  String _labelForIdx(int i) {
    final userRole = AuthService.currentUser?['role'] ?? 'Financial Manager';
    
    // Role-specific index mapping
    switch (userRole) {
      case 'CEO':
        switch (i) {
          case 0: return 'Dashboard';
          case 1: return 'My Proposals';
          case 6: return 'Analytics';
          case 10: return 'User Management';
          case 11: return 'System Settings';
          case 9: return 'Govern';
          default: return 'Dashboard';
        }
      case 'Reviewer':
        switch (i) {
          case 0: return 'Dashboard';
          case 1: return 'Review Queue';
          case 5: return 'Pending Reviews';
          case 6: return 'Quality Metrics';
          case 3: return 'Review History';
          default: return 'Dashboard';
        }
      case 'Client':
        switch (i) {
          case 0: return 'Dashboard';
          case 1: return 'My Proposals';
          case 3: return 'Signed Documents';
          case 4: return 'Messages';
          case 5: return 'Support';
          default: return 'Dashboard';
        }
      case 'Approver':
        switch (i) {
          case 0: return 'Dashboard';
          case 5: return 'Approvals';
          case 3: return 'Approval History';
          case 6: return 'Analytics';
          default: return 'Dashboard';
        }
      case 'Admin':
        switch (i) {
          case 0: return 'Dashboard';
          case 10: return 'User Management';
          case 11: return 'System Settings';
          case 6: return 'Analytics';
          case 9: return 'Govern';
          default: return 'Dashboard';
        }
      default: // Financial Manager
        switch (i) {
          case 0: return 'Dashboard';
          case 1: return 'My Proposals';
          case 2: return 'Templates';
          case 3: return 'Content Library';
          case 4: return 'Collaboration';
          case 5: return 'Approvals Status';
          case 6: return 'Analytics';
          case 7: return 'Preview';
          default: return 'Dashboard';
        }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Perform logout
                final app = context.read<AppState>();
                app.logout();
                AuthService.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
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
  }
}
