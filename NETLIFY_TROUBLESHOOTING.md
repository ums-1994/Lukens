# 🔧 Netlify Deployment Troubleshooting

## ❌ Problem: Changes Not Appearing on Netlify

If you've pushed changes but they're not showing up on Netlify, follow these steps:

## ✅ Step-by-Step Troubleshooting

### 1. Verify Changes Are Pushed to GitHub

**Check if your changes are actually on GitHub:**

```bash
# Check your current branch
git branch --show-current

# Check recent commits
git log --oneline -5

# Verify you're on the correct branch (should be Cleaned_Code)
# If not, switch to it:
git checkout Cleaned_Code

# Check if you have uncommitted changes
git status

# If you have uncommitted changes, commit and push:
git add .
git commit -m "Your commit message"
git push origin Cleaned_Code
```

**Verify on GitHub:**
- Go to your GitHub repo: `https://github.com/ums-1994/Lukens`
- Check the `Cleaned_Code` branch
- Verify your latest changes are there
- Check the commit timestamp matches when you pushed

### 2. Check Netlify Branch Configuration

**In Netlify Dashboard:**
1. Go to your site → **Site settings** → **Build & deploy** → **Continuous Deployment**
2. Verify **Production branch** is set to `Cleaned_Code`
3. If it's wrong, change it and trigger a new deploy

### 3. Check Netlify Build Logs

**In Netlify Dashboard:**
1. Go to **Deploys** tab
2. Click on the latest deploy
3. Check the **Build log** for:
   - ✅ Build success messages
   - ❌ Any error messages
   - ⚠️ Warnings that might indicate issues

**Common Build Issues:**
- Build failing silently
- Flutter SDK not found
- Dependencies not installing
- Build command errors

### 4. Verify Build Settings

**In Netlify Dashboard:**
1. Go to **Site settings** → **Build & deploy** → **Build settings**
2. Verify these settings match:

   **Base directory:** `frontend_flutter`
   
   **Build command:** 
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter && export PATH="$PATH:/tmp/flutter/bin" && flutter config --enable-web && flutter pub get && flutter build web --release --base-href /
   ```
   
   **Publish directory:** `build/web` (relative to base directory)

### 5. Clear Build Cache and Redeploy

**In Netlify Dashboard:**
1. Go to **Deploys** tab
2. Click **Trigger deploy** → **Clear cache and deploy site**
3. Wait for build to complete (5-10 minutes)

### 6. Check Browser Cache

**Your browser might be caching the old version:**
- **Hard refresh:** `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
- **Clear cache:** Open DevTools (F12) → Right-click refresh button → "Empty Cache and Hard Reload"
- **Incognito/Private mode:** Test in a new incognito window
- **Different browser:** Test in a different browser

### 7. Verify netlify.toml is Correct

**Check your `netlify.toml` file:**
- Should be in the **root** of your repository
- Should have correct `base` directory: `frontend_flutter`
- Should have correct `publish` directory: `build/web`

**If netlify.toml is wrong:**
1. Fix the file
2. Commit and push:
   ```bash
   git add netlify.toml
   git commit -m "Fix Netlify configuration"
   git push origin Cleaned_Code
   ```

### 8. Check File Paths

**Verify your changes are in the correct location:**
- Flutter files should be in `frontend_flutter/lib/`
- If you modified files outside `frontend_flutter/`, they won't be deployed
- Netlify only builds from `frontend_flutter/` directory

### 9. Force a New Deploy

**Manual trigger:**
1. In Netlify Dashboard → **Deploys** tab
2. Click **Trigger deploy** → **Deploy site**
3. Select branch: `Cleaned_Code`
4. Click **Deploy**

### 10. Check Deployment Status

**Verify deployment completed:**
- Look for ✅ **Published** status (not just "Building")
- Check the deploy timestamp matches your push time
- If deploy is stuck, cancel and retry

## 🔍 Common Issues and Fixes

### Issue: Build Succeeds But Old Files Deployed

**Cause:** Build cache or publish directory wrong

**Fix:**
1. Clear build cache (Step 5)
2. Verify publish directory is `build/web` (relative to `frontend_flutter`)
3. Check that `flutter build web` actually created new files

### Issue: Changes in Wrong Branch

**Cause:** Pushed to `main` or `master` instead of `Cleaned_Code`

**Fix:**
```bash
# Switch to correct branch
git checkout Cleaned_Code

# Merge or cherry-pick your changes
git cherry-pick <commit-hash>
# OR
git merge <other-branch>

# Push to correct branch
git push origin Cleaned_Code
```

### Issue: Build Fails Silently

**Cause:** Build command error not visible

**Fix:**
1. Check build logs carefully
2. Test build command locally:
   ```bash
   cd frontend_flutter
   flutter pub get
   flutter build web --release --base-href /
   ```
3. If local build fails, fix issues before pushing

### Issue: Flutter SDK Not Found

**Cause:** Flutter installation in build command failing

**Fix:**
- The build command should clone Flutter automatically
- If it fails, check build logs for network/disk space issues
- Consider using Netlify's build plugins for Flutter

## 🎯 Quick Checklist

Before asking for help, verify:

- [ ] Changes are committed and pushed to GitHub
- [ ] Pushed to `Cleaned_Code` branch (not `main`/`master`)
- [ ] Changes visible on GitHub web interface
- [ ] Netlify is set to deploy from `Cleaned_Code` branch
- [ ] Latest deploy shows ✅ Published status
- [ ] Build logs show no errors
- [ ] Tried hard refresh in browser (Ctrl+Shift+R)
- [ ] Tested in incognito/private window
- [ ] Cleared Netlify build cache and redeployed

## 🚀 Still Not Working?

If none of the above works:

1. **Check Netlify Status:** https://www.netlifystatus.com/
2. **Check GitHub Status:** https://www.githubstatus.com/
3. **Review Build Logs:** Look for any error messages
4. **Try Manual Deploy:** Use Netlify CLI or drag-and-drop deploy
5. **Contact Support:** Netlify support is very helpful

## 📝 Useful Commands

```bash
# Check what branch you're on
git branch --show-current

# See recent commits
git log --oneline -10

# Check if changes are pushed
git status

# Force push (if needed, be careful!)
git push origin Cleaned_Code --force

# Build locally to test
cd frontend_flutter
flutter pub get
flutter build web --release --base-href /
```

