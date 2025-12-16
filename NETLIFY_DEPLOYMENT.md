# 🚀 Deploy Flutter Frontend to Netlify

Netlify is **much better** for Flutter web apps than Render! It can build Flutter automatically.

## ✅ Advantages of Netlify

- ✅ **Automatic Flutter builds** - No need to pre-build locally
- ✅ **Better Flutter support** - Built-in Flutter SDK
- ✅ **Faster deployments** - Optimized for static sites
- ✅ **Free tier** - Generous free plan
- ✅ **Easy setup** - Connect GitHub and deploy

## 📋 Step-by-Step Deployment

### Step 1: Create Netlify Account

1. Go to [netlify.com](https://netlify.com)
2. Sign up with GitHub (easiest way)
3. Authorize Netlify to access your repositories

### Step 2: Deploy from GitHub

1. **In Netlify Dashboard:**
   - Click **"Add new site"** → **"Import an existing project"**
   - Select **"Deploy with GitHub"**
   - Authorize if needed
   - Select repository: `ums-1994/Lukens`
   - Select branch: `Cleaned_Code`

2. **Configure Build Settings:**
   - **Base directory**: `frontend_flutter` (or leave empty if using `cd frontend_flutter` in command)
   - **Build command**: 
     ```bash
     flutter pub get && flutter build web --release --base-href /
     ```
   - **Publish directory**: `build/web`

3. **Environment Variables:**
   - Click **"Show advanced"** → **"New variable"**
   - Add: `REACT_APP_API_URL` = `https://lukens-wp8w.onrender.com`
   - (Replace with your actual backend URL)

4. **Click "Deploy site"**

### Step 3: Wait for Build

- First build: 5-10 minutes (installs Flutter SDK)
- Subsequent builds: 2-5 minutes
- Netlify will show build progress in real-time

### Step 4: Get Your URL

After deployment, Netlify will give you a URL like:
- `https://lukens-xyz123.netlify.app`
- Or you can set a custom domain

## 🔧 Alternative: Using netlify.toml (Recommended)

I've created `netlify.toml` in your repo. If you use this:

1. **Push the file to GitHub:**
   ```bash
   git add netlify.toml
   git commit -m "Add Netlify configuration"
   git push origin Cleaned_Code
   ```

2. **In Netlify:**
   - Connect your repo
   - Netlify will **automatically detect** `netlify.toml`
   - Build settings will be auto-configured!
   - Just add environment variables

## 📝 Environment Variables in Netlify

**Go to**: Site settings → Environment variables → Add variable

**Required:**
- `REACT_APP_API_URL` = `https://lukens-wp8w.onrender.com`

**Optional:**
- `FLUTTER_VERSION` = `stable` (if you want specific version)

## 🔄 Continuous Deployment

Netlify automatically deploys when you push to `Cleaned_Code` branch!

- Push to GitHub → Netlify builds → Deploys automatically
- Preview deployments for pull requests
- Rollback to previous deployments easily

## 🔗 Connect Frontend to Backend

After frontend is deployed:

1. **Update Backend CORS:**
   - Go to Render backend → Environment
   - Add/Update: `FRONTEND_URL` = your Netlify URL
   - Save (auto-redeploys)

2. **Update Frontend API URL:**
   - Go to Netlify → Site settings → Environment variables
   - Update `REACT_APP_API_URL` if needed
   - Trigger a new deploy

## 🎯 Quick Setup Summary

1. ✅ Sign up at netlify.com
2. ✅ Connect GitHub repo `ums-1994/Lukens`
3. ✅ Select branch `Cleaned_Code`
4. ✅ Build command: `cd frontend_flutter && flutter pub get && flutter build web --release --base-href /`
5. ✅ Publish directory: `frontend_flutter/build/web`
6. ✅ Add env var: `REACT_APP_API_URL` = your backend URL
7. ✅ Deploy!

## 🆚 Netlify vs Render for Frontend

| Feature | Netlify | Render |
|---------|---------|--------|
| Flutter Support | ✅ Built-in | ❌ Manual setup |
| Build Time | ⚡ Fast | 🐌 Slow (downloads Flutter) |
| Free Tier | ✅ Generous | ✅ Good |
| Auto Deploy | ✅ Yes | ✅ Yes |
| Preview Deploys | ✅ Yes | ❌ No |
| Custom Domain | ✅ Free SSL | ✅ Free SSL |

## ✅ Recommended: Use Netlify!

Netlify is the better choice for Flutter web apps. Much simpler setup!









