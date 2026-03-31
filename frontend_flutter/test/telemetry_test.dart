import 'package:flutter_test/flutter_test.dart';
import 'package:lukens/services/telemetry_service.dart';

void main() {
  test('TelemetryService.trackEvent does not throw', () {
    expect(() => TelemetryService.trackEvent('unit_test_event', {'foo': 'bar'}), returnsNormally);
  });
}
