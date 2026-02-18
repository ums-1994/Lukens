import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/content_library_service.dart';
import '../../services/auth_service.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';

class ContentLibrarySelectionDialog extends StatefulWidget {
  final String? category;
  final String? parentFolderLabel;
  final bool requireParentFolderMatch;
  final bool imagesOnly;
  final bool textOnly;
  final bool thumbnailsOnly;
  final String? dialogTitle;

  const ContentLibrarySelectionDialog({
    super.key,
    this.category,
    this.parentFolderLabel,
    this.requireParentFolderMatch = false,
    this.imagesOnly = false,
    this.textOnly = false,
    this.thumbnailsOnly = false,
    this.dialogTitle,
  });

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

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), '');
  }

  bool _isFolder(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 't' || v == 'yes' || v == 'y';
    }
    return false;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool _isHttpUrl(dynamic value) {
    if (value is! String) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  String _cleanPreviewText(String raw) {
    var text = raw.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

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
      final modules = await _svc.getContentModules(
        token: token,
        category: widget.category,
      );
      final nonFolderCount =
          modules.where((m) => m['is_folder'] != true).length;
      setState(() {
        _modules = modules;
        _loading = false;
      });
      print(
          '✅ Loaded ${modules.length} content modules (${nonFolderCount} non-folder items available for insertion)');
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
    int? parentFolderId;
    if (widget.parentFolderLabel != null &&
        widget.parentFolderLabel!.trim().isNotEmpty) {
      final target = _normalizeName(widget.parentFolderLabel!);
      for (final m in _modules) {
        final isFolder = _isFolder(m['is_folder']);
        final label = _normalizeName((m['label'] ?? '').toString());
        final key = _normalizeName((m['key'] ?? '').toString());
        if (isFolder && (label == target || key == target)) {
          parentFolderId = _asInt(m['id']);
          break;
        }
      }
    }

    // Filter: exclude folders (only show actual content blocks for insertion)
    // and apply search filter
    final filtered = _modules.where((m) {
      // Skip folders - only show content blocks that can be inserted
      if (_isFolder(m['is_folder'])) {
        return false;
      }

      if (widget.parentFolderLabel != null &&
          widget.parentFolderLabel!.trim().isNotEmpty) {
        if (widget.requireParentFolderMatch && parentFolderId == null) {
          return false;
        }
        // Only apply the parent-folder filter if we successfully resolved the folder id.
        // If the folder can't be found (e.g. is_folder comes back as a non-bool), we fall
        // back to showing all items rather than hiding everything.
        if (parentFolderId != null) {
          final parsedPid = _asInt(m['parent_id']);
          if (parsedPid != parentFolderId) {
            return false;
          }
        }
      }

      if (widget.imagesOnly) {
        final content = m['content'];
        if (!_isHttpUrl(content)) {
          return false;
        }
      }

      if (widget.textOnly) {
        final content = m['content'];
        if (_isHttpUrl(content)) {
          return false;
        }
      }

      // Apply search filter
      if (_search.isNotEmpty) {
        final label = (m['label'] as String? ?? '').toLowerCase();
        final content = (m['content'] as String? ?? '').toLowerCase();
        final category = (m['category'] as String? ?? '').toLowerCase();
        final searchLower = _search.toLowerCase();
        return label.contains(searchLower) ||
            content.contains(searchLower) ||
            category.contains(searchLower);
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassContainer(
        borderRadius: 24,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 900,
          height: 600,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.darkBg2,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.library_books,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      widget.dialogTitle ?? 'Insert from Content Library',
                      style: PremiumTheme.titleMedium,
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
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: PremiumTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: PremiumTheme.darkBg3.withValues(alpha: 0.8),
                    prefixIcon:
                        const Icon(Icons.search, color: PremiumTheme.teal),
                    hintText: 'Search library...',
                    hintStyle: PremiumTheme.bodyMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: PremiumTheme.glassWhiteBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: PremiumTheme.teal, width: 2),
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
                            : (widget.imagesOnly && widget.thumbnailsOnly)
                                ? GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final m = filtered[index];
                                      final url =
                                          (m['content'] ?? '').toString();
                                      return InkWell(
                                        onTap: () =>
                                            Navigator.of(context).pop(m),
                                        borderRadius: BorderRadius.circular(12),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, stack) {
                                                  return Container(
                                                    color: PremiumTheme.darkBg3,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                                  color: Colors.black
                                                      .withOpacity(0.45),
                                                  child: Text(
                                                    (m['label'] ?? 'Untitled')
                                                        .toString(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final m = filtered[index];
                                      final category =
                                          m['category'] ?? 'Unknown';
                                      final rawContent =
                                          (m['content'] ?? '').toString();
                                      final preview =
                                          _cleanPreviewText(rawContent);
                                      final subtitle = preview.length > 150
                                          ? '${preview.substring(0, 150)}...'
                                          : preview;

                                      final showImageThumb =
                                          widget.imagesOnly &&
                                              _isHttpUrl(m['content']);

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        leading: showImageThumb
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  (m['content'] as String),
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stack) {
                                                    return Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getCategoryColor(
                                                                    category)
                                                                .withOpacity(
                                                                    0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.image,
                                                        color:
                                                            _getCategoryColor(
                                                                category),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            : Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: _getCategoryColor(
                                                          category)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  _getCategoryIcon(category),
                                                  color: _getCategoryColor(
                                                      category),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    _getCategoryColor(category)
                                                        .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _getCategoryColor(
                                                      category),
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
                                        onTap: () =>
                                            Navigator.of(context).pop(m),
                                      );
                                    },
                                  ),
              ),
            ],
          ),
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
