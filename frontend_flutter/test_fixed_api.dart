import 'dart:convert';
import 'dart:io';

void main() async {
  print('🔍 Testing fixed API call...\n');
  
  final url = 'https://lorde01v-v3.hf.space/analyze';
  print('🌐 Testing: $url');
  
  try {
    final uri = Uri.parse(url);
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.write('{"proposal_text": "This is a comprehensive proposal for implementing a new risk management system that includes multiple phases of development, testing, and deployment. The project will span over several months and require significant resources from various departments including IT, finance, and operations."}');
    
    final response = await request.close();
    final statusCode = response.statusCode;
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('✅ Response Status: $statusCode');
    print('📡 Response Body: $responseBody');
    
    if (statusCode == 200) {
      print('🎉 SUCCESS! API is working correctly!');
    } else {
      print('❌ Still getting error');
    }
    
    client.close();
  } catch (e) {
    print('❌ Error: $e');
  }
}
