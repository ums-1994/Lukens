import 'dart:convert';
import 'dart:io';

void main() async {
  print('🔍 Testing Risk Gate API URL loading...\n');
  
  try {
    // Look for .env file in backend directory
    final envFile = File('../backend/.env');
    if (await envFile.exists()) {
      print('✅ .env file found in backend directory');
      final contents = await envFile.readAsString();
      print('📋 Looking for Risk_Gate_engine_API in .env file...');
      
      // Look for Risk_Gate_engine_API
      final lines = contents.split('\n');
      String? riskGateUrl;
      
      for (final line in lines) {
        if (line.startsWith('Risk_Gate_engine_API=')) {
          riskGateUrl = line.split('=')[1];
          break;
        }
      }
      
      if (riskGateUrl != null) {
        print('\n🎯 Found Risk_Gate_engine_API: $riskGateUrl');
        
        // Test if the URL is reachable
        print('\n🌐 Testing API connectivity...');
        try {
          final uri = Uri.parse(riskGateUrl);
          final client = HttpClient();
          final request = await client.postUrl(uri);
          request.headers.set('Content-Type', 'application/json');
          request.write('{"text": "test proposal text"}');
          final response = await request.close();
          print('✅ API Response Status: ${response.statusCode}');
          
          // Read response body
          final responseBody = await response.transform(utf8.decoder).join();
          print('📡 Response Body: $responseBody');
          
          client.close();
        } catch (e) {
          print('❌ API Connection Error: $e');
        }
      } else {
        print('\n❌ Risk_Gate_engine_API not found in .env file');
        print('🔍 Using default: https://lorde01v-v3.hf.space/analyze');
        
        // Test default URL
        await testDefaultUrl();
      }
    } else {
      print('❌ .env file not found in backend directory');
      print('🔍 Using default: https://lorde01v-v3.hf.space/analyze');
      
      // Test default URL
      await testDefaultUrl();
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> testDefaultUrl() async {
  print('\n🌐 Testing default Hugging Face URL...');
  try {
    final uri = Uri.parse('https://lorde01v-v3.hf.space/analyze');
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.write('{"text": "test proposal text"}');
    final response = await request.close();
    print('✅ API Response Status: ${response.statusCode}');
    
    // Read response body
    final responseBody = await response.transform(utf8.decoder).join();
    print('📡 Response Body: $responseBody');
    
    client.close();
  } catch (e) {
    print('❌ Default API Connection Error: $e');
  }
}
