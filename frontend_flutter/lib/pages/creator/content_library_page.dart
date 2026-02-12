import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/asset_service.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/ai_content_generator.dart';
import '../../widgets/app_side_nav.dart';

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

  static const Set<String> _textCategories = {
    'sections',
    'company profile',
    'team',
    'case studies',
    'methodology',
    'assumptions',
    'risks',
    'pricing',
    'templates',
  };

  final List<String> categories = [
    "Sections",
    "Company Profile",
    "Team",
    "Case Studies",
    "Methodology",
    "Template",
    "Assumptions",
    "Risks",
    "Pricing",
    "Images",
    "Snippets",
    "Trash"
  ];

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
      if (mounted) {
        final app = context.read<AppState>();
        app.setCurrentNavLabel('Content Library');
        if (app.contentBlocks.isEmpty) {
          await app.fetchContent();
        }
      }
    });
  }

  Widget _buildTextBlockCard({
    required BuildContext context,
    required AppState app,
    required Map<String, dynamic> item,
  }) {
    final isFolder = item["is_folder"] == true;
    if (isFolder) {
      return GestureDetector(
        onTap: () => setState(() => currentFolderId = item["id"]),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder, color: Colors.white70, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item["label"] ?? item["key"] ?? "Folder",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      );
    }

    final rawContent = (item["content"] ?? "").toString();
    final cleanedContent = _removeTagComment(rawContent);
    final previewText = _stripHtmlTags(cleanedContent);
    final tags = item["tags"] is List && (item["tags"] as List).isNotEmpty
        ? List<String>.from(item["tags"])
        : _extractTagsFromContent(rawContent);

    final label = item["label"] ?? item["key"] ?? "Untitled";
    final updatedAt = item["updated_at"];
    final versionLabel =
        item["version"] != null ? "Version ${item["version"]}" : "Version 1";
    final usesLabel =
        item["usage_count"] != null ? "${item["usage_count"]} uses" : "0 uses";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Updated ${_formatDate(updatedAt)}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: "Version history",
                icon: const Icon(Icons.history, size: 18, color: Colors.white70),
                onPressed: () => _showVersionHistory(context),
              ),
              IconButton(
                tooltip: "Edit block",
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Colors.white70),
                onPressed: () => _showEditDialog(context, app, item),
              ),
              IconButton(
                tooltip: "Delete block",
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.redAccent),
                onPressed: () => _deleteItem(context, app, item["id"]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            previewText.isNotEmpty
                ? previewText
                : "No preview available for this block.",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(3).map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64B5F6),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                versionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                usesLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isFullTemplate(Map<String, dynamic> item) {
    // Check if item has template structure (sections, templateType, etc.)
    final content = (item["content"] ?? "").toString();
    final key = (item["key"] ?? "").toString().toLowerCase();
    final label = (item["label"] ?? "").toString().toLowerCase();
    
    // Check for template markers in key/label
    if (key.contains("_template") || key.contains("sow_") || key.contains("proposal_")) {
      return true;
    }
    if (label.contains("template") || label.contains("sow") || label.contains("statement of work")) {
      return true;
    }
    
    // Check if content contains template structure markers
    if (content.contains('"templateType"') || 
        content.contains('"sections"') || 
        content.contains('template_type') ||
        content.contains('Statement of Work') ||
        content.contains('SOW Template')) {
      return true;
    }
    
    return false;
  }

  Widget _buildTemplateCard({
    required BuildContext context,
    required AppState app,
    required Map<String, dynamic> item,
  }) {
    final label = item["label"] ?? item["key"] ?? "Untitled Template";
    final content = (item["content"] ?? "").toString();
    final updatedAt = item["updated_at"];
    final isSOW = label.toLowerCase().contains("sow") || 
                  label.toLowerCase().contains("statement of work");
    final isProposal = label.toLowerCase().contains("proposal");
    
    // Parse template sections if available in content
    List<String> sections = [];
    try {
      // Try to parse JSON structure
      if (content.trim().startsWith('{')) {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded.containsKey('sections')) {
          final sectionsList = decoded['sections'];
          if (sectionsList is List) {
            for (var section in sectionsList) {
              if (section is Map && section.containsKey('title')) {
                sections.add(section['title'].toString());
              } else if (section is String) {
                sections.add(section);
              }
            }
          }
        }
      } else if (content.contains('"sections"') || content.contains('sections:')) {
        // Try regex parsing
        final sectionsMatch = RegExp(r'"sections":\s*\[(.*?)\]', dotAll: true).firstMatch(content);
        if (sectionsMatch != null) {
          final sectionsStr = sectionsMatch.group(1)!;
          // Try to extract section titles from objects
          final titleMatches = RegExp(r'"title":\s*"([^"]+)"').allMatches(sectionsStr);
          if (titleMatches.isNotEmpty) {
            sections = titleMatches.map((m) => m.group(1)!).toList();
          } else {
            // Fallback: extract simple string values
            final sectionMatches = RegExp(r'"([^"]+)"').allMatches(sectionsStr);
            sections = sectionMatches.map((m) => m.group(1)!).toList();
          }
        }
      }
    } catch (e) {
      // Fallback: parse from content structure
    }
    
    // If no sections found, use defaults based on template type
    if (sections.isEmpty) {
      if (isSOW) {
        sections = [
          'Project Overview',
          'Scope of Work',
          'Deliverables',
          'Timeline & Milestones',
          'Resources & Team',
          'Terms & Conditions'
        ];
      } else if (isProposal) {
        sections = [
          'Executive Summary',
          'Company Profile',
          'Scope & Deliverables',
          'Timeline',
          'Investment',
          'Terms & Conditions'
        ];
      }
    }

    // Get template type color
    Color templateColor;
    IconData templateIcon;
    if (isSOW) {
      templateColor = PremiumTheme.success; // Green for SOW
      templateIcon = Icons.work_outline;
    } else if (isProposal) {
      templateColor = PremiumTheme.info; // Blue for Proposal
      templateIcon = Icons.description_outlined;
    } else {
      templateColor = PremiumTheme.purple; // Purple default
      templateIcon = Icons.style;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: PremiumTheme.glassCard(
        borderRadius: 20,
        gradientStart: templateColor,
        gradientEnd: templateColor.withValues(alpha: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to template editor or preview
            _showTemplatePreview(context, item);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: templateColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(templateIcon, color: templateColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (updatedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Updated ${_formatDate(updatedAt)}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "Edit template",
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                      onPressed: () => _showEditDialog(context, app, item),
                    ),
                    IconButton(
                      tooltip: "Delete template",
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () => _deleteItem(context, app, item["id"]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Template Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: templateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: templateColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isSOW ? "STATEMENT OF WORK" : isProposal ? "PROPOSAL" : "TEMPLATE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: templateColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                if (sections.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "Sections:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sections.take(6).map((section) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 12, color: PremiumTheme.teal),
                            const SizedBox(width: 4),
                            Text(
                              section,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  if (sections.length > 6)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "+ ${sections.length - 6} more sections",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    _stripHtmlTags(content).length > 150
                        ? "${_stripHtmlTags(content).substring(0, 150)}..."
                        : _stripHtmlTags(content),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Use template to create new document
                          _useTemplate(context, item);
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text("Use Template"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: templateColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showTemplatePreview(context, item),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text("Preview"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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

  void _showTemplatePreview(BuildContext context, Map<String, dynamic> item) {
    final content = (item["content"] ?? "").toString();
    final cleanedContent = _removeTagComment(content);
    
    // Check if content is JSON (full template structure)
    Widget contentWidget;
    try {
      if (content.trim().startsWith('{')) {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded.containsKey('sections')) {
          // Render as structured template
          contentWidget = _buildStructuredTemplatePreview(Map<String, dynamic>.from(decoded));
        } else {
          // Render as formatted text
          contentWidget = _buildHtmlPreview(cleanedContent);
        }
      } else {
        // Render HTML content properly
        contentWidget = _buildHtmlPreview(cleanedContent);
      }
    } catch (e) {
      // Fallback: render as formatted text
      contentWidget = _buildHtmlPreview(cleanedContent);
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: PremiumTheme.darkBg2,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: PremiumTheme.darkBg2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PremiumTheme.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.preview, color: PremiumTheme.teal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item["label"] ?? "Template Preview",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const Divider(height: 32, color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  child: contentWidget,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredTemplatePreview(Map<String, dynamic> decoded) {
    final sections = decoded['sections'] as List?;
    if (sections == null) {
      return const Text("No content available", style: TextStyle(color: Colors.white70));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (decoded.containsKey('description'))
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              decoded['description'].toString(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ...sections.map<Widget>((section) {
          if (section is Map) {
            final title = section['title']?.toString() ?? '';
            final content = section['content']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHtmlPreview(content),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      ],
    );
  }

  Widget _buildHtmlPreview(String htmlContent) {
    // Parse and render HTML content as styled Flutter widgets
    final lines = htmlContent.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Parse HTML tags
      if (line.contains('<h1>')) {
        final text = _extractTextFromTag(line, 'h1');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      } else if (line.contains('<h2>')) {
        final text = _extractTextFromTag(line, 'h2');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      } else if (line.contains('<h3>')) {
        final text = _extractTextFromTag(line, 'h3');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      } else if (line.contains('<p>')) {
        final text = _extractTextFromTag(line, 'p');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ));
      } else if (line.contains('<ul>')) {
        // Skip opening ul tag
      } else if (line.contains('</ul>')) {
        // Skip closing ul tag
      } else if (line.contains('<li>')) {
        final text = _extractTextFromTag(line, 'li');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'â€¢ ',
                style: TextStyle(
                  color: PremiumTheme.teal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.contains('<ol>')) {
        // Skip opening ol tag
      } else if (line.contains('</ol>')) {
        // Skip closing ol tag
      } else if (line.trim().startsWith('|') && line.contains('|')) {
        // Markdown table row
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ));
      } else if (line.trim().startsWith('#')) {
        // Markdown heading
        final level = line.split(' ').first.length;
        final text = line.substring(level).trim();
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 8, top: level > 1 ? 12 : 16),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: level == 1 ? 24 : level == 2 ? 20 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      } else if (line.trim().startsWith('-') || line.trim().startsWith('*')) {
        // Markdown list item
        final text = line.replaceFirst(RegExp(r'^[\s\-\*]+'), '').trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'â€¢ ',
                style: TextStyle(
                  color: PremiumTheme.teal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().isNotEmpty) {
        // Plain text
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _stripHtmlTags(line),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.isEmpty
          ? [
              const Text(
                "No content available",
                style: TextStyle(color: Colors.white70),
              ),
            ]
          : widgets,
    );
  }

  String _extractTextFromTag(String html, String tag) {
    final openTag = '<$tag>';
    final closeTag = '</$tag>';
    final openIndex = html.indexOf(openTag);
    if (openIndex == -1) return html;
    final closeIndex = html.indexOf(closeTag, openIndex);
    if (closeIndex == -1) return html.substring(openIndex + openTag.length);
    return html
        .substring(openIndex + openTag.length, closeIndex)
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  void _useTemplate(BuildContext context, Map<String, dynamic> item) {
    // Navigate to proposal wizard or document editor with template
    Navigator.pushNamed(context, '/new-proposal', arguments: {'template': item});
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

  void _showVersionHistory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Version history coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<String> _extractTagsFromContent(String content) {
    final regex =
        RegExp(r'<!--\s*tags:\s*(\[[^\]]*\])\s*-->', caseSensitive: false);
    final match = regex.firstMatch(content);
    if (match != null && match.groupCount >= 1) {
      try {
        final List<dynamic> decoded = jsonDecode(match.group(1)!);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  String _removeTagComment(String content) {
    return content.replaceAll(
      RegExp(r'<!--\s*tags:.*?-->', caseSensitive: false, dotAll: true),
      '',
    );
  }

  String _stripHtmlTags(String html) {
    final withoutBr = html.replaceAll('<br>', ' ').replaceAll('<br/>', ' ');
    final withoutTags = withoutBr.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
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
        final category = (item["category"] ?? "Sections").toString();
        final normalizedCategory = category.toLowerCase();
        final selectedCategoryLower = selectedCategory.toLowerCase();
        final bool categoryMatch = selectedCategory == "Sections"
            ? _textCategories.contains(normalizedCategory)
            : normalizedCategory == selectedCategoryLower || 
              (selectedCategoryLower == "template" && normalizedCategory == "templates") ||
              (selectedCategoryLower == "templates" && normalizedCategory == "template");

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
      final label =
          (item["label"] ?? item["key"] ?? "").toString().toLowerCase();
      final content = (item["content"] ?? "").toString().toLowerCase();
      final tags = (item["tags"] is List)
          ? (item["tags"] as List)
              .map((e) => e.toString().toLowerCase())
              .toList()
          : <String>[];
      return label.contains(q) ||
          content.contains(q) ||
          tags.any((t) => t.contains(q));
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
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Consumer<AppState>(
                  builder: (context, app, _) {
                    final user = AuthService.currentUser ?? app.currentUser;
                    final role =
                        (user?['role'] ?? '').toString().toLowerCase().trim();
                    final isAdmin = role == 'admin' || role == 'ceo';
                    return AppSideNav(
                      isCollapsed: app.isSidebarCollapsed,
                      currentLabel: app.currentNavLabel,
                      isAdmin: isAdmin,
                      onToggle: app.toggleSidebar,
                      onSelect: (label) {
                        app.setCurrentNavLabel(label);
                        _navigateToPage(context, label);
                      },
                    );
                  },
                ),
                // Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: const [
                                  Color(0xFF0F172A),
                                  Color(0xFF1E293B),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PremiumTheme.glassWhiteBorder,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: PremiumTheme.purple
                                        .withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.library_books,
                                      size: 22, color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      "Content Library",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Manage reusable content blocks and images",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _showAIGenerator = true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PremiumTheme.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon:
                                      const Icon(Icons.auto_awesome, size: 20),
                                  label: const Text("AI Generate"),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showNewContentMenu(context, app),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PremiumTheme.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
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
                                  isActive: selectedCategory == "Templates" || selectedCategory == "Template",
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
                                    onChanged: (v) =>
                                        setState(() => searchQuery = v),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.search),
                                      prefixIconColor: Colors.white70,
                                      hintText: "Search content, tags...",
                                      hintStyle: const TextStyle(
                                          color: Colors.white54),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.12),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: PremiumTheme.purple
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: typeFilter,
                                      dropdownColor: PremiumTheme.darkBg2,
                                      iconEnabledColor: Colors.white70,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      items: const [
                                        DropdownMenuItem(
                                            value: "all",
                                            child: Text("All Types")),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          typeFilter = v ?? 'all';
                                        });
                                      },
                                    ),
                                  ),
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
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sort,
                                    size: 18, color: Colors.white70),
                                const SizedBox(width: 12),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: sortBy,
                                    dropdownColor: PremiumTheme.darkBg2,
                                    iconEnabledColor: Colors.white70,
                                    isDense: true,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white),
                                    items: sortOptions.map((option) {
                                      return DropdownMenuItem(
                                        value: option,
                                        child: Text(option),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        sortBy = value!;
                                        currentPage = 1;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Pagination Info
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 420;

                              final label = Text(
                                "${startIdx + 1}-${endIdx} of ${filteredItems.length}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              );

                              final controls = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: currentPage > 1
                                        ? () => setState(() => currentPage--)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    iconSize: 20,
                                    color: Colors.white70,
                                  ),
                                  IconButton(
                                    onPressed: currentPage < totalPages
                                        ? () => setState(() => currentPage++)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                    iconSize: 20,
                                    color: Colors.white70,
                                  ),
                                ],
                              );

                              if (!isNarrow) {
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    label,
                                    controls,
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  label,
                                  const SizedBox(height: 8),
                                  controls,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Content List or Grid
                          Expanded(
                            child: pagedItems.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No items found",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : (selectedCategory == "Images")
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
                                          final isFolder =
                                              item["is_folder"] ?? false;

                                          if (isFolder) {
                                            // Folder - show as card with folder icon
                                            return GestureDetector(
                                              onTap: () => setState(() =>
                                                  currentFolderId = item["id"]),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.folder,
                                                        color:
                                                            PremiumTheme.purple,
                                                        size: 48),
                                                    const SizedBox(height: 12),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8),
                                                      child: Text(
                                                        item["label"] ??
                                                            item["key"] ??
                                                            "Folder",
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          // File/Image card item
                                          bool isImage =
                                              selectedCategory == "Images";
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
                                                        _deleteItem(context,
                                                            app, item["id"]);
                                                      },
                                                      child:
                                                          const Text("Delete"),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.04),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.08),
                                                ),
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
                                                              const BorderRadius
                                                                  .only(
                                                            topLeft:
                                                                Radius.circular(
                                                                    12),
                                                            topRight:
                                                                Radius.circular(
                                                                    12),
                                                          ),
                                                          child: isImage &&
                                                                  imageUrl !=
                                                                      null
                                                              ? Image.network(
                                                                  imageUrl,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder:
                                                                      (context,
                                                                          error,
                                                                          stackTrace) {
                                                                    return Container(
                                                                      color: Colors
                                                                              .grey[
                                                                          200],
                                                                      child: const Icon(
                                                                          Icons
                                                                              .image_not_supported,
                                                                          color:
                                                                              Colors.grey),
                                                                    );
                                                                  },
                                                                  loadingBuilder:
                                                                      (context,
                                                                          child,
                                                                          loadingProgress) {
                                                                    if (loadingProgress ==
                                                                        null)
                                                                      return child;
                                                                    return Container(
                                                                      color: Colors
                                                                          .white
                                                                          .withValues(
                                                                              alpha: 0.04),
                                                                      child:
                                                                          const Center(
                                                                        child:
                                                                            SizedBox(
                                                                          width:
                                                                              20,
                                                                          height:
                                                                              20,
                                                                          child:
                                                                              CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                )
                                                              : Container(
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                          alpha:
                                                                              0.04),
                                                                  child: Center(
                                                                    child:
                                                                        Column(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        Icon(
                                                                          _getFileIcon(item["label"] ??
                                                                              ""),
                                                                          size:
                                                                              48,
                                                                          color:
                                                                              PremiumTheme.purple,
                                                                        ),
                                                                        const SizedBox(
                                                                            height:
                                                                                8),
                                                                        Text(
                                                                          _getFileExtension(item["label"] ??
                                                                              ""),
                                                                          style:
                                                                              const TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            color:
                                                                                Colors.white70,
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
                                                                  onTap: () =>
                                                                      _showEditDialog(
                                                                          context,
                                                                          app,
                                                                          item),
                                                                  child:
                                                                      Container(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .black
                                                                          .withValues(alpha: 0.4),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              6),
                                                                    ),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            6),
                                                                    child: const Icon(
                                                                        Icons
                                                                            .edit,
                                                                        size:
                                                                            16,
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 8),
                                                                InkWell(
                                                                  onTap: () =>
                                                                      _deleteItem(
                                                                          context,
                                                                          app,
                                                                          item[
                                                                              "id"]),
                                                                  child:
                                                                      Container(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .black
                                                                          .withValues(alpha: 0.4),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              6),
                                                                    ),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            6),
                                                                    child: const Icon(
                                                                        Icons
                                                                            .delete,
                                                                        size:
                                                                            16,
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item["label"] ??
                                                              item["key"] ??
                                                              "",
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF0066CC),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          _formatDate(item[
                                                                  "created_at"] ??
                                                              ""),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey[500],
                                                          ),
                                                        ),
                                                        if (item["tags"]
                                                                is List &&
                                                            (item["tags"]
                                                                    as List)
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 6),
                                                          Wrap(
                                                            spacing: 4,
                                                            runSpacing: 4,
                                                            children: (item[
                                                                        "tags"]
                                                                    as List)
                                                                .take(2)
                                                                .map<Widget>(
                                                                    (tag) =>
                                                                        Container(
                                                                          padding:
                                                                              const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                6,
                                                                            vertical:
                                                                                2,
                                                                          ),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                Colors.blue[50],
                                                                            borderRadius:
                                                                                BorderRadius.circular(
                                                                              4,
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            tag.toString(),
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 10,
                                                                              color: Colors.blue[700],
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
                                    : (selectedCategory == "Template" || selectedCategory == "Templates")
                                        ? ListView.builder(
                                            itemCount: pagedItems.length,
                                            itemBuilder: (ctx, i) {
                                              final item = pagedItems[i];
                                              // Check if item is a full template (has JSON structure with templateType and sections)
                                              final content = (item["content"] ?? "").toString();
                                              final key = (item["key"] ?? "").toString().toLowerCase();
                                              final label = (item["label"] ?? "").toString().toLowerCase();
                                              
                                              // Full template detection: must have JSON structure OR key/label indicating full template
                                              bool isFullTemplate = false;
                                              
                                              // Check for JSON structure in content
                                              try {
                                                if (content.trim().startsWith('{')) {
                                                  final decoded = jsonDecode(content);
                                                  if (decoded is Map && decoded.containsKey('templateType') && decoded.containsKey('sections')) {
                                                    isFullTemplate = true;
                                                  }
                                                }
                                              } catch (e) {
                                                // Not JSON, continue checking
                                              }
                                              
                                              // Also check key/label patterns
                                              if (!isFullTemplate) {
                                                if (key.contains("_template") && (key.contains("proposal") || key.contains("sow") || key.contains("consulting"))) {
                                                  isFullTemplate = true;
                                                } else if (label.contains("template") && (label.contains("proposal") || label.contains("sow") || label.contains("consulting") || label.contains("delivery"))) {
                                                  isFullTemplate = true;
                                                } else if (content.contains('"templateType"') && content.contains('"sections"')) {
                                                  isFullTemplate = true;
                                                }
                                              }
                                              
                                              if (isFullTemplate) {
                                                return _buildTemplateCard(
                                                  context: context,
                                                  app: app,
                                                  item: item,
                                                );
                                              } else {
                                                // Show as template module/block (individual section)
                                                return _buildTextBlockCard(
                                                  context: context,
                                                  app: app,
                                                  item: item,
                                                );
                                              }
                                            },
                                          )
                                        : ListView.builder(
                                            itemCount: pagedItems.length,
                                            itemBuilder: (ctx, i) => _buildTextBlockCard(
                                                  context: context,
                                                  app: app,
                                                  item: pagedItems[i],
                                                ),
                                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.white54),
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
          backgroundColor: PremiumTheme.purple.withValues(alpha: 0.6),
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
        "name": "Consulting & Technology Delivery Proposal Template",
        "description": "Complete proposal template with all 11 sections - Cover Page, Executive Summary, Problem Statement, Scope of Work, Timeline, Team, Delivery Approach, Pricing, Risks, Governance, and Company Profile",
        "templateType": "proposal",
        "sections": [
          "Cover Page",
          "Executive Summary",
          "Problem Statement",
          "Scope of Work",
          "Project Timeline",
          "Team & Bios",
          "Delivery Approach",
          "Pricing Table",
          "Risks & Mitigation",
          "Governance Model",
          "Appendix â€“ Company Profile"
        ],
        "content": jsonEncode({
          "templateType": "proposal",
          "name": "Consulting & Technology Delivery Proposal Template",
          "description": "Complete proposal template with all sections",
          "sections": [
            {
              "title": "Cover Page",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"cover\", \"page\", \"module\"] -->\n<h1>Consulting & Technology Delivery Proposal</h1>\n\n<p><strong>Client:</strong> {{Client Name}}</p>\n<p><strong>Prepared For:</strong> {{Client Stakeholder}}</p>\n<p><strong>Prepared By:</strong> Khonology Team</p>\n<p><strong>Date:</strong> {{Date}}</p>\n\n<h2>Cover Summary</h2>\n<p>Khonology proposes a customised consulting and technology delivery engagement to support {{Client Name}} in achieving operational excellence, digital transformation, and data-driven decision-making.</p>"
            },
            {
              "title": "Executive Summary",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"executive\", \"summary\", \"module\"] -->\n<h1>Executive Summary</h1>\n\n<h2>Purpose of This Proposal</h2>\n<p>This proposal outlines Khonology's recommended approach, delivery methodology, timelines, governance, and expected outcomes for the {{Project Name}} initiative.</p>\n\n<h2>What We Bring</h2>\n<ul>\n<li>Strong expertise in digital transformation and enterprise delivery</li>\n<li>Deep experience in banking, insurance, ESG reporting, and financial services</li>\n<li>Proven capability across data engineering, cloud, automation, and governance</li>\n<li>A people-first consulting culture focused on delivery excellence</li>\n</ul>\n\n<h2>Expected Outcomes</h2>\n<ul>\n<li>Streamlined processes</li>\n<li>Robust governance</li>\n<li>Improved operational visibility</li>\n<li>Higher efficiency and reduced risk</li>\n<li>A scalable delivery architecture to support strategic goals</li>\n</ul>"
            },
            {
              "title": "Problem Statement",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"problem\", \"statement\", \"module\"] -->\n<h1>Problem Statement</h1>\n\n<h2>Current State Challenges</h2>\n<p>{{Client Name}} is experiencing the following challenges:</p>\n<ul>\n<li>Limited visibility into operational performance</li>\n<li>Manual processes creating inefficiencies</li>\n<li>High reporting complexity</li>\n<li>Lack of integrated workflows or automated governance</li>\n<li>Upcoming deadlines causing pressure on compliance and reporting</li>\n</ul>\n\n<h2>Opportunity</h2>\n<p>With a modern delivery framework, workflows, and reporting structures, {{Client Name}} can unlock operational excellence and achieve strategic growth objectives.</p>"
            },
            {
              "title": "Scope of Work",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"scope\", \"work\", \"module\"] -->\n<h1>Scope of Work</h1>\n\n<p>Khonology proposes the following Scope of Work:</p>\n\n<h2>1. Discovery & Assessment</h2>\n<ul>\n<li>Requirements gathering</li>\n<li>Stakeholder workshops</li>\n<li>Current-state assessment</li>\n</ul>\n\n<h2>2. Solution Design</h2>\n<ul>\n<li>Technical architecture</li>\n<li>Workflow design</li>\n<li>Data models and integration approach</li>\n</ul>\n\n<h2>3. Build & Configuration</h2>\n<ul>\n<li>Product configuration</li>\n<li>UI/UX setup</li>\n<li>Data pipeline setup</li>\n<li>Reporting components</li>\n</ul>\n\n<h2>4. Implementation & Testing</h2>\n<ul>\n<li>UAT support</li>\n<li>QA testing</li>\n<li>Release preparation</li>\n</ul>\n\n<h2>5. Training & Knowledge Transfer</h2>\n<ul>\n<li>System training</li>\n<li>Documentation handover</li>\n</ul>"
            },
            {
              "title": "Project Timeline",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"timeline\", \"project\", \"module\"] -->\n<h1>Project Timeline</h1>\n\n<table>\n<thead>\n<tr>\n<th>Phase</th>\n<th>Duration</th>\n<th>Description</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Discovery</td>\n<td>1â€“2 Weeks</td>\n<td>Requirements & assessment</td>\n</tr>\n<tr>\n<td>Design</td>\n<td>1 Week</td>\n<td>Architecture & workflow design</td>\n</tr>\n<tr>\n<td>Build</td>\n<td>2â€“4 Weeks</td>\n<td>Development & configuration</td>\n</tr>\n<tr>\n<td>UAT</td>\n<td>1â€“2 Weeks</td>\n<td>Testing & validation</td>\n</tr>\n<tr>\n<td>Go-Live</td>\n<td>1 Week</td>\n<td>Deployment & full handover</td>\n</tr>\n</tbody>\n</table>"
            },
            {
              "title": "Team & Bios",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"team\", \"bios\", \"module\"] -->\n<h1>Team & Bios</h1>\n\n<h2>Engagement Lead â€“ {{Name}}</h2>\n<p>Responsible for oversight, governance, and stakeholder engagement.</p>\n\n<h2>Technical Lead â€“ {{Name}}</h2>\n<p>Owns architecture, technical design, integration, and delivery.</p>\n\n<h2>Business Analyst â€“ {{Name}}</h2>\n<p>Facilitates workshops, documents requirements, and translations.</p>\n\n<h2>QA/Test Analyst â€“ {{Name}}</h2>\n<p>Ensures solution quality and manages UAT cycles.</p>"
            },
            {
              "title": "Delivery Approach",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"delivery\", \"approach\", \"module\"] -->\n<h1>Delivery Approach</h1>\n\n<p>Khonology follows a structured delivery methodology combining Agile, Lean, and governance best practices.</p>\n\n<h2>Key Features</h2>\n<ul>\n<li>Iterative sprint cycles</li>\n<li>Frequent stakeholder engagement</li>\n<li>Automated governance checkpoints</li>\n<li>Traceability from requirements â†’ delivery â†’ reporting</li>\n</ul>"
            },
            {
              "title": "Pricing Table",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"pricing\", \"table\", \"module\"] -->\n<h1>Pricing Table</h1>\n\n<table>\n<thead>\n<tr>\n<th>Service Component</th>\n<th>Quantity</th>\n<th>Rate</th>\n<th>Total</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Assessment & Discovery</td>\n<td>2 Weeks</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n<tr>\n<td>Build & Configuration</td>\n<td>4 Weeks</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n<tr>\n<td>UAT & Release</td>\n<td>2 Weeks</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n<tr>\n<td>Training & Handover</td>\n<td>1 Week</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n</tbody>\n</table>\n\n<p><strong>Total Estimated Cost:</strong> R {{Total}}</p>\n\n<p>Final costs will be confirmed after detailed scoping.</p>"
            },
            {
              "title": "Risks & Mitigation",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"risks\", \"mitigation\", \"module\"] -->\n<h1>Risks & Mitigation</h1>\n\n<table>\n<thead>\n<tr>\n<th>Risk</th>\n<th>Impact</th>\n<th>Likelihood</th>\n<th>Mitigation</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Limited stakeholder availability</td>\n<td>High</td>\n<td>Medium</td>\n<td>Align early calendars</td>\n</tr>\n<tr>\n<td>Data quality issues</td>\n<td>High</td>\n<td>High</td>\n<td>Early validation</td>\n</tr>\n<tr>\n<td>Changing scope</td>\n<td>Medium</td>\n<td>Medium</td>\n<td>Governance checkpoints</td>\n</tr>\n<tr>\n<td>Lack of documentation</td>\n<td>Medium</td>\n<td>High</td>\n<td>Early analysis and mapping</td>\n</tr>\n</tbody>\n</table>"
            },
            {
              "title": "Governance Model",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"governance\", \"model\", \"module\"] -->\n<h1>Governance Model</h1>\n\n<h2>Governance Structure</h2>\n<ul>\n<li>Engagement Lead</li>\n<li>Product Owner (Client)</li>\n<li>Delivery Team</li>\n<li>QA & Compliance Group</li>\n</ul>\n\n<h2>Tools</h2>\n<ul>\n<li>Jira</li>\n<li>Teams/Email</li>\n<li>Automated reporting dashboard</li>\n</ul>\n\n<h2>Cadence</h2>\n<ul>\n<li>Daily standups</li>\n<li>Weekly status updates</li>\n<li>Monthly executive review</li>\n</ul>"
            },
            {
              "title": "Appendix â€“ Company Profile",
              "required": true,
              "content": "<!-- tags: [\"template\", \"proposal\", \"company\", \"profile\", \"module\"] -->\n<h1>Appendix â€“ Company Profile</h1>\n\n<h2>About Khonology</h2>\n<p>Khonology is a South African-based digital consulting and technology delivery company specialising in:</p>\n<ul>\n<li>Enterprise automation</li>\n<li>Digital transformation</li>\n<li>ESG reporting</li>\n<li>Data engineering & cloud</li>\n<li>Business analysis and enterprise delivery</li>\n</ul>\n\n<p>We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.</p>"
            }
          ]
        })
      },
      {
        "name": "Statement of Work (SOW) Template",
        "description": "Complete SOW template with all sections - Project Overview, Scope, Deliverables, Timeline, Resources, and Terms",
        "templateType": "sow",
        "sections": [
          "Project Overview",
          "Scope of Work",
          "Deliverables",
          "Timeline & Milestones",
          "Resources & Team",
          "Terms & Conditions"
        ],
        "content": jsonEncode({
          "templateType": "sow",
          "name": "Statement of Work (SOW) Template",
          "description": "Complete SOW template with all sections",
          "sections": [
            {
              "title": "Project Overview",
              "required": true,
              "content": "# Project Overview\n\n## Background\n[Project background and context]\n\n## Objectives\n[Key project objectives]\n\n## Success Criteria\n[How success will be measured]"
            },
            {
              "title": "Scope of Work",
              "required": true,
              "content": "# Scope of Work\n\n## In Scope\n[Detailed description of work included]\n\n## Out of Scope\n[Items explicitly excluded]"
            },
            {
              "title": "Deliverables",
              "required": true,
              "content": "# Deliverables\n\n| Deliverable | Description | Due Date | Acceptance Criteria |\n|------------|-------------|----------|---------------------|\n| [Deliverable 1] | [Description] | [Date] | [Criteria] |"
            },
            {
              "title": "Timeline & Milestones",
              "required": true,
              "content": "# Timeline & Milestones\n\n## Project Timeline\n[High-level project timeline]\n\n## Key Milestones\n1. [Milestone 1] - [Date]\n2. [Milestone 2] - [Date]\n3. [Milestone 3] - [Date]"
            },
            {
              "title": "Resources & Team",
              "required": true,
              "content": "# Resources & Team\n\n## Team Structure\n[Team members and roles]\n\n## Responsibilities\n[Responsibilities of each party]"
            },
            {
              "title": "Terms & Conditions",
              "required": true,
              "content": "# Terms & Conditions\n\n## Payment Terms\n[Payment schedule and terms]\n\n## Intellectual Property\n[IP ownership terms]\n\n## Confidentiality\n[Confidentiality requirements]"
            }
          ]
        })
      },
      {
        "name": "Project Proposal Template",
        "description": "Complete project proposal template",
        "templateType": "proposal",
        "sections": [
          "Executive Summary",
          "Company Profile",
          "Scope & Deliverables",
          "Timeline",
          "Investment",
          "Terms & Conditions"
        ],
        "content":
            "PROJECT PROPOSAL\n\nScope:\n[Scope details]\n\nTimeline:\n[Timeline details]\n\nBudget:\n[Budget details]"
      },
      {
        "name": "Executive Summary",
        "description": "Professional executive summary template",
        "templateType": "block",
        "content":
            "[Client Name]\n\nExecutive Summary\n\n[Your summary content here]"
      },
      {
        "name": "Risk Assessment",
        "description": "Risk assessment and mitigation template",
        "templateType": "block",
        "content":
            "RISK ASSESSMENT\n\nIdentified Risks:\n\n1. [Risk 1]\n   Mitigation: [Plan]\n\n2. [Risk 2]\n   Mitigation: [Plan]"
      },
      {
        "name": "Terms & Conditions",
        "description": "Standard terms and conditions template",
        "templateType": "block",
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
                    onTap: () async {
                      final templateName = (template["name"] ?? "").toString();
                      final templateContent = (template["content"] ?? "").toString();
                      final templateType = (template["templateType"] ?? "").toString();
                      // Generate key that ensures template detection (_template suffix)
                      String templateKey = templateName.toLowerCase()
                          .replaceAll(" ", "_")
                          .replaceAll("(", "")
                          .replaceAll(")", "")
                          .replaceAll("&", "and")
                          .replaceAll("-", "_");
                      // Ensure key has _template suffix for detection
                      if (!templateKey.endsWith("_template")) {
                        templateKey = "${templateKey}_template";
                      }
                      
                      // If it's a full template (SOW or Proposal), create it directly
                      if (templateType == "sow" || templateType == "proposal") {
                        Navigator.pop(ctx);
                        try {
                          // Use "Template" category (singular) to match the UI
                          await app.createContent(
                            key: templateKey,
                            label: templateName,
                            content: templateContent,
                            category: "Template", // Use consistent category name
                            parentId: currentFolderId,
                          );
                          // Refresh content to see the new template
                          await app.fetchContent();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("$templateName created successfully"),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to create template: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        // For blocks, show the dialog for editing
                        labelCtrl.text = templateName;
                        contentCtrl.text = templateContent;
                        keyCtrl.text = templateKey;
                        Navigator.pop(ctx);
                        _showScratchTemplateDialog(context, app);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (template["name"] ?? "").toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (template["description"] ?? "").toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
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
                                  : Colors.white70,
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
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54),
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
                          "ðŸ“„ File loaded: $selectedFileName",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Content preview: ${fileContent!.substring(0, fileContent!.length > 100 ? 100 : fileContent!.length)}...",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
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
                      _navigateToPage(context, 'Dashboard');
                    },
                  ),
                  if (!_isAdminUser()) // Only show for non-admin users
                    _buildNavItem(
                      icon: Icons.description_outlined,
                      label: 'My Proposals',
                      isActive: _currentNavIdx == 1,
                      onTap: () {
                        _navigateToPage(context, 'My Proposals');
                      },
                    ),
                  _buildNavItem(
                    icon: Icons.note_outlined,
                    label: 'Templates',
                    isActive: _currentNavIdx == 2,
                    onTap: () {
                      _navigateToPage(context, 'Templates');
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.collections,
                    label: 'Content Library',
                    isActive: _currentNavIdx == 3,
                    onTap: () {
                      // Already on content library
                    },
                  ),
                  if (!_isAdminUser()) // Only show for non-admin users
                    _buildNavItem(
                      icon: Icons.people_outline,
                      label: 'Client Management',
                      isActive: _currentNavIdx == 4,
                      onTap: () {
                        _navigateToPage(context, 'Client Management');
                      },
                    ),
                  _buildNavItem(
                    icon: Icons.check_circle_outline,
                    label: _isAdminUser() ? 'Approved Proposals' : 'Approvals',
                    isActive: _currentNavIdx == 5,
                    onTap: () {
                      _navigateToPage(context, _isAdminUser() ? 'Approved Proposals' : 'Approvals');
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
                color: isActive
                    ? PremiumTheme.purple.withValues(alpha: 0.3)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? PremiumTheme.purple
                      : PremiumTheme.glassWhiteBorder,
                  width: isActive ? 2 : 1,
                ),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? PremiumTheme.purple.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? PremiumTheme.purple
                  : PremiumTheme.glassWhiteBorder.withValues(alpha: 0.7),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? PremiumTheme.purple.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? PremiumTheme.purple
                        : PremiumTheme.glassWhiteBorder,
                    width: isActive ? 2 : 1,
                  ),
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
                    color: isActive ? Colors.white : Colors.white70,
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

  bool _isAdminUser() {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;
      final role = (user['role']?.toString() ?? '').toLowerCase().trim();
      return role == 'admin' || role == 'ceo';
    } catch (e) {
      return false;
    }
  }

  void _navigateToPage(BuildContext context, String label) {
    final isAdmin = _isAdminUser();
    
    switch (label) {
      case 'Dashboard':
        if (isAdmin) {
          Navigator.pushReplacementNamed(context, '/approver_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
        }
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
      case 'Client Management':
        Navigator.pushNamed(context, '/client_management');
        break;
      case 'Approved Proposals':
        Navigator.pushNamed(context, '/approved_proposals');
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
