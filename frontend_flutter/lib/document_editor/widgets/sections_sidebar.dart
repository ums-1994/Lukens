import 'package:flutter/material.dart';
import '../models/document_section.dart';

/// Sidebar listing all sections in the current document.
///
/// This widget is stateless; selection changes and focus handling are
/// delegated back to the parent via [onSectionTap].
class SectionsSidebar extends StatelessWidget {
  const SectionsSidebar({
    super.key,
    required this.sections,
    required this.selectedSectionIndex,
    required this.onSectionTap,
  });

  final List<DocumentSection> sections;
  final int selectedSectionIndex;
  final ValueChanged<int> onSectionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sections.length} section${sections.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: sections.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final section = sections[index];
                final bool isSelected = selectedSectionIndex == index;

                final String fullText = section.controller.text;
                final String snippet;
                if (fullText.isEmpty) {
                  snippet = 'Empty section';
                } else {
                  final firstLine = fullText.split('\n').first;
                  snippet = firstLine.length > 40
                      ? firstLine.substring(0, 40)
                      : firstLine;
                }

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSectionTap(index),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00BCD4).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF00BCD4),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    section.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF00BCD4)
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Section type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: section.isCoverPage
                                        ? const Color(0xFF00BCD4)
                                            .withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    section.sectionType == 'cover'
                                        ? 'Cover'
                                        : section.sectionType == 'appendix'
                                            ? 'Appendix'
                                            : section.sectionType ==
                                                    'references'
                                                ? 'Refs'
                                                : 'Page',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: section.isCoverPage
                                          ? const Color(0xFF00BCD4)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
