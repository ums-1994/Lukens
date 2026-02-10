import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'pages/admin/proposal_review_page.dart';
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
import 'pages/financial/financial_manager_dashboard_page.dart';
import 'services/auth_service.dart';
import 'services/role_service.dart';
import 'api.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: Colors.black);
                  },
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
          '/financial_manager_dashboard': (context) =>
              const FinancialManagerDashboardPage(),
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
          '/approved_proposals': (context) => const ApprovedProposalsPage(),
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

            final isApprover =
                userRole == 'admin' || userRole == 'ceo' || userRole == 'approver';
            final isFinancialManager = userRole == 'financial manager';

            if (isApprover) {
              dashboardRoute = '/approver_dashboard';
              print('✅ Khonobuzz: Routing to Approver Dashboard');
            } else if (isFinancialManager) {
              dashboardRoute = '/financial_manager_dashboard';
              print('✅ Khonobuzz: Routing to Financial Manager Dashboard');
            } else {
              dashboardRoute = '/creator_dashboard';
              print('✅ Khonobuzz: Routing to Creator Dashboard');
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

    // If the user is authenticated (token + user restored), render the persona root.
    // Otherwise, show the landing screen which routes to login/register.
    if (AuthService.isLoggedIn) {
      return const RoleRoot();
    }
    return const StartupPage();
  }
}

class RoleRoot extends StatelessWidget {
  const RoleRoot({super.key});

  String _normalizedRole(dynamic rawRole) {
    return (rawRole ?? '').toString().toLowerCase().trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final role = _normalizedRole(user?['role']);

    if (role == 'admin' || role == 'ceo' || role == 'approver') {
      return const ApproverDashboardPage();
    }
    if (role == 'financial manager') {
      return const FinancialManagerDashboardPage();
    }
    return const DashboardPage();
  }
}
