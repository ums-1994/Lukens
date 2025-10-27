# Document Upload Implementation Guide

## Overview
The content library service now supports uploading documents (DOCX, PDF, etc.) to Cloudinary and storing them in the content library.

## What Was Fixed

### 1. API Endpoint Corrections
- **OLD**: `/content-blocks/*` ❌
- **NEW**: `/content/*` ✅

### 2. New Upload Methods
The `ContentLibraryService` now includes:
- `uploadDocument()` - Upload DOCX, PDF, etc.
- `uploadImage()` - Upload images
- `uploadAndCreateContent()` - Upload file + create content block in one operation

### 3. Enhanced Content Management
- Support for categories, folders, and file references
- Proper CRUD operations aligned with backend API
- Cloudinary integration for file storage

## Usage Examples

### Example 1: Simple Upload Button

```dart
import 'package:flutter/material.dart';
import 'widgets/document_upload_widget.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Content Library')),
      body: Center(
        child: DocumentUploadButton(
          buttonText: 'Upload Document',
          category: 'Company Documents',
          onUploadComplete: (result) {
            print('Uploaded: ${result['label']}');
            print('URL: ${result['url']}');
          },
        ),
      ),
    );
  }
}
```

### Example 2: Full Upload Card Widget

```dart
import 'package:flutter/material.dart';
import 'widgets/document_upload_widget.dart';

class ContentLibraryPage extends StatefulWidget {
  @override
  _ContentLibraryPageState createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  List<Map<String, dynamic>> _documents = [];

  void _handleUploadComplete(Map<String, dynamic> result) {
    setState(() {
      _documents.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Content Library')),
      body: Column(
        children: [
          DocumentUploadWidget(
            category: 'Documents',
            onUploadComplete: _handleUploadComplete,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final doc = _documents[index];
                return ListTile(
                  leading: Icon(Icons.description),
                  title: Text(doc['label']),
                  subtitle: Text(doc['url']),
                  trailing: IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () {
                      // Open document URL
                    },
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
```

### Example 3: Custom Upload Implementation

```dart
import 'package:file_picker/file_picker.dart';
import 'services/content_library_service.dart';

class CustomUploadExample {
  final ContentLibraryService _service = ContentLibraryService();

  Future<void> uploadCustomDocument() async {
    // Step 1: Pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true, // Important!
    );

    if (result == null || result.files.first.bytes == null) {
      return;
    }

    final file = result.files.first;

    // Step 2: Upload to Cloudinary and create content block
    final uploadResult = await _service.uploadAndCreateContent(
      fileBytes: file.bytes!,
      fileName: file.name,
      label: 'My Custom Document',
      category: 'Reports',
    );

    if (uploadResult != null && uploadResult['success'] == true) {
      print('✅ Upload successful!');
      print('Content ID: ${uploadResult['content_id']}');
      print('File URL: ${uploadResult['url']}');
      print('Public ID: ${uploadResult['public_id']}');
    } else {
      print('❌ Upload failed');
    }
  }

  // Upload image separately
  Future<void> uploadImageOnly() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.first.bytes == null) {
      return;
    }

    final file = result.files.first;
    final uploadResult = await _service.uploadImage(
      fileBytes: file.bytes!,
      fileName: file.name,
    );

    if (uploadResult != null) {
      print('Image URL: ${uploadResult['url']}');
    }
  }
}
```

### Example 4: Load and Display Documents

```dart
import 'package:flutter/material.dart';
import 'services/content_library_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentListPage extends StatefulWidget {
  @override
  _DocumentListPageState createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  final ContentLibraryService _service = ContentLibraryService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    // Get all content from the "Documents" category
    final docs = await _service.getContentModules(category: 'Documents');

    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Documents'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(child: Text('No documents found'))
              : ListView.builder(
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        leading: Icon(Icons.description, size: 40),
                        title: Text(doc['title'] ?? doc['label']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category: ${doc['category']}'),
                            if (doc['public_id'] != null)
                              Text(
                                'File ID: ${doc['public_id']}',
                                style: TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.open_in_new),
                              onPressed: () => _openDocument(doc['content']),
                              tooltip: 'Open Document',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Delete Document'),
                                    content: Text('Are you sure?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final success = await _service.deleteContentModule(doc['id']);
                                  if (success) {
                                    _loadDocuments();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Document deleted')),
                                    );
                                  }
                                }
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Show upload dialog or navigate to upload page
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Upload Document'),
              content: DocumentUploadWidget(
                category: 'Documents',
                onUploadComplete: (result) {
                  Navigator.pop(context);
                  _loadDocuments();
                },
              ),
            ),
          );
        },
        icon: Icon(Icons.upload_file),
        label: Text('Upload'),
      ),
    );
  }
}
```

## API Reference

### ContentLibraryService Methods

#### `getContentModules({String? category})`
Fetches all content modules, optionally filtered by category.

**Returns**: `Future<List<Map<String, dynamic>>>`

#### `uploadDocument({required Uint8List fileBytes, required String fileName})`
Uploads a document file to Cloudinary.

**Returns**: `Future<Map<String, dynamic>?>` with keys:
- `success`: bool
- `url`: String (Cloudinary URL)
- `public_id`: String (Cloudinary public ID)
- `filename`: String
- `size`: int

#### `uploadAndCreateContent({...})`
Uploads a file and creates a content block in one operation.

**Parameters**:
- `fileBytes`: Uint8List (required)
- `fileName`: String (required)
- `label`: String (required)
- `category`: String (default: 'Documents')
- `parentId`: int? (optional)

**Returns**: `Future<Map<String, dynamic>?>` with keys:
- `success`: bool
- `content_id`: int
- `url`: String
- `public_id`: String
- `label`: String

#### `createContentModule({...})`
Creates a new content block.

#### `updateContentModule({...})`
Updates an existing content block.

#### `deleteContentModule(int contentId)`
Deletes a content block by ID.

## Backend Endpoints Used

- `GET /content?category=<category>` - List content blocks
- `POST /content` - Create content block
- `PUT /content/{id}` - Update content block
- `DELETE /content/{id}` - Delete content block
- `POST /upload/template` - Upload document to Cloudinary
- `POST /upload/image` - Upload image to Cloudinary

## Environment Configuration

Make sure your `.env` file has Cloudinary credentials:

```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

## Troubleshooting

### Upload fails with 500 error
- Check backend logs
- Verify Cloudinary credentials in `.env`
- Ensure file size is within limits

### "Could not read file" error
- Make sure `withData: true` is set in FilePicker
- Check file permissions

### Document not appearing in list
- Verify the category name matches
- Check backend database for the content block
- Refresh the list after upload

## Next Steps

1. ✅ Service layer updated with upload support
2. ✅ Example widgets created
3. 🔄 Integrate upload widgets into your existing pages
4. 🔄 Add file preview/download functionality
5. 🔄 Add progress indicators for large files
6. 🔄 Add file type validation and size limits