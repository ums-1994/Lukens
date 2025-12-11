# 📋 Step-by-Step: Deploy Flutter Frontend to Render

## ✅ Step 1: Update .gitignore (Already Done)

I've updated `.gitignore` to allow `frontend_flutter/build/web/` to be committed.

## ✅ Step 2: Build Flutter Web Locally

**Run this in your terminal:**

```bash
cd frontend_flutter
flutter build web --release --base-href /
```

**Wait for build to complete** (may take 2-5 minutes)

**Verify build succeeded:**
- Check that `frontend_flutter/build/web/` folder exists
- Should contain `index.html`, `main.dart.js`, etc.

## ✅ Step 3: Add Build Folder to Git

**After build completes, run:**

```bash
# Go back to project root
cd ..

# Add the build folder
git add frontend_flutter/build/web

# Check what will be committed
git status

# Commit
git commit -m "Add built Flutter web for Render deployment"

# Push to GitHub
git push origin Cleaned_Code
```

## ✅ Step 4: Configure Render Static Site

### In Render Dashboard:

1. **Go to**: New + → Static Site
2. **Connect Repository**: `https://github.com/ums-1994/Lukens`
3. **Select Branch**: `Cleaned_Code`
4. **Settings**:
   - **Name**: `lukens-frontend`
   - **Root Directory**: Leave **empty**
   - **Build Command**: `echo "Using pre-built files"`
   - **Publish Directory**: `frontend_flutter/build/web`
5. **Environment Tab**:
   - Add: `REACT_APP_API_URL` = `https://lukens-wp8w.onrender.com`
   - (Replace with your actual backend URL)
6. **Click**: Create Static Site

## ✅ Step 5: Update Backend CORS

After frontend is deployed:

1. **Go to backend service** in Render
2. **Environment tab**
3. **Add/Update**: `FRONTEND_URL` = your frontend URL (e.g., `https://lukens-frontend.onrender.com`)
4. **Save** (auto-redeploys)

## 🎯 Quick Command Summary

```bash
# Build
cd frontend_flutter
flutter build web --release --base-href /

# Commit and push
cd ..
git add frontend_flutter/build/web
git commit -m "Add built Flutter web for Render deployment"
git push origin Cleaned_Code
```

Then configure Render as shown above!







