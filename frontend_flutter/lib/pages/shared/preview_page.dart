import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key});

  // Helper function to check if a string is likely an image URL
  bool _isImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lowerUrl = url.toLowerCase();
    return lowerUrl.startsWith('http://') ||
        lowerUrl.startsWith('https://') ||
        lowerUrl.contains('.cloudinary.com');
  }

  // Helper function to render content (text or image)
  Widget _renderContent(dynamic value) {
    final stringValue = value?.toString() ?? "";

    if (_isImageUrl(stringValue)) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 400),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            stringValue,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_not_supported, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      "Failed to load image",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stringValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          ),
        ),
      );
    }

    return Text(stringValue);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(child: Text("Select a proposal to preview."));
    }
    final sections = Map<String, dynamic>.from(p["sections"] ?? {});
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(p["title"],
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("${p["dtype"]} for ${p["client"]}"),
          const Divider(),
          // Export PDF & Request e-sign buttons handled here
          const SizedBox(height: 8),
          ...sections.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _renderContent(e.value),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
