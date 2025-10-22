# Server Startup & PostgreSQL Fix Guide

## Problems Fixed

### 1. ❌ ASGI/WSGI Compatibility Error
**Error**: `TypeError: Flask.__call__() missing 1 required positional argument: 'start_response'`

**Root Cause**: Uvicorn (ASGI server) wasn't properly using the WsgiToAsgi wrapper for Flask (WSGI framework).

**Solution**: Created a dedicated ASGI module (`asgi.py`) that properly wraps and exports the Flask app.

### 2. ❌ PostgreSQL Tables Not Initializing
**Root Cause**: The `init_pg_schema()` function was defined but never called on app startup.

**Solution**: Added database initialization in `@app.before_request` decorator to ensure schema is created on first request.

## Changes Made

### File: `backend/asgi.py` (NEW)
Created a proper ASGI entry point that:
- Handles module imports correctly
- Wraps Flask with WsgiToAsgi adapter
- Sets up the working directory

### File: `backend/app.py`
**Enhanced**:
1. Added robust error handling for PostgreSQL connection pool
2. Improved database initialization with better logging
3. Added health check endpoints (`/health` and `/api/init`)
4. Better error messages to help diagnose issues

### File: `start_python_backend.py`
**Updated**: Changed Uvicorn entry point from `app:asgi_app` to `asgi:app`

## How to Start the Server

### Option 1: Using the startup script (Recommended)
```bash
python start_python_backend.py
```

### Option 2: Direct Uvicorn command
```bash
cd backend
python -m uvicorn asgi:app --host 127.0.0.1 --port 8000 --reload
```

## Testing

### 1. Check PostgreSQL Connection
```bash
python backend/test_db_connection.py
```
✅ **Result**: PostgreSQL connected with 33+ tables initialized

### 2. Check Server Health
```bash
# After server starts
curl http://localhost:8000/health
```
Expected response:
```json
{"status": "ok", "db_initialized": true}
```

### 3. Initialize Database Manually
```bash
curl http://localhost:8000/api/init
```

## PostgreSQL Status
- ✅ Connection: Working
- ✅ Database: `proposal_sow_builder` exists
- ✅ User: `postgres` authenticated
- ✅ Tables: 33 tables already created

## Common Issues & Solutions

### Issue: Port 8000 already in use
**Solution**: Kill the previous process or use a different port
```bash
netstat -ano | findstr :8000  # Find process
taskkill /PID <PID> /F        # Kill it
```

### Issue: "ModuleNotFoundError" for app
**Solution**: Make sure you're running from the correct directory or use the startup script.

### Issue: CORS errors from frontend
**Solution**: Ensure `CORS_ORIGIN` in `.env` matches your frontend URL (currently `http://localhost:8080`)

### Issue: Login endpoint not found
**Note**: The `/login-email` endpoint is not yet implemented in app.py. Frontend may need to be updated to use implemented endpoints like `/register`.

## Database Schema
The following tables are created and managed:
- `users` - User accounts
- `proposals` - Proposal documents
- `content` - Content library items
- `settings` - Application settings
- `proposal_versions` - Version history
- `verify_tokens` - Email verification
- `document_comments` - Proposal comments

## Next Steps

1. **Kill previous server process** (if running on port 8000)
2. **Start new server** with: `python start_python_backend.py`
3. **Verify health**: `curl http://localhost:8000/health`
4. **Check logs** for "✅ Database schema initialized successfully"
5. **Test frontend** login/authentication

## Server Logs
When you start the server, you should see:
```
✅ PostgreSQL connection pool created successfully
🔄 Initializing PostgreSQL schema...
✅ Database schema initialized successfully
```

## Debugging

### Enable verbose logging
The app now prints:
- ✅ Success messages (green)
- ❌ Error messages (red)
- 🔄 Progress messages (blue)
- 🔍 Info messages (magnifying glass)

### Check for errors
Look for these patterns in console output:
- `❌ Error` - Something failed
- `⚠️ Warning` - Something to be aware of
- `✅ Success` - Good sign

## Additional Resources
- PostgreSQL connection details in `.env`
- Flask-CORS configuration
- Uvicorn async/ASGI support documentation