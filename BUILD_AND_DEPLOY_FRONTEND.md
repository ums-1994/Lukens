# 🚀 Build and Deploy Flutter Frontend to Render

## Step 1: Update .gitignore

I've already updated `.gitignore` to allow `frontend_flutter/build/web/` to be committed.

## Step 2: Build Flutter Web Locally

Run this command:

```bash
cd frontend_flutter
flutter build web --release --base-href /
```

This will create `frontend_flutter/build/web/` folder.

## Step 3: Add and Commit Build Folder

After build completes:

```bash
# Go back to root
cd ..

# Add the build folder
git add frontend_flutter/build/web

# Commit
git commit -m "Add built Flutter web for Render deployment"

# Push
git push origin Cleaned_Code
```

## Step 4: Configure Render Static Site

### Settings:
- **Name**: `lukens-frontend`
- **Repository**: `https://github.com/ums-1994/Lukens`
- **Branch**: `Cleaned_Code`
- **Root Directory**: Leave empty
- **Build Command**: `echo "Using pre-built files"`
- **Publish Directory**: `frontend_flutter/build/web`

### Environment Variable:
- **Key**: `REACT_APP_API_URL`
- **Value**: `https://lukens-wp8w.onrender.com` (your backend URL)

## ✅ That's it!

After pushing, Render will automatically deploy your frontend.







