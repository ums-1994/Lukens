import 'package:flutter/material.dart';
import 'lib/services/auto_draft_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debug Auto-Save',
      home: DebugAutoSavePage(),
    );
  }
}

class DebugAutoSavePage extends StatefulWidget {
  @override
  _DebugAutoSavePageState createState() => _DebugAutoSavePageState();
}

class _DebugAutoSavePageState extends State<DebugAutoSavePage> {
  final AutoDraftService _autoDraftService = AutoDraftService();
  final String _testProposalId = 'd50a6cdb-1f10-424c-ae7f-408fb611315e';
  int _changeCounter = 0;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeAutoSave();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message);
  }

  void _initializeAutoSave() {
    _addLog('Initializing auto-save...');
    final testData = {
      'sections': {
        'executive_summary':
            'Initial test content for auto-save functionality.',
        'scope': 'Initial scope content',
        'timeline': 'Initial timeline content',
      },
      'documentName': 'Test Proposal',
      'companyName': 'Test Company',
      'selectedClient': 'Test Client',
      'selectedSnapshots': ['executive_summary', 'scope'],
    };

    _autoDraftService.startAutoDraft(_testProposalId, testData);
    _addLog('Auto-save initialized with proposal ID: $_testProposalId');
  }

  void _simulateDataChange() {
    _changeCounter++;
    _addLog('Simulating data change #$_changeCounter');

    final newData = {
      'sections': {
        'executive_summary':
            'UPDATED test proposal content #$_changeCounter - ${DateTime.now()}',
        'scope': 'UPDATED test scope content #$_changeCounter',
        'timeline': 'UPDATED test timeline content #$_changeCounter',
      },
      'documentName': 'Test Proposal',
      'companyName': 'Test Company',
      'selectedClient': 'Test Client',
      'selectedSnapshots': ['executive_summary', 'scope'],
    };

    _autoDraftService.markChanged(newData);
    _addLog('Data marked as changed - should trigger auto-save in 2 seconds');
  }

  void _forceSave() {
    _addLog('Force saving...');
    _autoDraftService.forceSave().then((success) {
      _addLog('Force save result: $success');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Auto-Save'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto-Save Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _autoDraftService.isAutoSaving
                    ? Colors.orange.withOpacity(0.1)
                    : _autoDraftService.hasUnsavedChanges
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _autoDraftService.isAutoSaving
                      ? Colors.orange
                      : _autoDraftService.hasUnsavedChanges
                          ? Colors.red
                          : Colors.green,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _autoDraftService.isAutoSaving
                            ? Icons.sync
                            : _autoDraftService.hasUnsavedChanges
                                ? Icons.warning
                                : Icons.check_circle,
                        color: _autoDraftService.isAutoSaving
                            ? Colors.orange
                            : _autoDraftService.hasUnsavedChanges
                                ? Colors.red
                                : Colors.green,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _autoDraftService.getStatusMessage(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _autoDraftService.isAutoSaving
                              ? Colors.orange
                              : _autoDraftService.hasUnsavedChanges
                                  ? Colors.red
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                      'Has Unsaved Changes: ${_autoDraftService.hasUnsavedChanges}'),
                  Text('Is Auto-Saving: ${_autoDraftService.isAutoSaving}'),
                  if (_autoDraftService.lastError != null)
                    Text('Last Error: ${_autoDraftService.lastError}',
                        style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Actions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _simulateDataChange,
                  child: Text('Simulate Change #$_changeCounter'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _forceSave,
                  child: Text('Force Save'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Debug Logs:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoDraftService.stopAutoDraft();
    super.dispose();
  }
}
