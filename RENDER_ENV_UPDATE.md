# Update Render Environment Variables

## Issue
Render deployment is using old database credentials. The seed script is trying to use `sowbuilder_user` instead of `sowbuilder_jdyx_user`.

## Solution
Update these environment variables in your **Render Dashboard** → Backend Service → Settings → Environment Variables:

```
DB_HOST=dpg-d61mhge3jp1c7390jcm0-a
DB_PORT=5432
DB_NAME=sowbuilder_jdyx
DB_USER=sowbuilder_jdyx_user
DB_PASSWORD=LvUDRxCLtJSQn7tTKhux50kfCsL89cuF
DB_SSLMODE=require
DATABASE_URL=postgresql://sowbuilder_jdyx_user:LvUDRxCLtJSQn7tTKhux50kfCsL89cuF@dpg-d61mhge3jp1c7390jcm0-a/sowbuilder_jdyx
```

## Steps
1. Go to https://dashboard.render.com/
2. Select your backend service (lukens-wp8w)
3. Click **Settings** → **Environment**
4. Update/add each variable above
5. Click **Save Changes** at the bottom
6. Redeploy: Click **Deploys** tab → **Latest deploy** → **Redeploy**

Wait for deployment to complete. Logs should show:
- ✅ Database connection successful
- ✅ Content blocks seeded

## Local Testing
If you want to test locally first:
```bash
cd backend
python seed_content_blocks.py
```

Should show:
```
🚀 Seeding Khonology content blocks...
✅ Successfully seeded X content blocks!
```
