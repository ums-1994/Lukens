import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'pages/creator/creator_dashboard_page.dart';
import 'pages/creator/compose_page.dart';
import 'pages/creator/proposal_wizard.dart';
import 'pages/creator/new_proposal_page.dart';
import 'pages/creator/enhanced_compose_page.dart';
import 'pages/creator/blank_document_editor_page.dart';
import 'document_editor/pages/start_from_scratch_page.dart';
import 'pages/admin/govern_page.dart';
// import 'pages/approver/approvals_page.dart'; // Removed - using ApproverDashboardPage instead
import 'pages/shared/preview_page.dart';
import 'pages/creator/content_library_page.dart';
import 'pages/creator/templates_page.dart';
import 'pages/creator/template_builder.dart';
import 'pages/creator/client_management_page.dart';
import 'pages/admin/approver_dashboard_page.dart';
import 'pages/admin/admin_approvals_page.dart';
import 'pages/admin/proposal_review_page.dart';
import 'pages/finance_manager/finance_dashboard_v2.dart';
import 'pages/finance_manager/finance_onboarding_page.dart';
import 'pages/test_signature_page.dart';
import 'pages/shared/login_page.dart';
import 'pages/shared/register_page.dart';
import 'pages/shared/email_verification_page.dart';
import 'pages/shared/startup_page.dart';
import 'pages/shared/proposals_page.dart';
import 'pages/shared/approved_proposals_page.dart';
import 'pages/guest/guest_collaboration_page.dart';
import 'pages/shared/collaboration_router.dart';
import 'pages/client/client_onboarding_page.dart';
import 'pages/client/client_dashboard_home.dart';
import 'pages/admin/analytics_page.dart';
import 'pages/admin/ai_configuration_page.dart';
import 'pages/creator/settings_page.dart';
import 'pages/shared/cinematic_sequence_page.dart';
import 'services/auth_service.dart';
import 'services/role_service.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => RoleService()),
      ],
      child: MaterialApp(
        title: 'Lukens',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          textTheme: GoogleFonts.poppinsTextTheme(),
          scaffoldBackgroundColor: Colors.transparent,
        ),
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Global BG.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              if (child != null) child,
            ],
          );
        },
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          print('🔍 onGenerateRoute - Route name: ${settings.name}');

          // Handle collaboration routes with token
          if (settings.name == '/collaborate' ||
              (settings.name != null &&
                  settings.name!.contains('collaborate'))) {
            print('🔍 Collaboration route detected!');

            // Extract token from settings.name (it includes query params)
            String? token;

            // Try to get token from the route name itself
            if (settings.name != null && settings.name!.contains('token=')) {
              final uri = Uri.parse('http://dummy${settings.name}');
              token = uri.queryParameters['token'];
              print('📍 Token from route name: $token');
            }

            // Fallback: Try current URL
            if (token == null || token.isEmpty) {
              final currentUrl = web.window.location.href;
              print('📍 Trying current URL: $currentUrl');
              final uri = Uri.parse(currentUrl);

              // Check fragment for token
              if (uri.fragment.contains('token=')) {
                final fragmentUri =
                    Uri.parse('http://dummy?${uri.fragment.split('?').last}');
                token = fragmentUri.queryParameters['token'];
                print('📍 Token from fragment: $token');
              }
            }

            if (token != null && token.isNotEmpty) {
              print('✅ Token found, determining collaboration type...');
              // Use CollaborationRouter to determine which page to show
              final validToken = token; // Create non-nullable variable
              return MaterialPageRoute(
                builder: (context) => CollaborationRouter(token: validToken),
              );
            } else {
              print('❌ No token found, cannot navigate');
            }
          }

          // Handle client onboarding route
          if (settings.name == '/onboard' ||
              (settings.name != null && settings.name!.contains('onboard'))) {
            print('🔍 Client onboarding route detected: ${settings.name}');
            // Extract token from current URL - try multiple methods
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            String? token = uri.queryParameters['token'];

            // If not found in query params, try extracting from hash fragment or full URL
            if (token == null || token.isEmpty) {
              final hash = web.window.location.hash;
              if (hash.contains('token=')) {
                final hashMatch = RegExp(r'token=([^&#]+)').firstMatch(hash);
                if (hashMatch != null) {
                  token = hashMatch.group(1);
                }
              }
              // Try full URL as fallback
              if (token == null || token.isEmpty) {
                final urlMatch =
                    RegExp(r'token=([^&#]+)').firstMatch(currentUrl);
                if (urlMatch != null) {
                  token = urlMatch.group(1);
                }
              }
            }

            print(
                '📍 Onboarding token: ${token != null ? "${token.substring(0, 10)}..." : "null"}');
            if (token != null && token.isNotEmpty) {
              final validToken = token; // Create non-nullable variable
              return MaterialPageRoute(
                builder: (context) => ClientOnboardingPage(token: validToken),
              );
            } else {
              print('❌ No token found in onboarding URL');
            }
          }

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

          // Handle client proposals route
          if (settings.name == '/client/proposals' ||
              (settings.name != null &&
                  settings.name!.startsWith('/client/proposals'))) {
            print('🔍 Client proposals route detected: ${settings.name}');

            // Extract token from URL
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            String? token = uri.queryParameters['token'];

            if (token != null && token.isNotEmpty) {
              print('✅ Token found for client proposals');
              final validToken = token;
              return MaterialPageRoute(
                builder: (context) =>
                    ClientDashboardHome(initialToken: validToken),
              );
            } else {
              print('❌ No token found in client proposals URL');
            }
          }

          // Handle client portal route (e.g., /client-portal/123)
          if (settings.name != null &&
              settings.name!.contains('client-portal')) {
            print('🔍 Client portal route detected: ${settings.name}');

            // Extract proposal ID from the route
            final routeParts = settings.name!.split('/');
            String? proposalId;

            // Find the proposal ID after 'client-portal'
            for (int i = 0; i < routeParts.length; i++) {
              if (routeParts[i] == 'client-portal' &&
                  i + 1 < routeParts.length) {
                proposalId = routeParts[i + 1];
                break;
              }
            }

            if (proposalId != null && proposalId.isNotEmpty) {
              print('✅ Opening client portal for proposal ID: $proposalId');
              return MaterialPageRoute(
                builder: (context) => BlankDocumentEditorPage(
                  proposalId: proposalId,
                  proposalTitle: 'Proposal #$proposalId',
                  readOnly: true, // Clients view in read-only mode
                ),
              );
            } else {
              print('❌ No proposal ID found in client-portal route');
            }
          }

          return null; // Let other routes be handled normally
        },
        routes: {
          '/': (context) => const StartupPage(),
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/onboard': (context) {
            // This will be handled by onGenerateRoute, but adding as fallback
            final currentUrl = web.window.location.href;
            final uri = Uri.parse(currentUrl);
            String? token = uri.queryParameters['token'];

            // If not found in query params, try extracting from hash fragment or full URL
            if (token == null || token.isEmpty) {
              final hash = web.window.location.hash;
              if (hash.contains('token=')) {
                final hashMatch = RegExp(r'token=([^&#]+)').firstMatch(hash);
                if (hashMatch != null) {
                  token = hashMatch.group(1);
                }
              }
              // Try full URL as fallback
              if (token == null || token.isEmpty) {
                final urlMatch =
                    RegExp(r'token=([^&#]+)').firstMatch(currentUrl);
                if (urlMatch != null) {
                  token = urlMatch.group(1);
                }
              }
            }

            return ClientOnboardingPage(token: token ?? '');
          },
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
          '/home': (context) => const DashboardPage(),
          '/dashboard': (context) => const DashboardPage(),
          '/creator_dashboard': (context) => const DashboardPage(),
          '/proposals': (context) => ProposalsPage(),
          '/compose': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;

            // If proposal data is passed, open it in the editor
            if (args != null) {
              return BlankDocumentEditorPage(
                proposalId: args['id']?.toString(),
                proposalTitle: args['title']?.toString(),
                readOnly: args['readOnly'] ?? false,
                requireVersionDescription:
                    args['requireVersionDescription'] ?? false,
                isCollaborator: args['isCollaborator'] ?? false,
              );
            }

            // Otherwise, show the old compose page
            return const ComposePage();
          },
          '/proposal-wizard': (context) => const ProposalWizard(),
          '/new-proposal': (context) => const NewProposalPage(),
          '/blank-document': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;
            return StartFromScratchPage(
              proposalId: args?['proposalId'],
              initialTitle: args?['proposalTitle'] ?? 'Untitled Document',
              readOnly: args?['readOnly'] ?? false,
            );
          },
          '/enhanced-compose': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;
            return EnhancedComposePage(
              proposalId: args?['proposalId'] ?? '',
              proposalTitle: args?['proposalTitle'] ?? 'Untitled Proposal',
              templateType: args?['templateType'] ?? 'proposal',
              selectedModules:
                  List<String>.from(args?['selectedModules'] ?? []),
              initialData: args?['initialData'] as Map<String, dynamic>?,
            );
          },
          '/govern': (context) => const GovernPage(),
          '/preview': (context) => const PreviewPage(),
          '/content_library': (context) => const ContentLibraryPage(),
          '/content': (context) =>
              const ContentLibraryPage(), // Add missing route
          '/templates': (context) => const TemplatesPage(),
          '/template-builder': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;
            return TemplateBuilder(templateId: args?['templateId']);
          },
          '/approvals': (context) => const ApproverDashboardPage(),
          '/approver_dashboard': (context) => const ApproverDashboardPage(),
          '/finance_dashboard': (context) => FinanceDashboardPage(),
          '/finance/onboarding': (context) => const FinanceOnboardingPage(),
          '/approved_proposals': (context) => const ApprovedProposalsPage(),
          '/admin_approvals': (context) => const AdminApprovalsPage(),
          '/proposal_review': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;
            return ProposalReviewPage(
              proposalId: args?['id']?.toString() ?? '',
              proposalTitle: args?['title']?.toString(),
            );
          },
          '/admin_dashboard': (context) => const ApproverDashboardPage(),
          '/cinematic': (context) => const CinematicSequencePage(),
          '/client_management': (context) => const ClientManagementPage(),
          '/collaboration': (context) =>
              const ClientManagementPage(), // Redirected to Client Management
          // '/collaborate' is handled by onGenerateRoute to extract token
          '/analytics': (context) => const AnalyticsPage(),
          '/ai-configuration': (context) => const AIConfigurationPage(),
          '/settings': (context) => const SettingsPage(),
          '/test-signature': (context) => const TestSignaturePage(),
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

  Future<void> _checkVerificationUrl() async {
    final currentUrl = web.window.location.href;
    final uri = Uri.parse(currentUrl);

    // Check for external Khonobuzz JWT login (source=khonobuzz&token=...)
    final source = uri.queryParameters['source'] ?? '';
    if (source.toLowerCase() == 'khonobuzz') {
      String? externalToken = uri.queryParameters['token'];

      // Fallback: try to extract from hash or full URL
      if (externalToken == null || externalToken.isEmpty) {
        final hashMatch = RegExp(r'token=([^&#]+)').firstMatch(currentUrl);
        if (hashMatch != null) {
          externalToken = hashMatch.group(1);
        }
      }

      if (externalToken != null && externalToken.isNotEmpty) {
        print(
            '✅ Detected Khonobuzz JWT login - token: ${externalToken.substring(0, 10)}...');
        try {
          final loginResult = await AuthService.loginWithJwt(externalToken);
          final userProfile = loginResult?['user'] as Map<String, dynamic>?;
          final token = loginResult?['token'] as String?;

          if (userProfile != null && token != null && mounted) {
            final appState = context.read<AppState>();
            appState.authToken = token;
            appState.currentUser = userProfile;

            final roleService = context.read<RoleService>();
            await roleService.initializeRoleFromUser(userProfile);
            await appState.init();

            final rawRole = userProfile['role']?.toString() ?? '';
            final userRole = rawRole.toLowerCase().trim();
            String dashboardRoute;

            final isAdmin = userRole == 'admin' || userRole == 'ceo';
            final isFinance = userRole == 'finance' ||
                userRole == 'finance manager' ||
                userRole == 'financial manager' ||
                userRole == 'finance_manager' ||
                userRole == 'financial_manager';
            final isManager = userRole == 'manager' ||
                userRole == 'creator' ||
                userRole == 'user';

            if (isAdmin) {
              dashboardRoute = '/approver_dashboard';
              print('✅ Khonobuzz: Routing to Admin Dashboard');
            } else if (isFinance) {
              dashboardRoute = '/finance_dashboard';
              print('✅ Khonobuzz: Routing to Finance Dashboard');
            } else if (isManager) {
              dashboardRoute = '/creator_dashboard';
              print('✅ Khonobuzz: Routing to Creator Dashboard (Manager)');
            } else {
              dashboardRoute = '/creator_dashboard';
              print(
                  '⚠️ Khonobuzz: Unknown role "$userRole", defaulting to Creator Dashboard');
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, dashboardRoute);
            });
            return;
          }
        } catch (e) {
          print('❌ Khonobuzz JWT login failed: $e');
        }
      } else {
        print('❌ Khonobuzz source detected but no token found in URL');
      }
    }

    // Check if this is a client onboarding URL (priority check)
    final isOnboarding = currentUrl.contains('/onboard') ||
        uri.path.contains('/onboard') ||
        currentUrl.contains('onboard?token=');

    String? onboardingToken;
    // Try to get token from query parameters first
    onboardingToken = uri.queryParameters['token'];

    // If not found, try to extract from hash fragment or full URL
    if (onboardingToken == null || onboardingToken.isEmpty) {
      final hashMatch = RegExp(r'token=([^&#]+)').firstMatch(currentUrl);
      if (hashMatch != null) {
        onboardingToken = hashMatch.group(1);
      }
    }

    if (isOnboarding && onboardingToken != null && onboardingToken.isNotEmpty) {
      print(
          '✅ Detected client onboarding URL in _checkVerificationUrl - token: ${onboardingToken.substring(0, 10)}...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientOnboardingPage(token: onboardingToken!),
          ),
        );
      });
      return;
    }

    // Check if this is a collaboration URL (has token and contains 'collaborate')
    if (uri.fragment.contains('/collaborate') &&
        uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        // Navigate to guest collaboration page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const GuestCollaborationPage(),
            ),
          );
        });
        return;
      }
    }

    // Check if this is a client proposals URL (don't redirect to verification)
    final isClientProposals = currentUrl.contains('/client/proposals') ||
        uri.path.contains('/client/proposals');

    // Check if this is a collaboration URL (don't redirect to verification)
    final isCollaborationUrl = currentUrl.contains('/collaborate') ||
        uri.path.contains('/collaborate');

    // Check if this is a verification URL (but not onboarding, client proposals, or collaboration)
    if (!isOnboarding &&
        !isClientProposals &&
        !isCollaborationUrl &&
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
    // Check if this is a collaboration URL (guest access - no auth required)
    final currentUrl = web.window.location.href;
    final hash = web.window.location.hash;
    final search = web.window.location.search;

    print('🔍 AuthWrapper - Full URL: $currentUrl');
    print('🔍 AuthWrapper - Hash: $hash');
    print('🔍 AuthWrapper - Search: $search');

    // Check for client onboarding URL (priority check - must happen first)
    final uri = Uri.parse(currentUrl);
    final isOnboarding = currentUrl.contains('/onboard') ||
        uri.path.contains('/onboard') ||
        currentUrl.contains('onboard?token=') ||
        search.contains('onboard?token=');

    String? onboardingToken;
    // Try to get token from query parameters first
    onboardingToken = uri.queryParameters['token'];

    // If not found in query params, try to extract from hash fragment or full URL
    if (onboardingToken == null || onboardingToken.isEmpty) {
      // Try extracting from hash fragment
      if (hash.contains('token=')) {
        final hashMatch = RegExp(r'token=([^&#]+)').firstMatch(hash);
        if (hashMatch != null) {
          onboardingToken = hashMatch.group(1);
        }
      }
      // Try extracting from full URL as fallback
      if (onboardingToken == null || onboardingToken.isEmpty) {
        final urlMatch = RegExp(r'token=([^&#]+)').firstMatch(currentUrl);
        if (urlMatch != null) {
          onboardingToken = urlMatch.group(1);
        }
      }
    }

    if (isOnboarding && onboardingToken != null && onboardingToken.isNotEmpty) {
      print('✅ Detected client onboarding URL - showing ClientOnboardingPage');
      print('📍 Onboarding token: ${onboardingToken.substring(0, 10)}...');
      return ClientOnboardingPage(token: onboardingToken);
    }

    // Check for client proposals URL (priority - must be before collaboration check)
    final isClientProposals = currentUrl.contains('/client/proposals') ||
        uri.path.contains('/client/proposals');

    if (isClientProposals) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        print('✅ Detected client proposals URL - showing ClientDashboardHome');
        print('📍 Client token: ${token.substring(0, 10)}...');
        return const ClientDashboardHome();
      }
    }

    // Check for collaboration in hash or URL
    final isCollaboration = currentUrl.contains('/collaborate') ||
        hash.contains('/collaborate') ||
        currentUrl.contains('collaborate?token=') ||
        hash.contains('collaborate?token=');

    final hasToken = currentUrl.contains('token=') ||
        hash.contains('token=') ||
        search.contains('token=');

    print('🔍 Is Collaboration: $isCollaboration, Has Token: $hasToken');

    if (isCollaboration && hasToken) {
      print('✅ Detected collaboration URL - showing GuestCollaborationPage');
      return const GuestCollaborationPage();
    }

    // Check if this is an external URL (not our app) - if so, let browser handle it
    // External URLs like DocuSign should not be processed by Flutter routing
    final currentOrigin = web.window.location.origin;
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final urlOrigin =
          '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      if (urlOrigin != currentOrigin && !currentUrl.contains(currentOrigin)) {
        // This is an external URL - let browser handle it, don't show Flutter UI
        print(
            '🔍 External URL detected: $urlOrigin (current origin: $currentOrigin)');
        // Return a minimal widget that won't interfere
        return const SizedBox.shrink();
      }
    }

    // Always show landing page first when app starts
    // The landing page will handle navigation to login/dashboard based on auth status
    return const StartupPage();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIdx});
  final int? initialIdx;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  final pages = [
    DashboardPage(), // 0
    ProposalsPage(), // 1
    ContentLibraryPage(), // 2
    ClientManagementPage(), // 3
    ApproverDashboardPage(), // 4
    AnalyticsPage(), // 5
    PreviewPage(), // 6 (optional)
    ComposePage(), // 7 (optional)
    GovernPage(), // 8 (optional)
    ApproverDashboardPage(), // 9 (optional)
  ];

  @override
  void initState() {
    super.initState();
    // Redirect to appropriate dashboard based on user role
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectBasedOnRole(context);
    });
  }

  void _redirectBasedOnRole(BuildContext context) {
    final user = AuthService.currentUser;
    if (user == null) return;

    final roleService = context.read<RoleService>();

    // Initialize role service
    roleService.initializeRoleFromUser(user).then((_) {
      final currentRole = roleService.currentRole;
      String dashboardRoute;

      if (currentRole == UserRole.approver || currentRole == UserRole.admin) {
        dashboardRoute = '/approver_dashboard';
      } else if (currentRole == UserRole.finance) {
        dashboardRoute = '/finance_dashboard';
      } else {
        dashboardRoute = '/creator_dashboard';
      }

      Navigator.pushReplacementNamed(context, dashboardRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialIdx != null && idx != widget.initialIdx) {
      // initialize once with desired index
      idx = widget.initialIdx!;
    }
    final user = AuthService.currentUser;
    final backendRole = user?['role']?.toString().toLowerCase() ?? 'manager';
    final bool isAdminUser = backendRole == 'admin' || backendRole == 'ceo';

    return Scaffold(
      body: Row(
        children: [
          // Modern Navigation Sidebar
          _buildModernSidebar(),
          Expanded(child: pages[idx]),
        ],
      ),
      floatingActionButton: isAdminUser
          ? FloatingActionButton(
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
                            setState(() => idx = 9);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.admin_panel_settings_outlined),
                          title: const Text('Admin'),
                          onTap: () {
                            setState(() => idx = 10);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.business_outlined),
                          title: const Text('Client Portal'),
                          onTap: () {
                            setState(() => idx = 1);
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
            )
          : null,
    );
  }

  Widget _buildModernSidebar() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        border: Border(right: BorderSide(color: Colors.grey[900]!)),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00CED1),
                    const Color(0xFF20B2AA),
                  ],
                ),
              ),
              child: const Icon(Icons.dashboard, color: Colors.white, size: 26),
            ),
          ),
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildModernNavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    index: 0,
                  ),
                  _buildModernNavItem(
                    icon: Icons.description_outlined,
                    label: 'My Proposals',
                    index: 1,
                  ),
                  _buildModernNavItem(
                    icon: Icons.library_books,
                    label: 'Templates',
                    index: 2,
                  ),
                  _buildModernNavItem(
                    icon: Icons.collections,
                    label: 'Content Library',
                    index: 2,
                  ),
                  _buildModernNavItem(
                    icon: Icons.people_outline,
                    label: 'Client Management',
                    index: 3,
                  ),
                  _buildModernNavItem(
                    icon: Icons.done_all_outlined,
                    label: 'Approvals',
                    index: 5,
                  ),
                  _buildModernNavItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Analytics',
                    index: 6,
                  ),
                ],
              ),
            ),
          ),
          // Bottom Section
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                _buildModernNavItem(
                  icon: Icons.help_outline,
                  label: 'Help',
                  index: -1,
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: 'Logout',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleLogout,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.logout,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = idx == index && index != -1;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: index != -1 ? () => setState(() => idx = index) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: const Color(0xFF00CED1), width: 2)
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isActive ? const Color(0xFF00CED1) : Colors.grey[600],
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  label.split(' ')[0],
                  style: TextStyle(
                    fontSize: 9,
                    color:
                        isActive ? const Color(0xFF00CED1) : Colors.grey[600],
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
