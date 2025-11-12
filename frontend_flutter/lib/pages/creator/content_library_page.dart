import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../widgets/ai_content_generator.dart';

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
  final searchCtrl = TextEditingController();
  String selectedCategory = "Sections";
  String sortBy = "Last Edited (Newest First)";
  int currentPage = 1;
  int itemsPerPage = 10;
  String _currentPage = 'Content Library';
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  int? currentFolderId; // Track current folder being viewed
  String searchQuery = "";
  String typeFilter = "all";
  bool _showAIGenerator = false;

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
    searchCtrl.dispose();
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

  void _handleContentGenerated(Map<String, dynamic> contentData) {
    // Content is already saved in the AI Content Generator widget
    // Just refresh the content list
    final app = context.read<AppState>();
    app.fetchContent();
    setState(() {
      // Optionally switch to Sections tab to see the new content
      selectedCategory = "Sections";
      currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

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

    List<dynamic> filteredItems = displayItems.where((item) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final label = (item["label"] ?? item["key"] ?? "").toString().toLowerCase();
      final content = (item["content"] ?? "").toString().toLowerCase();
      final tags = (item["tags"] is List)
          ? (item["tags"] as List)
              .map((e) => e.toString().toLowerCase())
              .toList()
          : <String>[];
      return label.contains(q) || content.contains(q) || tags.any((t) => t.contains(q));
    }).toList();

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
    final totalPages = (filteredItems.length / itemsPerPage).ceil();
    final startIdx = (currentPage - 1) * itemsPerPage;
    final endIdx = (startIdx + itemsPerPage).clamp(0, filteredItems.length);
    final pagedItems = filteredItems.sublist(startIdx, endIdx);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F7F9),
          body: Row(
        children: [
          // Collapsible Sidebar (matching dashboard)
          GestureDetector(
            onTap: () {
              if (_isSidebarCollapsed) _toggleSidebar();
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSidebarCollapsed ? 90.0 : 250.0,
              color: const Color(0xFF34495E),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Toggle button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: InkWell(
                        onTap: _toggleSidebar,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: _isSidebarCollapsed
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.spaceBetween,
                            children: [
                              if (!_isSidebarCollapsed)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Navigation',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: _isSidebarCollapsed ? 0 : 8),
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
                    _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                        _currentPage == 'Dashboard', context),
                    _buildNavItem('My Proposals',
                        'assets/images/My_Proposals.png',
                        _currentPage == 'My Proposals', context),
                    _buildNavItem('Templates',
                        'assets/images/content_library.png',
                        _currentPage == 'Templates', context),
                    _buildNavItem('Content Library',
                        'assets/images/content_library.png',
                        _currentPage == 'Content Library', context),
                    _buildNavItem('Collaboration',
                        'assets/images/collaborations.png',
                        _currentPage == 'Collaboration', context),
                    _buildNavItem('Approvals Status',
                        'assets/images/Time Allocation_Approval_Blue.png',
                        _currentPage == 'Approvals Status', context),
                    _buildNavItem('Analytics (My Pipeline)',
                        'assets/images/analytics.png',
                        _currentPage == 'Analytics (My Pipeline)', context),
                    const SizedBox(height: 20),
                    // Divider
                    if (!_isSidebarCollapsed)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 1,
                        color: const Color(0xFF2C3E50),
                      ),
                    const SizedBox(height: 12),
                    // Logout button
                    _buildNavItem('Logout', 'assets/images/Logout_KhonoBuzz.png',
                        false, context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.library_books, size: 32, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Content Library",
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Manage reusable content blocks and images",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _showAIGenerator = true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C27B0),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 20),
                          label: const Text("AI Generate"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showNewContentMenu(context, app),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text("New Content"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Row(
                      children: [
                        _buildTabButton(
                          label: "Text Blocks",
                          isActive: selectedCategory == "Sections",
                          onTap: () {
                            setState(() {
                              selectedCategory = "Sections";
                              currentFolderId = null;
                              currentPage = 1;
                            });
                          },
                        ),
                        _buildTabButton(
                          label: "Image Library",
                          isActive: selectedCategory == "Images",
                          onTap: () {
                            setState(() {
                              selectedCategory = "Images";
                              currentFolderId = null;
                              currentPage = 1;
                            });
                          },
                        ),
                        _buildTabButton(
                          label: "Templates",
                          isActive: selectedCategory == "Templates",
                          onTap: () {
                            setState(() {
                              selectedCategory = "Templates";
                              currentFolderId = null;
                              currentPage = 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (v) => setState(() => searchQuery = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: "Search content, tags...",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: typeFilter,
                          items: const [
                            DropdownMenuItem(value: "all", child: Text("All Types")),
                          ],
                          onChanged: (v) {
                            setState(() {
                              typeFilter = v ?? 'all';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Filter/Sort Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 18, color: Colors.grey),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: sortBy,
                          underline: Container(),
                          isDense: true,
                          items: sortOptions.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Text(option,
                                  style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              sortBy = value!;
                              currentPage = 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Pagination Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${startIdx + 1}-${endIdx} of ${filteredItems.length}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: currentPage > 1
                                ? () => setState(() => currentPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            iconSize: 20,
                          ),
                          IconButton(
                            onPressed: currentPage < totalPages
                                ? () => setState(() => currentPage++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Content List or Grid
                  Expanded(
                    child: pagedItems.isEmpty
                        ? Center(
                            child: Text(
                              "No items in $selectedCategory",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : (selectedCategory == "Images" ||
                                selectedCategory == "Sections")
                            ? GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: pagedItems.length,
                                itemBuilder: (ctx, i) {
                                  final item = pagedItems[i];
                                  final isFolder = item["is_folder"] ?? false;

                                  if (isFolder) {
                                    // Folder - show as card with folder icon
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => currentFolderId = item["id"]),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.folder,
                                                color: const Color(0xFF4A90E2),
                                                size: 48),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              child: Text(
                                                item["label"] ??
                                                    item["key"] ??
                                                    "Folder",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0066CC),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  // File/Image card item
                                  bool isImage = selectedCategory == "Images";
                                  String? imageUrl =
                                      isImage ? item["content"] : null;

                                  return GestureDetector(
                                    onLongPress: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Options"),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _showEditDialog(
                                                    context, app, item);
                                              },
                                              child: const Text("Edit"),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _deleteItem(
                                                    context, app, item["id"]);
                                              },
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topLeft: Radius.circular(12),
                                                    topRight: Radius.circular(12),
                                                  ),
                                                  child: isImage && imageUrl != null
                                                      ? Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Container(
                                                              color: Colors.grey[200],
                                                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                                            );
                                                          },
                                                          loadingBuilder: (context, child, loadingProgress) {
                                                            if (loadingProgress == null) return child;
                                                            return Container(
                                                              color: Colors.grey[200],
                                                              child: const Center(
                                                                child: SizedBox(
                                                                  width: 20,
                                                                  height: 20,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        )
                                                      : Container(
                                                          color: Colors.grey[100],
                                                          child: Center(
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(
                                                                  _getFileIcon(item["label"] ?? ""),
                                                                  size: 48,
                                                                  color: const Color(0xFF4A90E2),
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Text(
                                                                  _getFileExtension(item["label"] ?? ""),
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
                                                if (isImage)
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Row(
                                                      children: [
                                                        InkWell(
                                                          onTap: () => _showEditDialog(context, app, item),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.4),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            padding: const EdgeInsets.all(6),
                                                            child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        InkWell(
                                                          onTap: () => _deleteItem(context, app, item["id"]),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.4),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            padding: const EdgeInsets.all(6),
                                                            child: const Icon(Icons.delete, size: 16, color: Colors.white),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item["label"] ??
                                                      item["key"] ??
                                                      "",
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0066CC),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDate(
                                                      item["created_at"] ?? ""),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                                if (item["tags"] is List &&
                                                    (item["tags"] as List)
                                                        .isNotEmpty)
                                                  ...[
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: (item["tags"]
                                                              as List)
                                                          .take(2)
                                                          .map<Widget>(
                                                              (tag) => Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .blue[50],
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                4,
                                                                              ),
                                                                    ),
                                                                    child: Text(
                                                                      tag
                                                                          .toString(),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: Colors
                                                                            .blue[700],
                                                                      ),
                                                                    ),
                                                                  ))
                                                          .toList(),
                                                    ),
                                                  ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                itemCount: pagedItems.length,
                                itemBuilder: (ctx, i) {
                                  final item = pagedItems[i];
                                  final isFolder = item["is_folder"] ?? false;

                                  return GestureDetector(
                                    onTap: isFolder
                                        ? () => setState(
                                            () => currentFolderId = item["id"])
                                        : null,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isFolder
                                                ? Icons.folder
                                                : Icons.description_outlined,
                                            color: isFolder
                                                ? const Color(0xFF4A90E2)
                                                : const Color(0xFFFFA500),
                                            size: 28,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item["label"] ?? item["key"],
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0066CC),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isFolder
                                                      ? "Folder"
                                                      : (item["content"] ?? "")
                                                          .toString(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton(
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                child: const Text("Edit"),
                                                onTap: () => _showEditDialog(
                                                    context, app, item),
                                              ),
                                              PopupMenuItem(
                                                child: const Text("Delete"),
                                                onTap: () => _deleteItem(
                                                    context, app, item["id"]),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
          ),
        ),
        // AI Content Generator Dialog
        AIContentGenerator(
          open: _showAIGenerator,
          onClose: () => setState(() => _showAIGenerator = false),
          onContentGenerated: _handleContentGenerated,
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue[50] : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? Colors.blue[300]! : Colors.grey[300]!,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? Colors.blue[700] : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNewContentMenu(BuildContext context, AppState app) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        final isTemplates = selectedCategory == "Templates";
        final isImages = selectedCategory == "Images";
        return AlertDialog(
          title: const Text("New Content"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTemplates)
                  ListTile(
                    leading: const Icon(Icons.style),
                    title: const Text("Create Template"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateDialog(context, app);
                    },
                  ),
                if (isTemplates)
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text("Upload Template"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showUploadTemplateDialog(context, app);
                    },
                  ),
                if (!isTemplates)
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text("Upload"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadFile(context, app);
                    },
                  ),
                if (isImages)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text("Add Image URL"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addImageUrl(context, app);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder),
                  title: const Text("New Folder"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showNewFolderDialog(context, app);
                  },
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
        );
      },
    );
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

  void _uploadFile(BuildContext context, AppState app) async {
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
          final fileKey = fileName
              .replaceAll(RegExp(r'\.[^.]+$'), '')
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

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
              await app.createContentWithCloudinary(
                fileKey,
                fileName,
                cloudinaryUrl,
                publicId,
                selectedCategory,
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

  // DUPLICATE - Kept for reference, actual implementation below
  /*
  List<Widget> _buildHeaderButtons_DUPLICATE(BuildContext context, AppState app) {
    return [
      ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const editor.TemplateEditorPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Create from Scratch"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0066CC),
          foregroundColor: Colors.white,
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: () => _showImportDialog(context, app),
        icon: const Icon(Icons.upload_file),
        label: const Text("Import Template"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[600],
          foregroundColor: Colors.white,
        ),
      ),
    ];
  }

  void _showImportDialog_DUPLICATE(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Import Template"),
        content: const Text("Import template functionality coming soon"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
  */

  List<Widget> _buildHeaderButtons_OLD(BuildContext context, AppState app) {
    List<Widget> buttons = [];

    switch (selectedCategory) {
      case "Templates":
        // Only "Create New" button
        buttons.add(
          ElevatedButton(
            onPressed: () => _showCreateDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text("Create New"),
              ],
            ),
          ),
        );
        break;

      case "Sections":
        // Both "Upload" and "New Folder" buttons
        buttons.add(
          ElevatedButton(
            onPressed: () => _uploadFile(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file, size: 18),
                SizedBox(width: 8),
                Text("Upload"),
              ],
            ),
          ),
        );
        buttons.add(const SizedBox(width: 12));
        buttons.add(
          ElevatedButton(
            onPressed: () => _showNewFolderDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text("New Folder"),
              ],
            ),
          ),
        );
        break;

      case "Images":
        // Both "Upload" and "New Folder" buttons
        buttons.add(
          ElevatedButton(
            onPressed: () => _uploadFile(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file, size: 18),
                SizedBox(width: 8),
                Text("Upload"),
              ],
            ),
          ),
        );
        buttons.add(const SizedBox(width: 12));
        buttons.add(
          ElevatedButton(
            onPressed: () => _showNewFolderDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text("New Folder"),
              ],
            ),
          ),
        );
        break;

      case "Snippets":
        // Only "New Folder" button
        buttons.add(
          ElevatedButton(
            onPressed: () => _showNewFolderDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text("New Folder"),
              ],
            ),
          ),
        );
        break;
    }

    return buttons;
  }

  void _showCreateDialog(BuildContext context, AppState app) {
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
                  _showTemplateGalleryDialog(context, app);
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
                  _showUploadTemplateDialog(context, app);
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

  void _showScratchTemplateDialog(BuildContext context, AppState app) {
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

  void _showTemplateGalleryDialog(BuildContext context, AppState app) {
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
      builder: (ctx) => AlertDialog(
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
                      keyCtrl.text =
                          template["name"]!.toLowerCase().replaceAll(" ", "_");
                      Navigator.pop(ctx);
                      _showScratchTemplateDialog(context, app);
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
    );
  }

  void _showUploadTemplateDialog(BuildContext context, AppState app) {
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

  // DUPLICATE - Commented out, using version below instead
  /*
  Widget _buildModernNavbar_DUPLICATE() {
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00CED1), Color(0xFF20B2AA)],
                ),
              ),
              child: const Icon(Icons.library_books,
                  color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: _currentNavIdx == 0,
                    onTap: () {
                      // In a real app, navigate to Dashboard
                      setState(() => _currentNavIdx = 0);
                      // You can navigate here using Navigator
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.description_outlined,
                    label: 'My Proposals',
                    isActive: _currentNavIdx == 1,
                    onTap: () {
                      setState(() => _currentNavIdx = 1);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.note_outlined,
                    label: 'Templates',
                    isActive: _currentNavIdx == 2,
                    onTap: () {
                      setState(() => _currentNavIdx = 2);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.collections,
                    label: 'Content Library',
                    isActive: _currentNavIdx == 3,
                    onTap: () {
                      setState(() => _currentNavIdx = 3);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.people_outline,
                    label: 'Collaboration',
                    isActive: _currentNavIdx == 4,
                    onTap: () {
                      setState(() => _currentNavIdx = 4);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.check_circle_outline,
                    label: 'Approvals',
                    isActive: _currentNavIdx == 5,
                    onTap: () {
                      setState(() => _currentNavIdx = 5);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.trending_up,
                    label: 'Analytics',
                    isActive: _currentNavIdx == 6,
                    onTap: () {
                      setState(() => _currentNavIdx = 6);
                    },
                  ),
                ],
              ),
            ),
          ),
          // Help & Logout
          Tooltip(
            message: 'Help',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Help is on the way!")),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.help_outline,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: 'Logout',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirm Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  */

  // DUPLICATE - Commented out, using version below instead
  /*
  Widget _buildNavItem_DUPLICATE({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
            mainAxisSize: MainAxisSize.min,
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
                  color: isActive ? const Color(0xFF00CED1) : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  */

  // Build header buttons (varies by category)
  List<Widget> _buildHeaderButtons(BuildContext context, AppState app) {
    List<Widget> buttons = [];

    switch (selectedCategory) {
      case "Sections":
        // Both "Upload" and "New Folder" buttons
        buttons.add(
          ElevatedButton(
            onPressed: () => _uploadFile(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file, size: 18),
                SizedBox(width: 8),
                Text("Upload"),
              ],
            ),
          ),
        );
        buttons.add(const SizedBox(width: 12));
        buttons.add(
          ElevatedButton(
            onPressed: () => _showNewFolderDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text("New Folder"),
              ],
            ),
          ),
        );
        break;

      case "Images":
        // Both "Upload" and "New Folder" buttons
        buttons.add(
          ElevatedButton(
            onPressed: () => _uploadFile(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file, size: 18),
                SizedBox(width: 8),
                Text("Upload"),
              ],
            ),
          ),
        );
        buttons.add(const SizedBox(width: 12));
        buttons.add(
          ElevatedButton(
            onPressed: () => _showNewFolderDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text("New Folder"),
              ],
            ),
          ),
        );
        break;

      case "Snippets":
        // Only "New Folder" button
        buttons.add(
          ElevatedButton(
            onPressed: () => _showNewFolderDialog(context, app),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text("New Folder"),
              ],
            ),
          ),
        );
        break;
    }

    return buttons;
  }


  // Build individual navigation item
  Widget _buildNavItem(
      String label, String assetPath, bool isActive, BuildContext context) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() => _currentPage = label);
              _navigateToPage(context, label);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFFCBD5E1),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: AssetService.buildImageWidget(assetPath,
                    fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0xFF2980B9), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFFCBD5E1),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath,
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFECF0F1),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isActive)
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushNamed(context, '/dashboard');
        break;
      case 'My Proposals':
        Navigator.pushNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushNamed(context, '/templates');
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
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    // Show confirmation dialog
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

  void _addImageUrl(BuildContext context, AppState app) {
    final labelCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Image URL"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: "Image Name",
                  hintText: "Enter image name",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Image URL",
                  hintText: "Enter image URL",
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
              if (labelCtrl.text.isEmpty || contentCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill all fields")),
                );
                return;
              }

              try {
                await app.createContent(
                  key: labelCtrl.text.toLowerCase().replaceAll(" ", "_"),
                  label: labelCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                  category: selectedCategory,
                  parentId: currentFolderId,
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Image uploaded successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to upload image: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text("Upload"),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Import Template"),
        content: const Text("Import template functionality coming soon"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // Delete item handler
  void _deleteItem(BuildContext context, AppState app, int itemId) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text(
            "Are you sure you want to delete this item? It will be moved to Trash."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog

              // Show loading state
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Deleting item..."),
                  duration: Duration(seconds: 2),
                ),
              );

              try {
                final result = await app.deleteContent(itemId);

                if (result) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Item moved to Trash"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {}); // Refresh UI
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to delete item"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error deleting item: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // Edit item handler
  void _showEditDialog(
      BuildContext context, AppState app, Map<String, dynamic> item) {
    final labelCtrl = TextEditingController(text: item["label"] ?? "");
    final contentCtrl = TextEditingController(text: item["content"] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Item"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: "Label",
                  hintText: "Enter item label",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Content",
                  hintText: "Enter item content",
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
              if (labelCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a label")),
                );
                return;
              }

              try {
                Navigator.pop(ctx);

                // Show loading message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Updating item..."),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Update the item
                final result = await app.updateContent(
                  item["id"],
                  label: labelCtrl.text,
                  content: contentCtrl.text,
                );

                if (result) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Item updated successfully"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {});
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to update item"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error updating item: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066CC),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Show new folder dialog
  void _showNewFolderDialog(BuildContext context, AppState app) {
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
                            "Folder '${folderNameCtrl.text}' created successfully"),
                        backgroundColor: Colors.green,
                      ),
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
}
