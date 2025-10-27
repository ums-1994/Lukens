# Testing Document Upload Feature

## Quick Test Checklist

### 1. Backend Verification

First, verify your backend is running and endpoints are accessible:

```powershell
# Test backend is running
curl http://localhost:8000

# Test content endpoint
curl http://localhost:8000/content

# Test upload endpoint exists (should return 422 without file)
curl -X POST http://localhost:8000/upload/template
```

### 2. Flutter Integration Test

Add this test page to your Flutter app to verify the upload functionality:

**Create file: `lib/pages/test_upload_page.dart`**

```dart
import 'package:flutter/material.dart';
import '../widgets/document_upload_widget.dart';
import '../services/content_library_service.dart';

class TestUploadPage extends StatefulWidget {
  @override
  _TestUploadPageState createState() => _TestUploadPageState();
}

class _TestUploadPageState extends State<TestUploadPage> {
  final ContentLibraryService _service = ContentLibraryService();
  List<Map<String, dynamic>> _documents = [];
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _status = 'Loading documents...');
    final docs = await _service.getContentModules();
    setState(() {
      _documents = docs;
      _status = 'Loaded ${docs.length} documents';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Document Upload'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text(_status)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Upload Widget
            DocumentUploadWidget(
              category: 'Test Documents',
              onUploadComplete: (result) {
                setState(() => _status = 'Upload complete: ${result['label']}');
                _loadDocuments();
              },
            ),
            SizedBox(height: 16),

            // Upload Button
            DocumentUploadButton(
              buttonText: 'Quick Upload',
              category: 'Test Documents',
              onUploadComplete: (result) {
                setState(() => _status = 'Quick upload complete!');
                _loadDocuments();
              },
            ),
            SizedBox(height: 24),

            // Document List
            Text(
              'Uploaded Documents',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (_documents.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('No documents yet. Upload one above!'),
                  ),
                ),
              )
            else
              ..._documents.map((doc) => Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(_getIconForDocument(doc)),
                      title: Text(doc['label'] ?? doc['title'] ?? 'Untitled'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category: ${doc['category']}'),
                          if (doc['content'] != null && doc['content'].isNotEmpty)
                            Text(
                              'URL: ${doc['content'].substring(0, doc['content'].length > 50 ? 50 : doc['content'].length)}...',
                              style: TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final success = await _service.deleteContentModule(doc['id']);
                          if (success) {
                            setState(() => _status = 'Deleted: ${doc['label']}');
                            _loadDocuments();
                          }
                        },
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  IconData _getIconForDocument(Map<String, dynamic> doc) {
    final label = (doc['label'] ?? '').toLowerCase();
    if (label.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (label.endsWith('.docx') || label.endsWith('.doc')) return Icons.description;
    if (label.endsWith('.xlsx') || label.endsWith('.xls')) return Icons.table_chart;
    if (label.endsWith('.pptx') || label.endsWith('.ppt')) return Icons.slideshow;
    return Icons.insert_drive_file;
  }
}
```

### 3. Add Test Route

In your `main.dart` or routing file, add:

```dart
import 'pages/test_upload_page.dart';

// Add to your routes or navigation
MaterialPageRoute(builder: (context) => TestUploadPage())
```

### 4. Manual Testing Steps

1. **Start Backend**
   ```powershell
   Set-Location "c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend"
   python app.py
   ```

2. **Start Flutter App**
   ```powershell
   Set-Location "c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\frontend_flutter"
   flutter run -d chrome
   ```

3. **Navigate to Test Page**
   - Open the test upload page in your app
   - You should see the upload widget

4. **Test Upload**
   - Click "Choose File to Upload"
   - Select a document (DOCX, PDF, etc.)
   - Watch for success message
   - Verify document appears in the list below

5. **Test Load**
   - Click refresh button
   - Verify documents load from backend
   - Check that document details are correct

6. **Test Delete**
   - Click delete icon on a document
   - Verify it's removed from the list

### 5. Expected Results

#### ✅ Successful Upload Response
```json
{
  "success": true,
  "content_id": 123,
  "url": "https://res.cloudinary.com/...",
  "public_id": "proposal_builder/templates/...",
  "label": "Company_background.docx"
}
```

#### ✅ Successful List Response
```json
[
  {
    "id": 123,
    "key": "1234567890_Company_background.docx",
    "title": "Company_background.docx",
    "label": "Company_background.docx",
    "content": "https://res.cloudinary.com/...",
    "category": "Documents",
    "is_folder": false,
    "parent_id": null,
    "public_id": "proposal_builder/templates/...",
    "created_at": "2025-01-19T12:34:56",
    "updated_at": "2025-01-19T12:34:56"
  }
]
```

### 6. Common Issues and Solutions

#### Issue: "Error 404: Not Found"
**Solution**: Verify backend is running and endpoints are correct:
- Backend should be at `http://localhost:8000`
- Check `content_library_service.dart` has correct `baseUrl`

#### Issue: "Upload failed with status: 500"
**Solution**: Check backend logs for errors:
- Verify Cloudinary credentials in `.env`
- Check file permissions
- Ensure temp directory is writable

#### Issue: "Could not read file"
**Solution**: 
- Ensure `withData: true` in FilePicker
- For web, this is required to load file bytes

#### Issue: File uploads but doesn't appear in list
**Solution**:
- Check category filter
- Verify content block was created (check database)
- Try refreshing the list

#### Issue: CORS errors in browser console
**Solution**: Backend already has CORS enabled, but verify:
```python
# In backend/app.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 7. Database Verification

Check if documents are stored correctly:

```sql
-- Connect to PostgreSQL
psql -U postgres -d proposal_sow_builder

-- Check content blocks table
SELECT id, key, label, category, public_id, created_at 
FROM content_blocks 
ORDER BY created_at DESC 
LIMIT 10;

-- Check for uploaded documents
SELECT * FROM content_blocks WHERE public_id IS NOT NULL;
```

### 8. Cloudinary Verification

1. Log in to your Cloudinary dashboard
2. Go to Media Library
3. Look for folder: `proposal_builder/templates`
4. Verify your uploaded documents appear there

### 9. Network Testing

Use browser DevTools to monitor network requests:

1. Open DevTools (F12)
2. Go to Network tab
3. Upload a file
4. Look for these requests:
   - `POST /upload/template` (should return 200)
   - `POST /content` (should return 200)
   - `GET /content` (should return 200 with updated list)

### 10. Success Criteria

- ✅ Can select and upload DOCX, PDF, and other document files
- ✅ Upload shows progress/loading indicator
- ✅ Success message displayed after upload
- ✅ Document appears in content library list
- ✅ Can view/download uploaded documents
- ✅ Can delete documents from library
- ✅ Cloudinary URL is accessible and file can be downloaded

## Next Steps After Testing

If all tests pass:
1. Integrate upload widgets into your actual content library pages
2. Add file preview functionality
3. Add search and filter for documents
4. Implement folder organization
5. Add file size limits and validation
6. Add user permissions for upload/delete

If tests fail:
1. Check backend logs for errors
2. Verify Cloudinary credentials
3. Check database connection
4. Review console errors in Flutter DevTools
5. Verify network connectivity between Flutter and backend