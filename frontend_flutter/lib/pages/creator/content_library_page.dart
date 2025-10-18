import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../api.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key});

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  final keyCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  String selectedCategory = "Templates";
  String sortBy = "Last Edited (Newest First)";
  int currentPage = 1;
  int itemsPerPage = 10;
  int _currentNavIdx = 3; // Content Library is index 3
  int? currentFolderId; // Track current folder being viewed

  final List<String> categories = [
    "Templates",
    "Sections",
    "Images",
    "Snippets"
  ];

  final List<String> sortOptions = [
    "Last Edited (Newest First)",
    "Last Edited (Oldest First)",
    "Name (A-Z)",
    "Name (Z-A)"
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Filter items by selected category and current folder
    final filteredItems = app.contentBlocks.where((item) {
      final category = item["category"] ?? "Templates";
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Row(
        children: [
          // Modern Navigation Sidebar
          _buildModernNavbar(),
          // Category Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey[300]!))),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Categories",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  ...categories.map((category) {
                    final count = app.contentBlocks
                        .where((item) =>
                            (item["category"] ?? "Templates").toLowerCase() ==
                            category.toLowerCase())
                        .length;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                            currentPage = 1;
                          });
                        },
                        child: Container(
                          color: selectedCategory == category
                              ? const Color(0xFFE8F0F7)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                color: selectedCategory == category
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selectedCategory == category
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: selectedCategory == category
                                        ? const Color(0xFF1E3A8A)
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                              Text(
                                category == "Templates"
                                    ? count.toString()
                                    : "-",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
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
                  // Header with back button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (currentFolderId != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () =>
                                    setState(() => currentFolderId = null),
                                tooltip: "Go back",
                              ),
                            ),
                          Text(
                            "$selectedCategory /",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (currentFolderId != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              app.contentBlocks.firstWhere(
                                    (item) => item["id"] == currentFolderId,
                                    orElse: () => {"label": "Folder"},
                                  )["label"] ??
                                  "Folder",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0066CC),
                                  ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: _buildHeaderButtons(context, app),
                      ),
                    ],
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
                        : selectedCategory == "Images"
                            ? GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: pagedItems.length,
                                itemBuilder: (ctx, i) {
                                  final item = pagedItems[i];
                                  final isFolder = item["is_folder"] ?? false;

                                  if (isFolder) {
                                    // Folder in Images category - show as list-like item
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => currentFolderId = item["id"]),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.folder,
                                                color: const Color(0xFF4A90E2),
                                                size: 32),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              child: Text(
                                                item["label"] ??
                                                    item["key"] ??
                                                    "Folder",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 11,
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

                                  // Image grid item
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
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(8),
                                                topRight: Radius.circular(8),
                                              ),
                                              child: Image.network(
                                                item["content"] ?? "",
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons
                                                        .image_not_supported),
                                                  );
                                                },
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              item["label"] ??
                                                  item["key"] ??
                                                  "",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF0066CC),
                                              ),
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

  void _showCreateDialog(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create New Template"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCreateOption(
                context: ctx,
                app: app,
                title: "Start from Scratch",
                icon: Icons.edit_note,
                description: "Create a new template from blank",
                onTap: () {
                  Navigator.pop(ctx);
                  _showScratchTemplateDialog(context, app);
                },
              ),
              const SizedBox(height: 12),
              _buildCreateOption(
                context: ctx,
                app: app,
                title: "Choose from Templates Gallery",
                icon: Icons.collections,
                description: "Select from pre-built templates",
                onTap: () {
                  Navigator.pop(ctx);
                  _showTemplateGalleryDialog(context, app);
                },
              ),
              const SizedBox(height: 12),
              _buildCreateOption(
                context: ctx,
                app: app,
                title: "Upload Template",
                icon: Icons.cloud_upload_outlined,
                description: "Upload a template from your computer",
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.bytes != null || file.path != null) {
          final fileName = file.name;

          // Create a unique key for the image
          final imageKey = fileName
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
                content: const Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text("Uploading image to Cloudinary..."),
                  ],
                ),
              ),
            );
          }

          try {
            // Upload to Cloudinary via backend
            // Use bytes on web, path on native platforms
            final uploadResult = file.bytes != null
                ? await app.uploadImageToCloudinary("",
                    fileBytes: file.bytes, fileName: fileName)
                : await app.uploadImageToCloudinary(file.path!);

            if (mounted) Navigator.pop(context); // Close loading dialog

            if (uploadResult != null && uploadResult['success'] == true) {
              final cloudinaryUrl = uploadResult['url'];
              final publicId = uploadResult['public_id'];

              // Add to content blocks
              app.contentBlocks.add({
                "id": DateTime.now().millisecondsSinceEpoch,
                "key": imageKey,
                "label": fileName,
                "content": cloudinaryUrl,
                "category": selectedCategory,
                "created_at": DateTime.now().toIso8601String(),
                "public_id": publicId,
                "is_folder": false,
                if (currentFolderId != null) "parent_id": currentFolderId,
              });

              app.notifyListeners();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Image '$fileName' uploaded successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              final errorMsg = uploadResult?['error'] ?? 'Upload failed';
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error uploading image: $errorMsg"),
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
                  content: Text("Error uploading image: ${e.toString()}"),
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

  List<Widget> _buildHeaderButtons(BuildContext context, AppState app) {
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
                  keyCtrl.text.trim(),
                  labelCtrl.text.trim(),
                  contentCtrl.text.trim(),
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
                          keyCtrl.text,
                          labelCtrl.text,
                          fileContent ?? contentCtrl.text,
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

  Widget _buildModernNavbar() {
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

  Widget _buildNavItem({
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

  void _deleteItem(BuildContext context, AppState app, int itemId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Show loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Deleting...")),
              );

              // Delete the item
              final success = await app.deleteContent(itemId);

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Item deleted successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Error deleting item"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, AppState app, Map<String, dynamic> item) {
    final editLabelCtrl = TextEditingController(text: item["label"] ?? "");
    final editContentCtrl = TextEditingController(text: item["content"] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Item"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editLabelCtrl,
                decoration: const InputDecoration(
                  labelText: "Label",
                  hintText: "Item label",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editContentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Content",
                  hintText: "Item content",
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
            onPressed: () {
              Navigator.pop(ctx);

              // Update the item
              item["label"] = editLabelCtrl.text;
              item["content"] = editContentCtrl.text;

              app.notifyListeners();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Item updated"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CED1),
              foregroundColor: Colors.black,
            ),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

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
                // Create folder with parent_id if inside a folder
                await app.createContent(
                  folderNameCtrl.text.toLowerCase().replaceAll(" ", "_"),
                  folderNameCtrl.text.trim(),
                  "", // Folders have empty content
                  category: selectedCategory,
                  parentId: currentFolderId,
                  isFolder: true,
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Folder created successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to create folder: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}
