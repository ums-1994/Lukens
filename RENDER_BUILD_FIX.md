# 🔧 Fix Render Build Error

## ❌ Current Error:
```
ERROR: Could not open requirements file: [Errno 2] No such file or directory: 'requirements.txt'
```

## 🔍 Problem:
Render is looking for `requirements.txt` in the root directory, but it's in the `backend/` folder.

## ✅ Solution Options:

### Option 1: Set Root Directory (Recommended)

In your Render backend service settings:

1. **Root Directory**: Set to `backend`
2. **Build Command**: `pip install -r requirements.txt`
3. **Start Command**: `gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app`

### Option 2: Update Build Command (If Root Directory is NOT set)

If you can't set Root Directory, update the build command:

1. **Root Directory**: Leave empty (or set to project root)
2. **Build Command**: `cd backend && pip install -r requirements.txt`
3. **Start Command**: `cd backend && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app`

## 🎯 Recommended Settings:

### Backend Service Configuration:

```
Name: lukens-backend
Environment: Python 3
Root Directory: backend
Build Command: pip install -r requirements.txt
Start Command: gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app
```

## 📋 Step-by-Step Fix:

1. Go to your Render dashboard
2. Click on your backend service (`lukens-backend`)
3. Go to **Settings** tab
4. Scroll to **Build & Deploy** section
5. Set **Root Directory** to: `backend`
6. Verify **Build Command** is: `pip install -r requirements.txt`
7. Verify **Start Command** is: `gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app`
8. Click **Save Changes**
9. Render will automatically redeploy

## ✅ After Fix:

You should see in the build logs:
```
==> Running build command 'pip install -r requirements.txt'...
Collecting Flask==2.3.3
Collecting psycopg2-binary==2.9.9
...
Successfully installed ...
```

## 🐛 If Still Having Issues:

1. **Check file exists**: Verify `backend/requirements.txt` exists in your repo
2. **Check branch**: Make sure you're deploying from the correct branch (`Cleaned_Code`)
3. **Check path**: If Root Directory is `backend`, build command should be `pip install -r requirements.txt` (not `backend/requirements.txt`)

## 📝 Quick Reference:

**If Root Directory = `backend`:**
- Build: `pip install -r requirements.txt`
- Start: `gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app`

**If Root Directory = empty/root:**
- Build: `cd backend && pip install -r requirements.txt`
- Start: `cd backend && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app`











