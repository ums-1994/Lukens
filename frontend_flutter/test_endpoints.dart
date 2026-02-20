import 'dart:convert';
import 'dart:io';

void main() async {
  print('🔍 Testing different Hugging Face endpoints...\n');
  
  final baseUrl = 'https://lorde01v-v3.hf.space';
  final endpoints = [
    '/analyze',
    '/api/analyze',
    '/predict',
    '/api/predict',
    '/risk-gate/analyze',
    '/api/risk-gate/analyze',
    '',  // Root endpoint
  ];
  
  for (final endpoint in endpoints) {
    final url = baseUrl + endpoint;
    print('\n🌐 Testing: $url');
    
    try {
      // Test GET first
      await testMethod('GET', url);
      
      // Test POST
      await testMethod('POST', url);
      
    } catch (e) {
      print('❌ Error: $e');
    }
    
    print('---');
  }
}

Future<void> testMethod(String method, String url) async {
  try {
    final uri = Uri.parse(url);
    final client = HttpClient();
    
    HttpClientRequest request;
    if (method == 'GET') {
      request = await client.getUrl(uri);
    } else {
      request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write('{"text": "test proposal text"}');
    }
    
    final response = await request.close();
    final statusCode = response.statusCode;
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('  $method: $statusCode - $responseBody');
    
    client.close();
  } catch (e) {
    print('  $method: Error - $e');
  }
}
