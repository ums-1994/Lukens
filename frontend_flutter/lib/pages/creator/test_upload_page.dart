import 'package:flutter/material.dart';
import '../../widgets/document_upload_widget.dart';
import '../../services/content_library_service.dart';

class TestUploadPage extends StatefulWidget {
  const TestUploadPage({Key? key}) : super(key: key);

  @override
  State<TestUploadPage> createState() => _TestUploadPageState();
}

class _TestUploadPageState extends State<TestUploadPage> {
  final ContentLibraryService _service = ContentLibraryService();
  List<Map<String, dynamic>> _uploadedDocs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    final docs = await _service.getContentModules(category: 'Documents');
    setState(() {
      _uploadedDocs = docs ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Document Upload'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Upload Widget
            DocumentUploadWidget(
              category: 'Documents',
              onUploadComplete: (result) {
                print('Upload complete: $result');
                _loadDocuments(); // Reload list
              },
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Uploaded Documents List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Uploaded Documents',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDocuments,
                  tooltip: 'Refresh list',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _uploadedDocs.isEmpty
                      ? const Center(
                          child: Text(
                            'No documents uploaded yet.\nUse the upload widget above to add documents.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _uploadedDocs.length,
                          itemBuilder: (context, index) {
                            final doc = _uploadedDocs[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.description,
                                    color: Colors.blue),
                                title: Text(doc['label'] ?? 'Untitled'),
                                subtitle: Text(
                                  'Category: ${doc['category'] ?? 'N/A'}\n'
                                  'ID: ${doc['id']}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Document'),
                                        content: const Text('Are you sure?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      await _service
                                          .deleteContentModule(doc['id']);
                                      _loadDocuments();
                                    }
                                  },
                                ),
                                onTap: () {
                                  // Show document details
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(doc['label'] ?? 'Document'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildDetailRow(
                                                'ID', doc['id'].toString()),
                                            _buildDetailRow(
                                                'Label', doc['label'] ?? 'N/A'),
                                            _buildDetailRow('Category',
                                                doc['category'] ?? 'N/A'),
                                            _buildDetailRow(
                                                'URL', doc['content'] ?? 'N/A'),
                                            _buildDetailRow('Public ID',
                                                doc['public_id'] ?? 'N/A'),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
