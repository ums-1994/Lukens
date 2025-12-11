# 🔧 Update Render Start Command - URGENT FIX NEEDED

## Problem
Render is using a start command from the dashboard that includes `-b 0.0.0.0:$PORT`, which fails because:
1. The `-b` flag overrides the config file
2. If `$PORT` is empty, it becomes `-b 0.0.0.0:` which is invalid
3. The service fails to bind to a port and deployment times out

## Solution - Update Render Dashboard NOW

**You MUST update the start command in your Render dashboard:**

1. Go to your Render dashboard: https://dashboard.render.com
2. Navigate to your backend service (lukens-backend)
3. Go to **Settings** → **Start Command**
4. **DELETE** the current start command
5. **REPLACE** it with this exact command:

```bash
cd backend && python migrate_db.py && gunicorn -c gunicorn_conf.py app:app
```

6. Click **Save Changes**
7. Render will automatically redeploy

### Why This Works

- Removes the problematic `-b 0.0.0.0:$PORT` flag
- The `gunicorn_conf.py` file automatically reads the `PORT` environment variable
- Render automatically sets `PORT` - no need to reference it in the command
- The config file handles port binding correctly

### Option 2: Use render.yaml (If Render is using it)

The `render.yaml` file has been updated. If Render is using it, the start command should work automatically.

### Why This Works

- The `gunicorn_conf.py` file reads the `PORT` environment variable automatically
- Render automatically sets the `PORT` environment variable
- No need to use `-b` flag - the config file handles it
- More reliable than using `$PORT` in the command line

### Verification

After updating, check the logs for:
```
🔌 Gunicorn binding to: 0.0.0.0:XXXXX
```

Where `XXXXX` is the port number provided by Render.

### Current Issue

The logs show Render is using:
```
python migrate_db.py && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app
```

This command has the `-b` flag which overrides the config file. Update it to remove the `-b` flag as shown above.

