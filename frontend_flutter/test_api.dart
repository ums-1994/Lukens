import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print('🔍 Testing Risk Gate API URL loading...\n');
  
  try {
    // Try to load .env from current directory
    await dotenv.load(fileName: '.env');
    print('✅ .env file loaded successfully');
    
    final riskGateUrl = dotenv.env['Risk_Gate_engine_API'];
    final hfUrl = dotenv.env['HUGGINGFACE_API_URL'];
    
    print('📋 Environment variables found:');
    print('   Risk_Gate_engine_API: $riskGateUrl');
    print('   HUGGINGFACE_API_URL: $hfUrl');
    
    final baseUrl = riskGateUrl ?? hfUrl ?? 'https://lorde01v-v3.hf.space/analyze';
    print('\n🎯 Final Risk Gate API URL: $baseUrl');
    
    // Test if the URL is reachable
    print('\n🌐 Testing API connectivity...');
    final uri = Uri.parse(baseUrl);
    final request = await HttpClient().getUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    
    try {
      final response = await request.close();
      print('✅ API Response Status: ${response.statusCode}');
      print('✅ API is reachable!');
    } catch (e) {
      print('❌ API Connection Error: $e');
    }
    
  } catch (e) {
    print('❌ Could not load .env file: $e');
    print('🔍 Using default Hugging Face URL: https://lorde01v-v3.hf.space/analyze');
  }
}
