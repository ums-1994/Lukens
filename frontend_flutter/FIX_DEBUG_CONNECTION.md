# Fix Flutter Web Debug Connection Error

## Problem
```
Failed to establish connection with the application instance in Chrome.
This can happen if the websocket connection used by the web tooling is unable to correctly establish a connection
```

## Quick Fixes (Try in Order)

### Solution 1: Use Release Mode (Recommended)
Run Flutter in release mode instead of debug mode - this avoids the debug service entirely:

```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081 --release
```

### Solution 2: Disable Debug Service
Run without the debug service:

```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081 --no-web-resources-cdn
```

### Solution 3: Use Different Port
Sometimes port 8081 has issues, try a different port:

```bash
cd frontend_flutter
flutter run -d chrome --web-port 8082
```

Then update `backend/.env`:
```
FRONTEND_URL=http://localhost:8082
```

### Solution 4: Clean and Rebuild
```bash
cd frontend_flutter
flutter clean
flutter pub get
flutter run -d chrome --web-port 8081
```

### Solution 5: Check Windows Firewall
The WebSocket connection might be blocked by Windows Firewall:

1. Open Windows Defender Firewall
2. Allow Flutter/Dart through firewall
3. Or temporarily disable firewall to test

### Solution 6: Use Profile Mode
Profile mode is between debug and release:

```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081 --profile
```

## Best Solution for Development

For development, use **release mode** - it's faster and avoids debug connection issues:

```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081 --release
```

You'll still see console logs, but hot reload won't work. For hot reload, use Solution 2 or 6.

