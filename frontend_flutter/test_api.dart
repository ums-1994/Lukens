import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _kRiskBase = String.fromEnvironment(
  'RISK_GATE_HF_BASE_URL',
  defaultValue: '',
);

void main() async {
  print('🔍 Testing Risk Gate API URL loading...\n');
  
  try {
    // Try to load .env from current directory
    await dotenv.load(fileName: '.env');
    print('✅ .env file loaded successfully');
    
    final riskGateUrl = dotenv.env['Risk_Gate_engine_API'];
    final hfUrl = dotenv.env['HUGGINGFACE_API_URL'];
    final r2 = dotenv.env['RISK_GATE_HF_BASE_URL'];
    
    print('📋 Environment variables found:');
    print('   Risk_Gate_engine_API: $riskGateUrl');
    print('   RISK_GATE_HF_BASE_URL: $r2');
    print('   HUGGINGFACE_API_URL: $hfUrl');
    
    var baseUrl = (_kRiskBase.isNotEmpty
            ? _kRiskBase
            : (r2 ?? riskGateUrl ?? hfUrl ?? ''))
        .trim();
    if (baseUrl.isEmpty) {
      baseUrl = (Platform.environment['RISK_GATE_HF_BASE_URL'] ?? '').trim();
    }
    if (!baseUrl.endsWith('/analyze')) {
      baseUrl = baseUrl.endsWith('/') ? '${baseUrl}analyze' : '$baseUrl/analyze';
    }
    if (baseUrl.isEmpty || baseUrl == '/analyze') {
      print('\n❌ Set RISK_GATE_HF_BASE_URL or Risk_Gate_engine_API in .env');
      return;
    }
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
    print('Set RISK_GATE_HF_BASE_URL or create .env with Risk_Gate_engine_API');
  }
}
