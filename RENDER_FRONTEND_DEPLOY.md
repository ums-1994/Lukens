# 🚀 Deploy Frontend to Render (Static Site)

## ✅ Yes, Use "Static Site"

For Flutter web apps, use Render's **Static Site** service.

## 📋 Step-by-Step Deployment

### Step 1: Create Static Site
1. Go to Render Dashboard
2. Click **"New +"** → **"Static Site"**
3. Connect your Git repository (same repo as backend)

### Step 2: Configure Settings

**Basic Settings:**
- **Name**: `lukens-frontend` (or any name you prefer)
- **Branch**: `Cleaned_Code` (or your default branch)
- **Root Directory**: `frontend_flutter`

**Build Settings:**
- **Build Command**: 
  ```bash
  flutter pub get && flutter build web --release --base-href /
  ```
- **Publish Directory**: `build/web`

### Step 3: Add Environment Variable

Go to **Environment** tab and add:

```env
REACT_APP_API_URL=https://lukens-wp8w.onrender.com
```

**Important**: Replace `lukens-wp8w.onrender.com` with your actual backend URL from Render.

### Step 4: Deploy
1. Click **"Create Static Site"**
2. Wait for build to complete (may take 5-10 minutes first time)
3. You'll get a URL like: `https://lukens-frontend.onrender.com`

## ⚠️ Important Notes

### Flutter SDK on Render
Render's static site builder may not have Flutter SDK installed by default. If build fails:

**Option 1: Use Build Command with Flutter Installation**
```bash
# Install Flutter if not available
if ! command -v flutter &> /dev/null; then
  git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter
  export PATH="$PATH:/tmp/flutter/bin"
fi
flutter config --enable-web
flutter pub get
flutter build web --release --base-href /
```

**Option 2: Pre-build Locally and Commit**
1. Build locally: `flutter build web --release --base-href /`
2. Commit the `build/web` folder
3. Use build command: `echo "Using pre-built files"`
4. Publish directory: `build/web`

### API URL Configuration
After deployment, make sure:
1. Frontend environment variable `REACT_APP_API_URL` points to your backend
2. Backend environment variable `FRONTEND_URL` points to your frontend URL
3. Update CORS in backend to allow frontend domain

## 📋 Complete Settings Summary

```
Name: lukens-frontend
Type: Static Site
Branch: Cleaned_Code
Root Directory: frontend_flutter
Build Command: flutter pub get && flutter build web --release --base-href /
Publish Directory: build/web

Environment Variable:
REACT_APP_API_URL=https://lukens-wp8w.onrender.com
```

## ✅ After Deployment

1. **Test the frontend URL** - Should load your Flutter app
2. **Test API connection** - Check browser console for API calls
3. **Update backend CORS** - Add frontend URL to backend's `FRONTEND_URL` env var

## 🐛 Troubleshooting

**"Flutter command not found"**
- Use the build command with Flutter installation (Option 1 above)
- Or pre-build locally and commit (Option 2 above)

**"Build failed"**
- Check Flutter version compatibility
- Ensure `pubspec.yaml` has all dependencies
- Check build logs for specific errors

**"API calls failing"**
- Verify `REACT_APP_API_URL` is set correctly
- Check backend CORS settings
- Ensure backend is running and accessible

## 🎯 Quick Checklist

- [ ] Created Static Site service
- [ ] Set Root Directory to `frontend_flutter`
- [ ] Set Build Command
- [ ] Set Publish Directory to `build/web`
- [ ] Added `REACT_APP_API_URL` environment variable
- [ ] Updated backend `FRONTEND_URL` to point to frontend
- [ ] Tested frontend loads correctly
- [ ] Tested API connection works






