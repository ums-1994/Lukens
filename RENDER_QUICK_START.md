# 🚀 Render Deployment - Quick Start

## Prerequisites
- Git repository with your code
- Render account (free tier works)
- All API keys ready

## Quick Deploy (5 Steps)

### 1. Create PostgreSQL Database
- Render Dashboard → **New +** → **PostgreSQL**
- Name: `lukens-db`
- Click **Create Database**
- **Save connection details**

### 2. Deploy Backend
- Render Dashboard → **New +** → **Web Service**
- Connect your Git repo
- Settings:
  - **Name**: `lukens-backend`
  - **Root Directory**: `backend`
  - **Build Command**: `pip install -r requirements.txt`
  - **Start Command**: `cd backend && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app`
- **Environment Tab** → Add all variables from `.env.example`
- Click **Create Web Service**
- **Copy the URL** (e.g., `https://lukens-backend.onrender.com`)

### 3. Deploy Frontend
- Render Dashboard → **New +** → **Static Site**
- Connect your Git repo
- Settings:
  - **Name**: `lukens-frontend`
  - **Root Directory**: `frontend_flutter`
  - **Build Command**: `flutter pub get && flutter build web --release --base-href /`
  - **Publish Directory**: `build/web`
- **Environment Tab** → Add:
  - `REACT_APP_API_URL` = your backend URL from step 2
- Click **Create Static Site**

### 4. Update Backend CORS
- Go to backend service → **Environment**
- Add/Update: `FRONTEND_URL` = your frontend URL
- Save (auto-redeploys)

### 5. Initialize Database
- Backend will auto-initialize on first request
- Or check logs to verify schema creation

## ✅ Done!

Your app is live:
- Frontend: `https://lukens-frontend.onrender.com`
- Backend: `https://lukens-backend.onrender.com`

## 🔧 Required Environment Variables

See `.env.example` for full list. Minimum required:

**Backend:**
- Database credentials (from Render PostgreSQL)
- `PYTHON_VERSION=3.11.0`
- `FRONTEND_URL` (your frontend URL)

**Frontend:**
- `REACT_APP_API_URL` (your backend URL)

## 📚 Full Documentation

See `docs/guides/RENDER_DEPLOYMENT.md` for detailed instructions.

## 🐛 Common Issues

**Backend won't start:**
- Check all environment variables are set
- Verify database connection
- Check build logs for errors

**Frontend can't connect to backend:**
- Verify `REACT_APP_API_URL` is correct
- Check CORS settings in backend
- Ensure `FRONTEND_URL` is set in backend

**Database errors:**
- Verify database credentials
- Check database is running
- Ensure schema initialized

## 💡 Pro Tips

1. **Use Blueprints**: Import `render.yaml` for automatic setup
2. **Monitor Logs**: Check Render dashboard for real-time logs
3. **Auto-Deploy**: Push to Git = automatic deployment
4. **Free Tier**: Services sleep after 15min inactivity (wake on request)










