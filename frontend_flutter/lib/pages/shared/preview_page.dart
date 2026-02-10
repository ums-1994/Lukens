import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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
    var p = app.currentProposal;
    // Fallback: accept proposal via route arguments if app state not set
    if (p == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        p = args;
        try {
          context.read<AppState>().selectProposal(p);
        } catch (_) {}
      }
    }
    if (p == null) {
      return const Center(child: Text("Select a proposal to preview."));
    }
    final Map<String, dynamic> pm = Map<String, dynamic>.from(p as Map);
    final sections = Map<String, dynamic>.from(pm["sections"] ?? {});
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(pm["title"],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Preview PDF'),
                onPressed: () async {
                  final id = pm['id'] is int
                      ? pm['id'] as int
                      : int.tryParse(pm['id']?.toString() ?? '') ?? 0;
                  if (id == 0) return;

                  final appWrite = context.read<AppState>();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Generating PDF preview...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  final bytes =
                      await appWrite.fetchProposalPdfPreviewBytes(proposalId: id);
                  if (bytes == null) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to load PDF preview'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!kIsWeb) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF preview is currently web-only'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final blob = html.Blob([bytes], 'application/pdf');
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  try {
                    await launchUrlString(url);
                  } finally {
                    html.Url.revokeObjectUrl(url);
                  }
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.draw),
                label: const Text('Send with DocuSign'),
                onPressed: () async {
                  final nameController = TextEditingController(
                      text: pm['client_name']?.toString().isNotEmpty == true
                          ? pm['client_name']
                          : 'Client');
                  final emailController = TextEditingController(
                      text: pm['client_email']?.toString() ?? '');
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Send for Signature'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration:
                                const InputDecoration(labelText: 'Signer Name'),
                          ),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                                labelText: 'Signer Email'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Send')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final id = pm['id'] is int
                      ? pm['id'] as int
                      : int.tryParse(pm['id']?.toString() ?? '') ?? 0;
                  if (id == 0) return;
                  final appWrite = context.read<AppState>();
                  final result = await appWrite.sendProposalForSignature(
                    proposalId: id,
                    signerName: nameController.text.trim(),
                    signerEmail: emailController.text.trim(),
                    returnUrl:
                        'http://localhost:8081/#/proposals/$id?signed=true',
                  );
                  if (result != null && result['signing_url'] != null) {
                    final url = result['signing_url'].toString();
                    await launchUrlString(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Failed to create DocuSign envelope')));
                  }
                },
              ),
            ],
          ),
          Text((pm["dtype"] ?? 'Proposal').toString() +
              (pm["client"] != null ? " for ${pm["client"]}" : "")),
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

