import 'package:flutter/foundation.dart';

class VersionControlConfig {
  static const int _versionYear = 2026;
  static const String _versionMonth = '01';
  static const String _versionWeekCode = 'C';
  static const String _versionDayCode = 'A';
  static const int _versionCommitNumber = 2;
  static const String _versionEnvironment = 'SIT';

  static const String versionLabel =
      'Ver. $_versionYear.$_versionMonth.'
      '$_versionWeekCode$_versionDayCode'
      '$_versionCommitNumber'
      '_$_versionEnvironment';

  // Configuration for showing/hiding overlay based on environment
  static bool get showOverlay {
    // Show in debug mode, hide in release
    return kDebugMode;
  }

  // Allow override via environment variable
  static bool get forceShow {
    const bool fromEnv = bool.fromEnvironment('SHOW_VERSION_OVERLAY', defaultValue: true);
    return fromEnv;
  }

  static bool get shouldShow => showOverlay || forceShow;
}
