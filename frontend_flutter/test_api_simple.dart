import 'dart:convert';
import 'dart:io';

Future<void> testUrl(String analyzeUrl) async {
  print('\n🌐 Testing Risk Gate URL...');
  try {
    final uri = Uri.parse(analyzeUrl);
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.write('{"text": "test proposal text"}');
    final response = await request.close();
    print('✅ API Response Status: ${response.statusCode}');
    final responseBody = await response.transform(utf8.decoder).join();
    print('📡 Response Body: $responseBody');
    client.close();
  } catch (e) {
    print('❌ API Connection Error: $e');
  }
}

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
        final t = line.trim();
        if (t.startsWith('Risk_Gate_engine_API=')) {
          riskGateUrl = line.split('=').skip(1).join('=');
          break;
        } else if (t.startsWith('RISK_GATE_HF_BASE_URL=')) {
          var b = line.split('=').skip(1).join('=').trim();
          if (!b.endsWith('/analyze')) {
            b = b.endsWith('/') ? '${b}analyze' : '$b/analyze';
          }
          riskGateUrl = b;
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
        print('\n❌ Risk_Gate_engine_API / RISK_GATE_HF_BASE_URL not found in .env');
        final fromShell =
            const String.fromEnvironment('RISK_GATE_HF_BASE_URL', defaultValue: '');
        var b = fromShell.trim();
        if (b.isEmpty) {
          b = (Platform.environment['RISK_GATE_HF_BASE_URL'] ?? '').trim();
        }
        if (b.isEmpty) {
          print('Set RISK_GATE_HF_BASE_URL in .env or environment.');
          return;
        }
        await testUrl('$b/analyze');
      }
    } else {
      print('❌ .env file not found in backend directory');
      final fromShell =
          const String.fromEnvironment('RISK_GATE_HF_BASE_URL', defaultValue: '');
      var b = fromShell.trim();
      if (b.isEmpty) {
        b = (Platform.environment['RISK_GATE_HF_BASE_URL'] ?? '').trim();
      }
      if (b.isEmpty) {
        print('Set RISK_GATE_HF_BASE_URL or add backend/.env');
        return;
      }
      await testUrl('$b/analyze');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
