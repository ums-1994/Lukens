# 🎯 Netlify Setup - Simple Steps

## ✅ What I've Created

1. **`netlify.toml`** - Configuration file (auto-detected by Netlify)
2. **`NETLIFY_DEPLOYMENT.md`** - Full deployment guide
3. **`NETLIFY_QUICK_START.md`** - Quick 5-minute setup

## 🚀 Quick Deploy (5 Steps)

### 1. Push netlify.toml to GitHub

```bash
git add netlify.toml
git commit -m "Add Netlify configuration"
git push origin Cleaned_Code
```

### 2. Sign Up at Netlify

- Go to [netlify.com](https://netlify.com)
- Sign up with GitHub

### 3. Deploy Site

- Click **"Add new site"** → **"Import an existing project"**
- Select **"Deploy with GitHub"**
- Choose repo: `ums-1994/Lukens`
- Select branch: `Cleaned_Code`

### 4. Netlify Auto-Detects Config

- Netlify will automatically read `netlify.toml`
- Build settings are pre-configured!
- Just add environment variable

### 5. Add Environment Variable

- Click **"Show advanced"** → **"New variable"**
- **Key**: `REACT_APP_API_URL`
- **Value**: `https://lukens-wp8w.onrender.com`
- Click **"Deploy site"**

## ✅ That's It!

Netlify will:
- ✅ Install Flutter SDK automatically
- ✅ Build your app
- ✅ Deploy it
- ✅ Give you a URL

## 🔗 Connect to Backend

After deployment:

1. Copy your Netlify URL (e.g., `https://lukens-xyz123.netlify.app`)
2. Go to Render backend → Environment
3. Add: `FRONTEND_URL` = your Netlify URL
4. Save

## 🎉 Done!

Your frontend is live on Netlify!





