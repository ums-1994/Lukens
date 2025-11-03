// ignore_for_file: deprecated_member_use, unused_element
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../api.dart';
import '../../widgets/footer.dart';
import '../../widgets/role_switcher.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key});

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage>
    with TickerProviderStateMixin {
  final keyCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  String selectedCategory = "Sections";
  String sortBy = "Last Edited (Newest First)";
  int currentPage = 1;
  int itemsPerPage = 10;
  String _currentPage = 'Content Library';
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  int? currentFolderId; // Track current folder being viewed

  final List<String> categories = ["Sections", "Images", "Snippets", "Trash"];

  final List<String> sortOptions = [
    "Last Edited (Newest First)",
    "Last Edited (Oldest First)",
    "Name (A-Z)",
    "Name (Z-A)"
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Start collapsed
    _animationController.value = 1.0;

    // Fetch content if empty
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      if (app.contentBlocks.isEmpty) {
        await app.fetchContent();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
      if (_isSidebarCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<List<dynamic>> _loadDisplayItems() async {
    final app = context.read<AppState>();
    if (selectedCategory == "Trash") {
      return await app.fetchTrash();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final userRole = app.currentUser?['role'] ?? 'Financial Manager';

    // Filter items by selected category and current folder
    List<dynamic> displayItems = [];

    if (selectedCategory == "Trash") {
      // For trash, we'll load items in real-time
      displayItems = []; // Placeholder - will be fetched when needed
    } else {
      displayItems = app.contentBlocks.where((item) {
        final category = item["category"] ?? "Sections";
        final categoryMatch =
            category.toLowerCase() == selectedCategory.toLowerCase();

        // If in a folder, only show items in that folder
        if (currentFolderId != null) {
          final parentId = item["parent_id"];
          return categoryMatch && parentId == currentFolderId;
        }

        // Show root items (no parent_id or parent_id is null)
        final parentId = item["parent_id"];
        return categoryMatch && (parentId == null || parentId == "");
      }).toList();
    }

    final filteredItems = displayItems;

    // Sort items
    switch (sortBy) {
      case "Last Edited (Oldest First)":
        filteredItems.sort((a, b) => (a["created_at"] ?? "")
            .toString()
            .compareTo(b["created_at"] ?? ""));
        break;
      case "Name (A-Z)":
        filteredItems.sort((a, b) => (a["label"] ?? a["key"])
            .toString()
            .toLowerCase()
            .compareTo((b["label"] ?? b["key"]).toString().toLowerCase()));
        break;
      case "Name (Z-A)":
        filteredItems.sort((a, b) => (b["label"] ?? b["key"])
            .toString()
            .toLowerCase()
            .compareTo((a["label"] ?? a["key"]).toString().toLowerCase()));
        break;
      default:
        filteredItems.sort((a, b) => (b["created_at"] ?? "")
            .toString()
            .compareTo(a["created_at"] ?? ""));
    }

    // Calculate pagination
    final startIdx = (currentPage - 1) * itemsPerPage;
    final endIdx = (startIdx + itemsPerPage).clamp(0, filteredItems.length);
    final pagedItems = filteredItems.sublist(startIdx, endIdx);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Content Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const CompactRoleSwitcher(),
                      const SizedBox(width: 20),
                      ClipOval(
                        child: Image.asset(
                          'assets/images/User_Profile.png',
                          width: 105,
                          height: 105,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getUserName(app.currentUser),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userRole,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'logout') {
                            _handleLogout(context, app);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Content with Sidebar
          Expanded(
            child: Row(
              children: [
                // Collapsible Sidebar
                GestureDetector(
                  onTap: () {
                    if (_isSidebarCollapsed) _toggleSidebar();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    // Re-added ClipRRect
                    borderRadius: BorderRadius.circular(
                        0), // No rounded corners for sidebar
                    child: BackdropFilter(
                      // Re-added BackdropFilter
                      filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isSidebarCollapsed ? 90.0 : 250.0,
                        color: Colors.black
                            .withOpacity(0.32), // Adjusted opacity to 0.32
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              // Toggle button
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: InkWell(
                                  onTap: _toggleSidebar,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(
                                          0.12), // Adjusted opacity to 0.12
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: _isSidebarCollapsed
                                          ? MainAxisAlignment.center
                                          : MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (!_isSidebarCollapsed)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              'Navigation',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  _isSidebarCollapsed ? 0 : 8),
                                          child: Icon(
                                            _isSidebarCollapsed
                                                ? Icons.keyboard_arrow_right
                                                : Icons.keyboard_arrow_left,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Navigation items
                              _buildNavItem(
                                  'Dashboard',
                                  'assets/images/Dashboard.png',
                                  _currentPage == 'Dashboard'),
                              _buildNavItem(
                                  'My Proposals',
                                  'assets/images/My_Proposals.png',
                                  _currentPage == 'My Proposals'),
                              _buildNavItem(
                                  'Templates',
                                  'assets/images/Templates.png',
                                  _currentPage == 'Templates'),
                              _buildNavItem(
                                  'Content Library',
                                  'assets/images/Content_Library.png',
                                  _currentPage == 'Content Library'),
                              _buildNavItem(
                                  'Collaboration',
                                  'assets/images/Collaboration.png',
                                  _currentPage == 'Collaboration'),
                              _buildNavItem(
                                  'Approvals Status',
                                  'assets/images/Approval_Status.png',
                                  _currentPage == 'Approvals Status'),
                              _buildNavItem(
                                  'Analytics (My Pipeline)',
                                  'assets/images/Analytics.png',
                                  _currentPage == 'Analytics (My Pipeline)'),
                              const SizedBox(height: 20),
                              // Divider
                              if (!_isSidebarCollapsed)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  height: 1,
                                  color: Colors.black.withOpacity(
                                      0.35), // Adjusted divider color to be blackish
                                ),
                              const SizedBox(height: 12),
                              // Logout button
                              _buildNavItem(
                                  'Logout', 'assets/images/Logout.png', false),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE9293A).withOpacity(0.5),
                                width: 1),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentFolderId != null
                                              ? (app.contentBlocks.firstWhere(
                                                      (element) =>
                                                          element['id'] ==
                                                          currentFolderId,
                                                      orElse: () =>
                                                          {})['label'] ??
                                                  'Folder')
                                              : _capitalize(selectedCategory),
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white),
                                        ),
                                        Text(
                                          currentFolderId != null
                                              ? 'Items in this folder'
                                              : 'Manage all your reusable content blocks',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.7)),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          width: 200,
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: "Search content...",
                                              hintStyle: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.7)),
                                              prefixIcon: Icon(Icons.search,
                                                  color: Colors.white
                                                      .withOpacity(0.7)),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide.none),
                                              filled: true,
                                              fillColor: Colors.black
                                                  .withOpacity(0.12),
                                            ),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0),
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: const Color(0xFFE9293A)
                                                      .withOpacity(0.5),
                                                  width: 1)),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: sortBy,
                                              dropdownColor:
                                                  Colors.black.withOpacity(0.8),
                                              icon: Icon(Icons.arrow_drop_down,
                                                  color: Colors.white
                                                      .withOpacity(0.7)),
                                              style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.9)),
                                              items: sortOptions
                                                  .map((String value) =>
                                                      DropdownMenuItem<String>(
                                                          value: value,
                                                          child: Text(value)))
                                                  .toList(),
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  sortBy = newValue ?? sortBy;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ..._buildAppBarActions(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (currentFolderId != null)
                                FolderBreadcrumbs(
                                  path: app.getFolderPath(currentFolderId),
                                  onNavigate: (folderId) {
                                    setState(() {
                                      currentFolderId = folderId;
                                    });
                                  },
                                ),
                              Expanded(
                                child: _buildContentArea(pagedItems, app),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Footer(),
        ],
      ),
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushNamed(context, '/creator_dashboard');
        break;
      case 'My Proposals':
        Navigator.pushNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushNamed(context, '/proposal-wizard');
        break;
      case 'Content Library':
        // Already on content library
        break;
      case 'Collaboration':
        Navigator.pushNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
        Navigator.pushNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushNamed(context, '/analytics');
        break;
      case 'Logout':
        _handleLogout(context, context.read<AppState>());
        break;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Templates":
        return Icons.description;
      case "Sections":
        return Icons.dashboard;
      case "Images":
        return Icons.image;
      case "Snippets":
        return Icons.code;
      default:
        return Icons.folder;
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'rtf':
      case 'odt':
        return Icons.file_present;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks > 1 ? 's' : ''} ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildCreateOption({
    required BuildContext context,
    required AppState app,
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 32, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';

    // Try different possible field names for the user's name
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];

    return name ?? 'User';
  }

  void _handleLogout(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              if (app.currentUser != null) {
                app.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (app.currentUser != null) {
        app.logout();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildNavItem(String title, String imagePath, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentPage = title;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.black.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Image.asset(
                  imagePath,
                  width: 24,
                  height: 24,
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(List<dynamic> items, AppState app) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFolder = item['is_folder'] ?? false;
        final isTrash = item['category'] == 'Trash';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  border: Border.all(
                      color: isTrash
                          ? Colors.red.withOpacity(0.5)
                          : Colors.transparent,
                      width: 1),
                ),
                child: ListTile(
                  leading: Icon(
                    _getCategoryIcon(item['category'] ?? 'Sections'),
                    color: isTrash ? Colors.red : Colors.white.withOpacity(0.7),
                  ),
                  title: Text(
                    item['label'] ?? item['key'],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item['description'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  trailing: isFolder
                      ? Icon(Icons.folder, color: Colors.white.withOpacity(0.7))
                      : Icon(
                          _getFileIcon(item['label'] ?? item['key']),
                          color: Colors.white.withOpacity(0.7),
                        ),
                  onTap: () {
                    if (isFolder) {
                      setState(() {
                        currentFolderId = item['id'];
                      });
                    } else {
                      _showItemDetails(item, app);
                    }
                  },
                  onLongPress: () {
                    if (!isFolder) {
                      _showItemActions(item, app);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showItemDetails(dynamic item, AppState app) {
    final isFolder = item['is_folder'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['label'] ?? item['key']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFolder)
                const Text(
                    "This is a folder. Double-tap to open it or long-press for actions."),
              if (!isFolder)
                Text(
                  item['content'] ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              if (!isFolder)
                Text(
                  "Created: ${_formatDate(item['created_at'] ?? '')}",
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              if (!isFolder)
                Text(
                  "Last Edited: ${_formatDate(item['updated_at'] ?? '')}",
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              if (!isFolder)
                Text(
                  "Key: ${item['key']}",
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              if (!isFolder)
                Text(
                  "Category: ${_capitalize(item['category'] ?? 'Sections')}",
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              if (!isFolder)
                Text(
                  "Parent: ${app.contentBlocks.firstWhere((e) => e['id'] == item['parent_id'], orElse: () => {
                        'label': 'Root'
                      })['label']}",
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showItemActions(dynamic item, AppState app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['label'] ?? item['key']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("Edit"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditItemDialog(item, app);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(item, app);
                },
              ),
              if (item['is_folder'] ?? false)
                ListTile(
                  leading:
                      const Icon(Icons.create_new_folder, color: Colors.green),
                  title: const Text("New Folder"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showNewFolderDialog();
                  },
                ),
              if (!(item['is_folder'] ?? false))
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.purple),
                  title: const Text("Upload File"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _uploadFile();
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(dynamic item, AppState app) {
    final isFolder = item['is_folder'] ?? false;

    final TextEditingController labelCtrl =
        TextEditingController(text: item['label']);
    final TextEditingController contentCtrl =
        TextEditingController(text: item['content']);
    final TextEditingController keyCtrl =
        TextEditingController(text: item['key']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['label'] ?? item['key']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFolder)
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: "Folder Name",
                    hintText: "Enter new folder name",
                  ),
                ),
              if (!isFolder)
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: "Template Name",
                    hintText: "Enter new template name",
                  ),
                ),
              if (!isFolder)
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: "Template Key",
                    hintText: "Enter new template key",
                  ),
                ),
              if (!isFolder)
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: "Template Content",
                    hintText: "Enter new template content",
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final label = labelCtrl.text.trim();
              final key = keyCtrl.text.trim();
              final content = contentCtrl.text.trim();

              if (isFolder) {
                if (label.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Folder name cannot be empty")),
                  );
                  return;
                }
                try {
                  final result = await app.updateContent(
                    item['id'],
                    label: label,
                    parentId: item['parent_id'],
                    isFolder: true,
                  );
                  if (result) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Folder updated successfully")),
                    );
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to update folder")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Error updating folder: ${e.toString()}")),
                  );
                }
              } else {
                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Template key cannot be empty")),
                  );
                  return;
                }
                if (label.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Template name cannot be empty")),
                  );
                  return;
                }
                try {
                  final result = await app.updateContent(
                    item['id'],
                    label: label,
                    key: key,
                    content: content,
                    category: item['category'],
                    parentId: item['parent_id'],
                  );
                  if (result) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Template updated successfully")),
                    );
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Failed to update template")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Error updating template: ${e.toString()}")),
                  );
                }
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(dynamic item, AppState app) {
    final isFolder = item['is_folder'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['label'] ?? item['key']),
        content: Text(isFolder
            ? "Are you sure you want to delete this folder and all its contents?"
            : "Are you sure you want to delete this item? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await app.deleteContent(item['id']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isFolder
                            ? "Folder and contents deleted"
                            : "Item deleted"),
                        backgroundColor: Colors.red),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Failed to delete item: ${e.toString()}"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showNewFolderDialog() {
    final app = context.read<AppState>();
    final folderNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create New Folder"),
        content: TextField(
          controller: folderNameCtrl,
          decoration: const InputDecoration(
            labelText: "Folder Name",
            hintText: "Enter folder name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (folderNameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a folder name")),
                );
                return;
              }

              try {
                final folderKey = folderNameCtrl.text
                    .toLowerCase()
                    .replaceAll(" ", "_")
                    .replaceAll(RegExp(r'[^a-z0-9_]'), '');

                final result = await app.createContent(
                  key: folderKey,
                  label: folderNameCtrl.text.trim(),
                  content: "",
                  category: selectedCategory,
                  parentId: currentFolderId,
                  isFolder: true,
                );

                Navigator.pop(ctx);

                if (result) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Folder '${folderNameCtrl.text}' created successfully")),
                    );
                    setState(() {});
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to create folder"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error creating folder: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
            ),
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Template"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.description, color: Color(0xFF4a6cf7)),
                title: const Text("Create from Scratch"),
                subtitle: const Text("Start with a blank proposal"),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/new-proposal');
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.style, color: Color(0xFF4a6cf7)),
                title: const Text("From Template Gallery"),
                subtitle: const Text("Choose from predefined templates"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTemplateGalleryDialog();
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading:
                    const Icon(Icons.upload_file, color: Color(0xFF4a6cf7)),
                title: const Text("Upload Template"),
                subtitle: const Text("Import from a file"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUploadTemplateDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showScratchTemplateDialog() {
    final app = context.read<AppState>();
    keyCtrl.clear();
    labelCtrl.clear();
    contentCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Template from Scratch"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: "Key (unique)",
                  hintText: "e.g., executive_summary",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: "Template Name",
                  hintText: "e.g., Executive Summary",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Template Content",
                  hintText: "Enter your template content here...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (keyCtrl.text.isEmpty || labelCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill all fields")),
                );
                return;
              }
              try {
                await app.createContent(
                  key: keyCtrl.text.trim(),
                  label: labelCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                  category: selectedCategory,
                  parentId: currentFolderId,
                );
                keyCtrl.clear();
                labelCtrl.clear();
                contentCtrl.clear();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Template created successfully")),
                );
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed: $e")),
                );
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showTemplateGalleryDialog() {
    final galleryTemplates = [
      {
        "name": "Executive Summary",
        "description": "Professional executive summary template",
        "content":
            "[Client Name]\n\nExecutive Summary\n\n[Your summary content here]"
      },
      {
        "name": "Project Proposal",
        "description": "Complete project proposal template",
        "content":
            "PROJECT PROPOSAL\n\nScope:\n[Scope details]\n\nTimeline:\n[Timeline details]\n\nBudget:\n[Budget details]"
      },
      {
        "name": "Risk Assessment",
        "description": "Risk assessment and mitigation template",
        "content":
            "RISK ASSESSMENT\n\nIdentified Risks:\n\n1. [Risk 1]\n   Mitigation: [Plan]\n\n2. [Risk 2]\n   Mitigation: [Plan]"
      },
      {
        "name": "Terms & Conditions",
        "description": "Standard terms and conditions template",
        "content":
            "TERMS AND CONDITIONS\n\n1. Definitions\n2. Scope of Services\n3. Payment Terms\n4. Confidentiality\n5. Termination"
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Templates Gallery"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: galleryTemplates.map((template) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    child: InkWell(
                      onTap: () {
                        labelCtrl.text = template["name"]!;
                        contentCtrl.text = template["content"]!;
                        keyCtrl.text = template["name"]!
                            .toLowerCase()
                            .replaceAll(" ", "_");
                        Navigator.pop(ctx);
                        _showScratchTemplateDialog();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template["name"]!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              template["description"]!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadTemplateDialog() {
    final app = context.read<AppState>();
    String? selectedFileName;
    String? fileContent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Upload Template"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File upload area
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: selectedFileName != null
                            ? Colors.green[300]!
                            : Colors.grey[300]!,
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                    color: selectedFileName != null
                        ? Colors.green[50]
                        : Colors.grey[50],
                  ),
                  child: Material(
                    child: InkWell(
                      onTap: () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'txt',
                            'pdf',
                            'json',
                            'md',
                            'docx',
                            'doc'
                          ],
                          allowMultiple: false,
                        );

                        if (result != null) {
                          final file = result.files.single;
                          setState(() {
                            selectedFileName = file.name;
                            // Read file content
                            try {
                              if (file.path != null) {
                                fileContent =
                                    File(file.path!).readAsStringSync();
                                // Auto-fill label and key from filename
                                labelCtrl.text = file.name
                                    .replaceAll(RegExp(r'\.[^.]+$'), '');
                                keyCtrl.text = file.name
                                    .replaceAll(RegExp(r'\.[^.]+$'), '')
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
                                contentCtrl.text = fileContent!.substring(
                                    0,
                                    fileContent!.length > 500
                                        ? 500
                                        : fileContent!.length);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Error reading file: ${e.toString()}")),
                              );
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          selectedFileName != null
                              ? Icon(Icons.check_circle,
                                  size: 40, color: Colors.green[400])
                              : Icon(Icons.cloud_upload_outlined,
                                  size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            selectedFileName ?? "Click to select file",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedFileName != null
                                  ? Colors.green[600]
                                  : Colors.grey[600],
                              fontWeight: selectedFileName != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (selectedFileName == null)
                            const SizedBox(height: 4),
                          if (selectedFileName == null)
                            Text(
                              "or drag and drop",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          if (selectedFileName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Supported: txt, pdf, json, md, doc, docx",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (selectedFileName != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "📄 File loaded: $selectedFileName",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Content preview: ${fileContent!.substring(0, fileContent!.length > 100 ? 100 : fileContent!.length)}...",
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: "Template Name",
                    hintText: "Name for this template",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: "Template Key (unique)",
                    hintText: "e.g., imported_template",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Template Content Preview",
                    hintText: "File content will appear here",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: selectedFileName == null
                  ? null
                  : () async {
                      if (keyCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Please enter a template key")),
                        );
                        return;
                      }

                      if (labelCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Please enter a template name")),
                        );
                        return;
                      }

                      try {
                        final templateName = labelCtrl.text;

                        await app.createContent(
                          key: keyCtrl.text,
                          label: labelCtrl.text,
                          content: fileContent ?? contentCtrl.text,
                          category: selectedCategory,
                          parentId: currentFolderId,
                        );
                        keyCtrl.clear();
                        labelCtrl.clear();
                        contentCtrl.clear();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Template '$templateName' uploaded successfully"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedFileName == null
                    ? Colors.grey[300]
                    : Colors.blue[600],
              ),
              child: const Text("Upload Template"),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];

    switch (selectedCategory) {
      case "Templates":
        actions.add(
          Tooltip(
            message: "Create New Template",
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showCreateDialog(),
            ),
          ),
        );
        break;
      case "Sections":
      case "Images":
        actions.add(
          Tooltip(
            message: "Upload File",
            child: IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              onPressed: () => _uploadFile(),
            ),
          ),
        );
        actions.add(const SizedBox(width: 8)); // Add SizedBox separately
        actions.add(
          Tooltip(
            message: "New Folder",
            child: IconButton(
              icon: const Icon(Icons.create_new_folder, color: Colors.white),
              onPressed: () => _showNewFolderDialog(),
            ),
          ),
        );
        break;
      case "Snippets":
        actions.add(
          Tooltip(
            message: "New Snippet",
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showScratchTemplateDialog(),
            ),
          ),
        );
        actions.add(const SizedBox(width: 8)); // Add SizedBox separately
        actions.add(
          Tooltip(
            message: "New Folder",
            child: IconButton(
              icon: const Icon(Icons.create_new_folder, color: Colors.white),
              onPressed: () => _showNewFolderDialog(),
            ),
          ),
        );
        break;
      case "Trash":
        actions.add(
          Tooltip(
            message: "Restore All",
            child: IconButton(
              icon: const Icon(Icons.restore, color: Colors.white),
              onPressed: () => _restoreAllTrash(),
            ),
          ),
        );
        actions.add(const SizedBox(width: 8)); // Add SizedBox separately
        actions.add(
          Tooltip(
            message: "Empty Trash",
            child: IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _emptyTrash(),
            ),
          ),
        );
        break;
    }
    return actions;
  }

  void _restoreAllTrash() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore All Items"),
        content: const Text(
            "Are you sure you want to restore all items from Trash?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final app = context.read<AppState>();
                await app.restoreAllTrash();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("All items restored from Trash"),
                        backgroundColor: Colors.green),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Failed to restore items: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Restore"),
          ),
        ],
      ),
    );
  }

  void _emptyTrash() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Empty Trash"),
        content: const Text(
            "Are you sure you want to permanently delete all items in Trash? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final app = context.read<AppState>();
                await app.emptyTrash();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Trash emptied successfully"),
                        backgroundColor: Colors.green),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Failed to empty trash: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Empty"),
          ),
        ],
      ),
    );
  }

  void _uploadFile() async {
    final app = context.read<AppState>();
    try {
      // Determine allowed file types based on category
      List<String> allowedExtensions;
      String fileTypeLabel;

      if (selectedCategory == "Images") {
        allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
        fileTypeLabel = "image";
      } else if (selectedCategory == "Sections") {
        allowedExtensions = [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'odt',
          'jpg',
          'jpeg',
          'png'
        ];
        fileTypeLabel = "document";
      } else {
        allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
        fileTypeLabel = "file";
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.bytes != null || file.path != null) {
          final fileName = file.name;

          // Create a unique key for the file
          final fileKey = await app.getUniqueContentKey(fileName);

          if (mounted) {
            // Show loading dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text("Uploading"),
                content: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Text("Uploading $fileTypeLabel to Cloudinary..."),
                  ],
                ),
              ),
            );
          }

          try {
            // Upload to Cloudinary via backend
            // Use appropriate upload method based on category
            // Use bytes on web, path on native platforms
            final uploadResult = selectedCategory == "Sections"
                ? (file.bytes != null
                    ? await app.uploadTemplateToCloudinary("",
                        fileBytes: file.bytes, fileName: fileName)
                    : await app.uploadTemplateToCloudinary(file.path!))
                : (file.bytes != null
                    ? await app.uploadImageToCloudinary("",
                        fileBytes: file.bytes, fileName: fileName)
                    : await app.uploadImageToCloudinary(file.path!));

            if (mounted) Navigator.pop(context); // Close loading dialog

            if (uploadResult != null && uploadResult['success'] == true) {
              final cloudinaryUrl = uploadResult['url'];
              final publicId = uploadResult['public_id'];

              // Save to backend database
              // If we're inside a folder, set parent_id to link the file to the folder
              await app.createContent(
                key: fileKey,
                label: fileName,
                content: cloudinaryUrl,
                publicId: publicId,
                category: selectedCategory,
                parentId: currentFolderId,
              );

              // Force UI refresh
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "${fileTypeLabel[0].toUpperCase()}${fileTypeLabel.substring(1)} '$fileName' uploaded successfully to $selectedCategory"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              final errorMsg = uploadResult?['error'] ?? 'Upload failed';
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error uploading $fileTypeLabel: $errorMsg"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text("Error uploading $fileTypeLabel: ${e.toString()}"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class FolderBreadcrumbs extends StatelessWidget {
  final List<dynamic> path;
  final ValueChanged<int?> onNavigate;

  const FolderBreadcrumbs({
    super.key,
    required this.path,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => onNavigate(null),
              child: Text(
                "Home",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...path.map((folder) {
              return Row(
                children: [
                  Icon(Icons.chevron_right,
                      color: Colors.white.withOpacity(0.7), size: 16),
                  GestureDetector(
                    onTap: () => onNavigate(folder['id']),
                    child: Text(
                      folder['label'],
                      style: TextStyle(
                        color: folder == path.last
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: folder == path.last
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
