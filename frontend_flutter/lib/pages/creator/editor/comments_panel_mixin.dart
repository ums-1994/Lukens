part of '../blank_document_editor_page.dart';

/// Mixin for the comments panel UI and behavior.
///
/// It is constrained to `_BlankDocumentEditorPageState` so it can access
/// the state's fields and methods like `_sections`, `_highlightedText`,
/// `_commentController`, `_comments`, `setState`, `context`,
/// `_addComment`, `_getFilteredComments`, `_formatTimestamp`,
/// `_updateCommentStatus`, and `_deleteComment`.
mixin _CommentsPanelMixin on _BlankDocumentEditorPageState {
  void _showCommentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 500,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.comment,
                          color: Color(0xFF00BCD4), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Add Comment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_sections.isNotEmpty) ...[
                    Text(
                      'Target Section',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSectionForComment ?? 0,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: _sections.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(
                            entry.value.titleController.text.isNotEmpty
                                ? entry.value.titleController.text
                                : 'Untitled Section',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSectionForComment = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_highlightedText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFF00BCD4).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Highlighted Text:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _highlightedText.length > 100
                                ? '${_highlightedText.substring(0, 100)}...'
                                : _highlightedText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Comment',
                      hintText: 'Enter your comment here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _commentController.clear();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _addComment();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                        ),
                        child: const Text('Add Comment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCommentsPanel() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.comment,
                          color: Color(0xFF00BCD4), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _commentFilterStatus,
                        items: ['all', 'open', 'resolved'].map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _commentFilterStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.comment_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add comments to collaborate with your team',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _getFilteredComments().length,
                          itemBuilder: (context, index) {
                            final comment = _getFilteredComments()[index];
                            return _buildCommentCard(comment);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final isResolved = comment['status'] == 'resolved';
    final hasHighlightedText = comment['highlighted_text'] != null &&
        comment['highlighted_text'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isResolved ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isResolved
              ? Colors.grey[300]!
              : const Color(0xFF00BCD4).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF00BCD4),
                child: Text(
                  comment['commenter_name']
                          ?.toString()
                          .substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['commenter_name'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      _formatTimestamp(comment['timestamp']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isResolved ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isResolved ? 'RESOLVED' : 'OPEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isResolved ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (comment['section_title'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Section: ${comment['section_title']}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF00BCD4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (hasHighlightedText) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                comment['highlighted_text'],
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            comment['comment_text'] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isResolved)
                TextButton.icon(
                  onPressed: () =>
                      _updateCommentStatus(comment['id'], 'resolved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Resolve'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green[700],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _updateCommentStatus(comment['id'], 'open'),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reopen'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteComment(comment['id']),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}