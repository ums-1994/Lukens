import 'package:flutter/material.dart';
import '../services/content_library_service.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key});

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  List<Map<String, dynamic>> _contentModules = [];
  List<Map<String, dynamic>> _contentTypes = [];
  bool _isLoading = true;
  String? _authToken;

  // Create an instance of ContentLibraryService for use in this class
  late final ContentLibraryService contentLibraryService;

  // Filter and search
  String _selectedContentType = 'All';
  String _searchQuery = '';
  List<String> _selectedTags = [];

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    contentLibraryService = ContentLibraryService();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // For now, use mock data
      // In a real app, this would get the token from secure storage
      // or from the current user session
      _authToken = null;

      // Load content types
      _contentTypes = await contentLibraryService.getContentTypes();
      print('Debug: Loaded content types: $_contentTypes');

      // Load content modules
      await _loadContentModules();
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading content library: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContentModules() async {
    final modules = await contentLibraryService.getContentModules(
      contentType: _selectedContentType == 'All' ? null : _selectedContentType,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      tags: _selectedTags.isEmpty ? null : _selectedTags,
      authToken: _authToken,
    );

    setState(() {
      _contentModules = modules;
    });
    print('Debug: Loaded ${modules.length} content modules');
    for (var module in modules) {
      print(
          'Debug: Module - ${module['title']} (${module['content_type']}) - editable: ${module['is_editable']}');
    }
  }

  void _applyFilters() {
    _loadContentModules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/creator_dashboard'),
        ),
        title: const Text(
          'Content Library',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _navigateToPage(context, value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'Dashboard',
                child: Row(
                  children: [
                    Icon(Icons.dashboard_outlined, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text('Dashboard'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'My Proposals',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text('My Proposals'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Templates',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text('Templates'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Collaboration',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text('Collaboration'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Approvals Status',
                child: Row(
                  children: [
                    Icon(Icons.approval_outlined, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text('Approvals Status'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Analytics (My Pipeline)',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text('Analytics (My Pipeline)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                _buildFilters(),
                Expanded(
                  child: _contentModules.isEmpty
                      ? _buildEmptyState()
                      : _buildContentGrid(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Content Library',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage reusable content blocks for proposals',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showCreateModuleDialog,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Content Block'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search content blocks...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey[400], size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Filter dropdown
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3F3F46)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedContentType,
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                icon:
                    Icon(Icons.filter_list, color: Colors.grey[400], size: 20),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All')),
                  ..._contentTypes.map((type) => DropdownMenuItem(
                        value: type['name'],
                        child: Text(type['name']),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedContentType = value!);
                  _applyFilters();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No content blocks found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first content block to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateModuleDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Content Block'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: _contentModules.length,
        itemBuilder: (context, index) {
          final module = _contentModules[index];
          return _buildContentCard(module);
        },
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> module) {
    Map<String, dynamic> contentType;
    try {
      contentType = _contentTypes.firstWhere(
        (type) =>
            type['name'] == module['content_type'] ||
            type['id'] == module['content_type'],
      );
    } catch (e) {
      contentType = {'name': 'Unknown', 'description': ''};
    }

    final isEditable = module['is_editable'] ?? true;
    print('Debug: Module ${module['title']} - isEditable: $isEditable');
    final lastModified = module['updated_at'] ?? module['created_at'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showModuleDetails(module),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27272A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  contentType['name'],
                                  style: const TextStyle(
                                    color: Color(0xFFD4D4D8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (!isEditable) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFF52525B)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Locked',
                                    style: TextStyle(
                                      color: Color(0xFFA1A1AA),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Content preview
                Expanded(
                  child: Text(
                    module['content'],
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Footer with date and actions
                Row(
                  children: [
                    Text(
                      'Modified ${_formatDate(lastModified)}',
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _showModuleDetails(module),
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          color: const Color(0xFFA1A1AA),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFFA1A1AA),
                          ),
                        ),
                        if (isEditable)
                          IconButton(
                            onPressed: () {
                              print(
                                  'Debug: Edit button clicked for ${module['title']}');
                              _showEditModuleDialog(module);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: const Color(0xFFA1A1AA),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: const Color(0xFFA1A1AA),
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
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getContentTypeName(String? contentType) {
    try {
      final type = _contentTypes.firstWhere(
        (type) => type['id'] == contentType || type['name'] == contentType,
      );
      return type['name'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showModuleDetails(Map<String, dynamic> module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(module['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Type: ${_getContentTypeName(module['content_type'])}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(module['content']),
              if (module['tags'] != null &&
                  (module['tags'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: (module['tags'] as List).map<Widget>((tag) {
                    return Chip(
                      label: Text(tag),
                      backgroundColor: Colors.blue[100],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _insertIntoProposal(module);
            },
            child: const Text('Insert into Proposal'),
          ),
        ],
      ),
    );
  }

  void _showCreateModuleDialog() {
    _showModuleFormDialog();
  }

  void _showEditModuleDialog(Map<String, dynamic> module) {
    print('Debug: Opening edit dialog for ${module['title']}');

    // First show a simple test dialog to see if dialogs work at all
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit: ${module['title']}'),
        content: Text('This is a test dialog for editing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showModuleFormDialog(module: module);
            },
            child: const Text('Open Full Editor'),
          ),
        ],
      ),
    );
  }

  void _showModuleFormDialog({Map<String, dynamic>? module}) {
    final isEditing = module != null;
    print(
        'Debug: Form dialog - isEditing: $isEditing, module: ${module?['title']}');
    final titleController = TextEditingController(text: module?['title'] ?? '');
    final contentController =
        TextEditingController(text: module?['content'] ?? '');
    String selectedType = module?['content_type'] ??
        (_contentTypes.isNotEmpty ? _contentTypes.first['id'] : '');
    print(
        'Debug: Form dialog - selectedType: $selectedType, contentTypes: ${_contentTypes.length}');
    final tagsController = TextEditingController(
        text: (module?['tags'] as List?)?.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: Text(
            isEditing ? 'Edit Module' : 'Create Module',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType.isNotEmpty
                      ? selectedType
                      : (_contentTypes.isNotEmpty
                          ? _contentTypes.first['id']
                          : null),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Content Type',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                  dropdownColor: const Color(0xFF18181B),
                  items: _contentTypes.map<DropdownMenuItem<String>>((type) {
                    return DropdownMenuItem<String>(
                      value: type['id'] as String,
                      child: Text(
                        type['name'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    print('Debug: Dropdown changed to: $value');
                    setState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Content',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tagsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'e.g., web development, mobile, design',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print(
                    'Debug: Save button pressed - title: ${titleController.text}, contentType: $selectedType');
                _saveModule(
                  isEditing: isEditing,
                  moduleId: module?['id'],
                  title: titleController.text,
                  contentType: selectedType,
                  content: contentController.text,
                  tags: tagsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveModule({
    required bool isEditing,
    String? moduleId,
    required String title,
    required String contentType,
    required String content,
    required List<String> tags,
  }) async {
    print(
        'Debug: Save module called - isEditing: $isEditing, title: $title, contentType: $contentType');

    if (title.isEmpty || contentType.isEmpty || content.isEmpty) {
      print(
          'Debug: Validation failed - title: $title, contentType: $contentType, content: ${content.length} chars');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    Navigator.pop(context);

    try {
      if (isEditing) {
        await contentLibraryService.updateContentModule(
          moduleId: moduleId!,
          title: title,
          content: content,
          tags: tags,
          authToken: _authToken,
        );
      } else {
        await contentLibraryService.createContentModule(
          title: title,
          contentType: contentType,
          content: content,
          tags: tags,
          authToken: _authToken,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing
              ? 'Module updated successfully'
              : 'Module created successfully'),
        ),
      );
      _loadContentModules();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving module: $e')),
      );
    }
  }

  void _insertIntoProposal(Map<String, dynamic> module) {
    // This would integrate with the proposal creation flow
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Content "${module['title']}" will be inserted into your proposal'),
        action: SnackBarAction(
          label: 'View Proposal',
          onPressed: () {
            // Navigate to proposal creation/editing
          },
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/creator_dashboard');
        break;
      case 'My Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        // Already on content library page
        break;
      case 'Collaboration':
        Navigator.pushReplacementNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
        Navigator.pushReplacementNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/creator_dashboard');
    }
  }
}
