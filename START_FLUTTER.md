# 🚀 Start Flutter Frontend on Port 8081

## Quick Start

### Option 1: Command Line (Recommended)
```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081
```

### Option 2: VS Code
1. Open `frontend_flutter` folder
2. Press `F5` or click Run → Start Debugging
3. Select "Chrome"
4. Wait for it to open browser

### Option 3: If Flutter isn't on port 8081
```bash
cd frontend_flutter

# Clean first
flutter clean
flutter pub get

# Then run
flutter run -d chrome --web-port 8081
```

---

## ✅ What Should Happen

1. Terminal shows:
   ```
   Launching lib/main.dart on Chrome in debug mode...
   Building application for the web...
   ```

2. Browser opens automatically to: `http://localhost:8081`

3. You see the login/landing page

4. **Now** click the collaboration link again!

---

## 🐛 If Port 8081 is Busy

```bash
# Find what's using it
netstat -ano | findstr :8081

# Kill it (replace PID)
taskkill /PID <process_id> /F

# Then start Flutter
flutter run -d chrome --web-port 8081
```

---

## 📋 Final Setup

You should have **TWO terminals running**:

**Terminal 1: Backend**
```bash
cd backend
python app.py
# Running on http://localhost:8000
```

**Terminal 2: Frontend**
```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081
# Running on http://localhost:8081
```

---

## ✨ Test Collaboration

Once Flutter is running:
1. Click the collaboration email link again
2. Should open to: `http://localhost:8081/#/collaborate?token=...`
3. Should show: Guest collaboration page with proposal!

---

**The link is correct now, you just need to start the Flutter app!** 🎉

