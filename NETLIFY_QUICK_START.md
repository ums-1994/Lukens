# ⚡ Netlify Quick Start - 5 Minutes

## 🚀 Deploy Your Flutter Frontend to Netlify

### Step 1: Sign Up & Connect (2 min)

1. Go to [netlify.com](https://netlify.com)
2. Click **"Sign up"** → **"GitHub"**
3. Authorize Netlify

### Step 2: Deploy Site (2 min)

1. Click **"Add new site"** → **"Import an existing project"**
2. Select **"Deploy with GitHub"**
3. Choose repo: `ums-1994/Lukens`
4. Select branch: `Cleaned_Code`

### Step 3: Configure Build (1 min)

**If using `netlify.toml` (recommended):**
- Netlify auto-detects it!
- Just add environment variable below

**If configuring manually:**
- **Base directory**: `frontend_flutter`
- **Build command**: `flutter pub get && flutter build web --release --base-href /`
- **Publish directory**: `build/web`

### Step 4: Add Environment Variable

1. Click **"Show advanced"** → **"New variable"**
2. **Key**: `REACT_APP_API_URL`
3. **Value**: `https://lukens-wp8w.onrender.com` (your backend URL)
4. Click **"Deploy site"**

## ✅ Done!

Netlify will:
- Install Flutter SDK automatically
- Build your app
- Deploy it
- Give you a URL like `https://lukens-xyz123.netlify.app`

## 🔗 Connect to Backend

After deployment:

1. **Copy your Netlify URL**
2. **Go to Render backend** → Environment
3. **Add**: `FRONTEND_URL` = your Netlify URL
4. **Save** (auto-redeploys)

## 🎉 That's it!

Your frontend is now live on Netlify and connected to your Render backend!









