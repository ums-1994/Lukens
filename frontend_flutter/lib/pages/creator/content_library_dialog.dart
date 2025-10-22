import 'package:flutter/material.dart';
import '../../services/content_library_service.dart';

class ContentLibrarySelectionDialog extends StatefulWidget {
  const ContentLibrarySelectionDialog({super.key});

  @override
  State<ContentLibrarySelectionDialog> createState() => _ContentLibrarySelectionDialogState();
}

class _ContentLibrarySelectionDialogState extends State<ContentLibrarySelectionDialog> {
  final ContentLibraryService _svc = ContentLibraryService();
  List<Map<String, dynamic>> _modules = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final modules = await _svc.getContentModules();
    setState(() {
      _modules = modules;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insert from Content Library'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search library...'),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _modules.where((m) => _search.isEmpty || (m['title'] as String).toLowerCase().contains(_search.toLowerCase())).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final filtered = _modules.where((m) => _search.isEmpty || (m['title'] as String).toLowerCase().contains(_search.toLowerCase())).toList();
                      final m = filtered[index];
                      return ListTile(
                        title: Text(m['title'] ?? ''),
                        subtitle: Text((m['content'] ?? '').toString().substring(0, (m['content'] ?? '').toString().length > 150 ? 150 : (m['content'] ?? '').toString().length)),
                        onTap: () => Navigator.of(context).pop(m),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
