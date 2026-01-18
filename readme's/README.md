# Widgets Library

This directory contains reusable widgets for the Flutter application.

## Version Control Overlay

### Files
- `version_control_overlay.dart` - The actual overlay widget
- `version_control_config.dart` - Configuration for showing/hiding the overlay
- `app_wrapper.dart` - Global wrapper that adds the overlay to all screens
- `scaffold_wrapper.dart` - Convenience wrapper for Scaffold with overlay

### Usage

#### Global Application (Recommended)
The `AppWrapper` is already integrated in `main.dart` and will show the version overlay on all screens based on the configuration.

```dart
// In main.dart - already implemented
MaterialApp(
  builder: (context, child) {
    return AppWrapper(
      child: YourWidget(),
    );
  },
)
```

#### Individual Screens
For individual screens or to override the global setting:

```dart
import 'package:your_app/widgets/app_wrapper.dart';

AppWrapper(
  showVersionOverlay: true, // or false to override
  child: YourScreen(),
)
```

#### With Scaffold
Use the `ScaffoldWrapper` for convenience:

```dart
import 'package:your_app/widgets/scaffold_wrapper.dart';

ScaffoldWrapper(
  showVersionOverlay: true,
  appBar: AppBar(title: Text('My Page')),
  body: YourContent(),
)
```

### Configuration

The overlay visibility is controlled by `VersionControlConfig`:

- **Debug Mode**: Shows by default
- **Release Mode**: Hides by default
- **Environment Override**: Set `SHOW_VERSION_OVERLAY=true` to force show

```dart
// Check current configuration
bool willShow = VersionControlConfig.shouldShow;
String version = VersionControlConfig.versionLabel;
```

### Version Information

Current version: `Ver. 2026.01.BE1_SIT`

- Year: 2026
- Month: 01
- Week Code: B
- Day Code: E
- Commit Number: 1
- Environment: SIT (System Integration Testing)

### Customization

To update version information, modify the constants in `version_control_overlay.dart`:

```dart
static const int _versionYear = 2026;
static const String _versionMonth = '01';
static const String _versionWeekCode = 'B';
static const String _versionDayCode = 'E';
static const int _versionCommitNumber = 1;
static const String _versionEnvironment = 'SIT';
```
