# 🔌 Port Configuration Guide

## Port Allocation

Your application uses multiple ports for different services:

```
Port 8000  → Python Backend (Flask API)
Port 8080  → PostgreSQL/Database Interface
Port 8081  → Flutter Frontend (Web App)
Port 5432  → PostgreSQL Database
```

---

## ⚠️ Important: Frontend Port

**The collaboration invitation emails link to port 8081**, not 8080, because:
- Port 8080 is used by the PostgreSQL/EDB Postgres interface
- Port 8081 is for the Flutter web application

---

## 🚀 Running the Frontend on Port 8081

### Option 1: Command Line Flag
```bash
cd frontend_flutter
flutter run -d chrome --web-port=8081
```

### Option 2: Using Chrome with Port
```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081
```

### Option 3: Web Server (for deployment)
```bash
cd frontend_flutter
flutter build web
cd build/web
python -m http.server 8081
```

---

## 🔧 Backend Configuration

Update your `backend/.env` file:

```env
# Frontend URL (for email links)
FRONTEND_URL=http://localhost:8081
```

**Important:** Do NOT use port 8080 for `FRONTEND_URL` as that's the database port!

---

## ✅ Verification

### 1. Check Backend is Running
```bash
curl http://localhost:8000/health
```
Should return: `{"status": "ok", ...}`

### 2. Check Frontend is Running
Open browser to: `http://localhost:8081`
Should show: Flutter login/landing page

### 3. Check Database is Accessible
Open browser to: `http://localhost:8080`
Should show: EDB Postgres interface

### 4. Test Collaboration Link
Click a collaboration email link.
Should open: `http://localhost:8081/#/collaborate?token=...`
Should show: Guest collaboration page (not database)

---

## 🐛 Troubleshooting

### "Port 8081 already in use"
```bash
# Find what's using port 8081
netstat -ano | findstr :8081

# Kill the process (Windows)
taskkill /PID <process_id> /F

# Or use a different port
flutter run -d chrome --web-port 8082
# Then update FRONTEND_URL=http://localhost:8082
```

### "Collaboration link shows database page"
❌ Problem: Email links go to `http://localhost:8080`
✅ Solution: 
1. Update `FRONTEND_URL` in `.env` to `http://localhost:8081`
2. Restart backend: `python app.py`
3. Send new invitation

### "Frontend won't start"
```bash
# Clear Flutter cache
flutter clean

# Get dependencies
flutter pub get

# Run with specific port
flutter run -d chrome --web-port 8081
```

---

## 📝 Complete Startup Sequence

### Step 1: Start Database (if not already running)
```bash
# PostgreSQL should already be running on port 5432
# EDB Postgres interface runs on port 8080
```

### Step 2: Start Backend
```bash
cd backend
python app.py
# Should start on http://localhost:8000
```

### Step 3: Start Frontend
```bash
cd frontend_flutter
flutter run -d chrome --web-port 8081
# Should open browser to http://localhost:8081
```

### Step 4: Verify All Services
- Backend API: http://localhost:8000/health
- Frontend App: http://localhost:8081
- Database UI: http://localhost:8080 (optional)

---

## 🔄 Port Conflicts Reference

If you encounter port conflicts:

| Service | Default Port | Alternative |
|---------|--------------|-------------|
| Backend | 8000 | 8001, 5000 |
| Frontend | 8081 | 8082, 8083 |
| PostgreSQL | 5432 | 5433 |
| DB Interface | 8080 | (depends on your setup) |

**When changing ports:**
1. Update `FRONTEND_URL` in `backend/.env`
2. Update any hardcoded URLs in frontend
3. Restart all services
4. Test collaboration links

---

## 🎯 Production Configuration

For production deployment:

```env
# Production .env
FRONTEND_URL=https://yourdomain.com
```

The port configuration only matters for local development.

---

## 📋 Quick Reference

**Start Backend:**
```bash
cd backend && python app.py
```

**Start Frontend (Correct Port):**
```bash
cd frontend_flutter && flutter run -d chrome --web-port 8081
```

**Check Services:**
```bash
# Backend
curl http://localhost:8000/health

# Frontend (in browser)
open http://localhost:8081
```

---

## ✨ Summary

✅ **Port 8000** - Backend API  
✅ **Port 8081** - Flutter Frontend ← **Use this for collaboration!**  
✅ **Port 8080** - Database Interface (don't use for frontend)  

**Always use port 8081 for the Flutter app to avoid conflicts with the database interface!**

---

**Updated:** October 27, 2025  
**Issue Fixed:** Collaboration links now correctly point to port 8081

