import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Risk Gate HF Space base URL (no `/analyze` or `/analyze-proposal` suffix).
/// Set `RISK_GATE_HF_BASE_URL` in backend `.env`, or pass
/// `--dart-define=RISK_GATE_HF_BASE_URL=https://your-space.hf.space` for web builds.
Future<String> resolveRiskGateHfBaseUrl() async {
  const compiled =
      String.fromEnvironment('RISK_GATE_HF_BASE_URL', defaultValue: '');
  var base = compiled.trim();
  if (base.isNotEmpty) {
    return _stripTrailingSlash(_stripRiskPaths(base));
  }
  for (final path in ['../backend/.env', '.env']) {
    try {
      await dotenv.load(fileName: path);
      base = (dotenv.env['RISK_GATE_HF_BASE_URL'] ??
              dotenv.env['Risk_Gate_engine_API'] ??
              '')
          .trim();
      if (base.isNotEmpty) {
        break;
      }
    } catch (_) {}
  }
  base = _stripTrailingSlash(_stripRiskPaths(base));
  return base;
}

String _stripRiskPaths(String s) {
  var t = s.trim();
  for (final suffix in ['/analyze-proposal', '/analyze']) {
    if (t.endsWith(suffix)) {
      t = t.substring(0, t.length - suffix.length).trim();
      break;
    }
  }
  return t;
}

String _stripTrailingSlash(String s) => s.replaceAll(RegExp(r'/+$'), '');
