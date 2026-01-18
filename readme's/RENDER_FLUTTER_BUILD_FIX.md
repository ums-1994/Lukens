# 🔧 Fix Flutter "command not found" on Render

## ❌ Error:
```
bash: line 1: flutter: command not found
```

## 🔍 Problem:
Render's Static Site builder doesn't have Flutter SDK installed by default.

## ✅ Solution: Install Flutter in Build Command

### Updated Build Command

Replace your build command with this:

```bash
git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter && export PATH="$PATH:/tmp/flutter/bin" && flutter config --enable-web && cd frontend_flutter && flutter pub get && flutter build web --release --base-href /
```

### Step-by-Step Fix

1. **Go to Render Dashboard**
   - Open your frontend static site service
   - Go to **Settings** tab

2. **Update Build Command**
   - Find **Build Command** field
   - Replace with the command above
   - **Root Directory** should be: `frontend_flutter` (or leave empty if using `cd frontend_flutter`)

3. **Alternative: If Root Directory is `frontend_flutter`**
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter && export PATH="$PATH:/tmp/flutter/bin" && flutter config --enable-web && flutter pub get && flutter build web --release --base-href /
   ```

4. **Save and Redeploy**
   - Click **Save Changes**
   - Render will automatically rebuild

## 📋 What This Command Does

1. **Clones Flutter SDK**: Downloads Flutter stable to `/tmp/flutter`
2. **Adds to PATH**: Makes `flutter` command available
3. **Enables Web**: Configures Flutter for web builds
4. **Gets Dependencies**: Runs `flutter pub get`
5. **Builds Web App**: Creates production build in `build/web`

## ⚠️ Important Notes

- **First build will be slower** (5-10 minutes) because it downloads Flutter
- **Subsequent builds are faster** (Flutter may be cached)
- **Build time**: Expect 5-10 minutes for first build

## 🎯 Alternative: Pre-build Locally (Faster)

If builds are too slow, you can pre-build locally:

1. **Build locally:**
   ```bash
   cd frontend_flutter
   flutter build web --release --base-href /
   ```

2. **Commit the build folder:**
   ```bash
   git add frontend_flutter/build/web
   git commit -m "Add pre-built Flutter web files"
   git push
   ```

3. **Use simpler build command:**
   ```bash
   echo "Using pre-built files"
   ```

4. **Publish Directory**: `frontend_flutter/build/web`

## ✅ Recommended Build Command

**For Render Static Site:**

```bash
git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter && export PATH="$PATH:/tmp/flutter/bin" && flutter config --enable-web && cd frontend_flutter && flutter pub get && flutter build web --release --base-href /
```

**Settings:**
- **Root Directory**: Leave empty OR set to `frontend_flutter`
- **Build Command**: (use command above)
- **Publish Directory**: `frontend_flutter/build/web`

## 🐛 Troubleshooting

**"Still can't find flutter"**
- Make sure the command is all on one line
- Check that `export PATH` is included
- Verify Flutter clone succeeded (check build logs)

**"Build takes too long"**
- First build is always slow (downloading Flutter)
- Consider pre-building locally (Alternative method above)

**"Permission denied"**
- Flutter installs to `/tmp` which should be writable
- If issues persist, try installing to a different location











