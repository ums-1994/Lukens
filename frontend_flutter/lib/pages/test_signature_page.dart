import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../services/api_service.dart';

class TestSignaturePage extends StatefulWidget {
  const TestSignaturePage({super.key});

  @override
  State<TestSignaturePage> createState() => _TestSignaturePageState();
}

class _TestSignaturePageState extends State<TestSignaturePage> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool isSigning = false;

  Future<void> _testSignature() async {
    setState(() {
      isSigning = true;
    });

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes != null) {
        // Test with a dummy token
        final success =
            await ApiService.uploadSignature('test-token', signatureBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Signature uploaded successfully!'
                : 'Failed to upload signature'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSigning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Signature Pad'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Test Signature Pad',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _signatureController.clear();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: isSigning ? null : _testSignature,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: isSigning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Test Upload'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Instructions:\n1. Draw your signature above\n2. Click "Test Upload" to test the API\n3. Check the console for results',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }
}
