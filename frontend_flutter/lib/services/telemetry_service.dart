// Lightweight telemetry helper used for dashboard interaction events.
class TelemetryService {
  /// Track a simple event with optional metadata.
  /// Currently logs to console; can be extended to POST to a telemetry endpoint.
  static void trackEvent(String eventName, [Map<String, dynamic>? props]) {
    try {
      final meta = props == null ? '' : ' ${props.toString()}';
      // ignore: avoid_print
      print('📣 Telemetry: $eventName$meta');
    } catch (_) {}
  }
}
