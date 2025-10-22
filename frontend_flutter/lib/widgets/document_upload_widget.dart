import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/content_library_service.dart';

/// Example widget demonstrating how to upload documents to the content library
class DocumentUploadWidget extends StatefulWidget {
  final String? category;
  final Function(Map<String, dynamic>)? onUploadComplete;

  const DocumentUploadWidget({
    Key? key,
    this.category,
    this.onUploadComplete,
  }) : super(key: key);

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  final ContentLibraryService _service = ContentLibraryService();
  bool _isUploading = false;
  String? _uploadStatus;

  Future<void> _pickAndUploadDocument() async {
    try {
      // Pick a file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'],
        withData: true, // Important: loads file bytes
      );

      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() {
          _uploadStatus = 'Error: Could not read file';
        });
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Uploading ${file.name}...';
      });

      // Upload the document and create content block
      final uploadResult = await _service.uploadAndCreateContent(
        fileBytes: file.bytes!,
        fileName: file.name,
        label: file.name,
        category: widget.category ?? 'Documents',
      );

      if (uploadResult != null && uploadResult['success'] == true) {
        setState(() {
          _uploadStatus = 'Upload successful: ${file.name}';
          _isUploading = false;
        });

        // Notify parent widget
        if (widget.onUploadComplete != null) {
          widget.onUploadComplete!(uploadResult);
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name} uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _uploadStatus = 'Upload failed';
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _uploadStatus = 'Error: $e';
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Upload Document',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_uploadStatus != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _uploadStatus!,
                  style: TextStyle(
                    color: _uploadStatus!.contains('Error') ||
                            _uploadStatus!.contains('failed')
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ),
            if (_isUploading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              ElevatedButton.icon(
                onPressed: _pickAndUploadDocument,
                icon: const Icon(Icons.file_upload),
                label: const Text('Choose File to Upload'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Supported formats: PDF, DOC, DOCX, TXT, XLSX, PPTX',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple button widget for uploading documents
class DocumentUploadButton extends StatefulWidget {
  final String buttonText;
  final String? category;
  final Function(Map<String, dynamic>)? onUploadComplete;
  final IconData icon;

  const DocumentUploadButton({
    Key? key,
    this.buttonText = 'Upload Document',
    this.category,
    this.onUploadComplete,
    this.icon = Icons.upload_file,
  }) : super(key: key);

  @override
  State<DocumentUploadButton> createState() => _DocumentUploadButtonState();
}

class _DocumentUploadButtonState extends State<DocumentUploadButton> {
  final ContentLibraryService _service = ContentLibraryService();
  bool _isUploading = false;

  Future<void> _uploadDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'],
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.bytes == null) {
        return;
      }

      setState(() => _isUploading = true);

      final file = result.files.first;
      final uploadResult = await _service.uploadAndCreateContent(
        fileBytes: file.bytes!,
        fileName: file.name,
        label: file.name,
        category: widget.category ?? 'Documents',
      );

      setState(() => _isUploading = false);

      if (uploadResult != null && uploadResult['success'] == true) {
        if (widget.onUploadComplete != null) {
          widget.onUploadComplete!(uploadResult);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name} uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isUploading
        ? const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _uploadDocument,
            icon: Icon(widget.icon),
            label: Text(widget.buttonText),
          );
  }
}
