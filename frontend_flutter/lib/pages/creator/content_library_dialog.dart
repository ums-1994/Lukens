import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/content_library_service.dart';
import '../../services/auth_service.dart';
import '../../api.dart';

class ContentLibrarySelectionDialog extends StatefulWidget {
  const ContentLibrarySelectionDialog({super.key});

  @override
  State<ContentLibrarySelectionDialog> createState() =>
      _ContentLibrarySelectionDialogState();
}

class _ContentLibrarySelectionDialogState
    extends State<ContentLibrarySelectionDialog> {
  final ContentLibraryService _svc = ContentLibraryService();
  List<Map<String, dynamic>> _modules = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _getToken() {
    // Try AuthService first
    final authToken = AuthService.token;
    if (authToken != null && authToken.isNotEmpty) {
      return authToken;
    }

    // Try AppState as fallback
    try {
      final appState = context.read<AppState>();
      return appState.authToken;
    } catch (e) {
      print('Error getting token from AppState: $e');
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = _getToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No authentication token available');
        setState(() {
          _modules = [];
          _loading = false;
        });
        return;
      }

      print('✅ Loading content with token (length: ${token.length})');
      final modules = await _svc.getContentModules(token: token);
      setState(() {
        _modules = modules;
        _loading = false;
      });
      print('✅ Loaded ${modules.length} content modules');
    } catch (e) {
      print('❌ Error loading content modules: $e');
      setState(() {
        _modules = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _modules
        .where((m) =>
            _search.isEmpty ||
            (m['label'] as String? ?? '')
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 700,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A3A52),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Insert from Content Library',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF00BCD4)),
                  hintText: 'Search library...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF00BCD4), width: 2),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00BCD4)),
                          ),
                          SizedBox(height: 16),
                          Text('Loading content library...'),
                        ],
                      ),
                    )
                  : _modules.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Content Library is Empty',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add content from the Content Library page\n(Navigate using the left sidebar)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try a different search term',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final m = filtered[index];
                                final category = m['category'] ?? 'Unknown';
                                final content = (m['content'] ?? '').toString();
                                final subtitle = content.length > 150
                                    ? '${content.substring(0, 150)}...'
                                    : content;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(category)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: _getCategoryColor(category),
                                    ),
                                  ),
                                  title: Text(
                                    m['label'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(category)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _getCategoryColor(category),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Color(0xFF00BCD4),
                                  ),
                                  onTap: () => Navigator.of(context).pop(m),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'sections':
        return Icons.article;
      case 'images':
        return Icons.image;
      case 'snippets':
        return Icons.snippet_folder;
      case 'documents':
        return Icons.description;
      default:
        return Icons.folder;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'sections':
        return const Color(0xFF00BCD4);
      case 'images':
        return const Color(0xFF4CAF50);
      case 'snippets':
        return const Color(0xFFFF9800);
      case 'documents':
        return const Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }
}
