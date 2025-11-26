import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:url_strategy/url_strategy.dart';
import 'pages/creator/creator_dashboard_page.dart';
import 'pages/creator/compose_page.dart';
import 'pages/creator/proposal_wizard.dart';
import 'pages/creator/new_proposal_page.dart';
import 'pages/creator/enhanced_compose_page.dart';
import 'pages/creator/blank_document_editor_page.dart';
import 'pages/admin/govern_page.dart';
import 'pages/approver/approvals_page.dart';
import 'pages/shared/preview_page.dart';
import 'pages/creator/content_library_page.dart';
import 'pages/approver/approver_dashboard_page.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/test_signature_page.dart';
import 'pages/shared/email_verification_page.dart';
import 'pages/shared/startup_page.dart';
import 'pages/shared/proposals_page.dart';
import 'pages/creator/collaboration_page.dart';
import 'pages/creator/client_management_page.dart';
import 'pages/public/client_onboarding_page.dart';
import 'pages/guest/guest_collaboration_page.dart';
import 'pages/shared/collaboration_router.dart';
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
  
  // Use hash-based routing for web (URLs like /#/onboard/token)
  // This fixes deep linking issues with Flutter web dev server
  if (kIsWeb) {
    setHashUrlStrategy();
  }
  
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
        locale: const Locale('en', 'US'),
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          textTheme: GoogleFonts.poppinsTextTheme(),
          scaffoldBackgroundColor: Colors.transparent,
        ),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Localizations.override(
              context: context,
              locale: const Locale('en', 'US'),
              child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Global BG.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              if (child != null) child,
            ],
              ),
            ),
          );
        },
        home: const AppBootstrapper(),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          print('🔍 onGenerateRoute - Route name: ${settings.name}');
          
          // Catch-all: redirect any undefined routes to home
          if (settings.name == '/' || settings.name == null || settings.name!.isEmpty) {
            return MaterialPageRoute(builder: (context) => const AppBootstrapper());
          }

          // Handle client onboarding routes (PUBLIC - no auth required)
          if (settings.name != null && settings.name!.startsWith('/onboard/')) {
            print('🔍 Client onboarding route detected!');
            final token = settings.name!.substring(9); // Remove '/onboard/'
            print('📍 Onboarding token: $token');
            return MaterialPageRoute(
              builder: (context) => ClientOnboardingPage(token: token),
              settings: settings,
            );
          }

          // Handle secure proposal routes
          if (settings.name == '/secure-proposal' ||
              (settings.name != null &&
                  settings.name!.contains('secure-proposal'))) {
            print('🔒 Secure proposal route detected!');
            
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
              
              // Check query parameters
              if ((token == null || token.isEmpty) && uri.queryParameters.containsKey('token')) {
                token = uri.queryParameters['token'];
                print('📍 Token from query params: $token');
              }
            }
            
            if (token != null && token.isNotEmpty) {
              print('✅ Token found for secure proposal');
              final validToken = token;
              return MaterialPageRoute(
                builder: (context) => CollaborationRouter(token: validToken),
              );
            } else {
              print('❌ No token found for secure proposal');
            }
          }

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
          '/creator_dashboard': (context) => const HomeShell(),
          '/proposals': (context) => ProposalsPage(),
          '/compose': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;

            // If proposal data is passed, open it in the editor
            if (args != null) {
              return BlankDocumentEditorPage(
                proposalId: args['id']?.toString(),
                proposalTitle: args['title']?.toString(),
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
            return BlankDocumentEditorPage(
              proposalId: args?['proposalId'],
              proposalTitle: args?['proposalTitle'] ?? 'Untitled Document',
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
            );
          },
          '/govern': (context) => const GovernPage(),
          '/preview': (context) => const PreviewPage(),
          '/content_library': (context) => const ContentLibraryPage(),
          '/content': (context) =>
              const ContentLibraryPage(), // Add missing route
          '/approvals': (context) => const ApprovalsPage(),
          '/approver_dashboard': (context) => const ApproverDashboardPage(),
          '/admin_dashboard': (context) => const AdminDashboardPage(),
          '/cinematic': (context) => const HomeShell(), // Redirect cinematic to home
          '/login': (context) => const HomeShell(), // Redirect login to home
          '/register': (context) => const HomeShell(), // Redirect register to home
          '/startup': (context) => const HomeShell(), // Redirect startup to home
          '/collaboration': (context) => const ClientManagementPage(),
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

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    // Clear any old route hashes that might cause navigation to landing pages
    final currentUrl = web.window.location.href;
    final hash = web.window.location.hash;
    
    // If URL has old landing page routes, clear them
    if (hash.contains('/cinematic') || hash.contains('/startup') || 
        hash.contains('/login') || hash.contains('/register')) {
      web.window.location.hash = '';
    }
    
    // Handle direct-access collaboration/verification URLs first
    if (_handleGuestOrVerificationRoutes()) {
      return;
    }

    if (!AuthService.isLoggedIn) {
      const fakeToken = 'dev-bypass-token';
      final defaultUser = {
        'email': 'admin@khonology.com',
        'full_name': 'Admin User',
        'role': 'Financial Manager',
      };
      AuthService.setUserData(defaultUser, fakeToken);
    }

    try {
      await context.read<AppState>().init();
    } catch (e) {
      print('⚠️ App bootstrap init failed: $e');
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  bool _handleGuestOrVerificationRoutes() {
    final currentUrl = web.window.location.href;
    final uri = Uri.parse(currentUrl);
    final hash = web.window.location.hash;
    final search = web.window.location.search;

    final isCollaboration = currentUrl.contains('/collaborate') ||
        hash.contains('/collaborate') ||
        currentUrl.contains('collaborate?token=') ||
        hash.contains('collaborate?token=');

    final hasToken = currentUrl.contains('token=') ||
        hash.contains('token=') ||
        search.contains('token=');

    if (isCollaboration && hasToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GuestCollaborationPage()),
        );
      });
      return true;
    }

    if (uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationPage(token: token),
            ),
          );
        });
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Launching workspace…'),
            ],
          ),
        ),
      );
    }

    return const HomeShell();
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
    DashboardPage(), // 0
    ProposalsPage(), // 1
    ContentLibraryPage(), // 2
    CollaborationPage(), // 3
    ApprovalsPage(), // 4
    AnalyticsPage(), // 5
    PreviewPage(), // 6 (optional)
    ComposePage(), // 7 (optional)
    GovernPage(), // 8 (optional)
    ApproverDashboardPage(), // 9 (optional)
    AdminDashboardPage(), // 10 (optional)
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.initialIdx != null && idx != widget.initialIdx) {
      // initialize once with desired index
      idx = widget.initialIdx!;
      _current = _labelForIdx(idx);
    }
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
                      setState(() => idx = 9);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
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
      ),
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
                    index: 3,
                  ),
                  _buildModernNavItem(
                    icon: Icons.people_outline,
                    label: 'Collaboration',
                    index: 4,
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

  int _idxForLabel(String label) {
    switch (label) {
      case 'Dashboard':
        return 0;
      case 'My Proposals':
        return 1;
      case 'Templates':
        return 2;
      case 'Content Library':
        return 3;
      case 'Collaboration':
        return 4;
      case 'Approvals Status':
        return 5;
      case 'Analytics (My Pipeline)':
        return 6;
      case 'Preview':
        return 7;
      default:
        return 0;
    }
  }

  String _labelForIdx(int i) {
    switch (i) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'My Proposals';
      case 2:
        return 'Templates';
      case 3:
        return 'Content Library';
      case 4:
        return 'Collaboration';
      case 5:
        return 'Approvals Status';
      case 6:
        return 'Analytics (My Pipeline)';
      case 7:
        return 'Preview';
      default:
        return 'Dashboard';
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
                    context, '/home', (route) => false);
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
