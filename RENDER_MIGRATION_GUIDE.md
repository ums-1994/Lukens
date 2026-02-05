# Database Migration to Render

## Current Status
✅ Local database backed up: `local_db_backup.sql` (746 KB)
✅ Render credentials configured in `backend/.env`
✅ Internal connection string ready

## Migration Steps

### Step 1: Update render.yaml (or build configuration)

Add the backup and migration script to Render deployment:

```yaml
services:
  - type: web
    name: backend
    runtime: python
    buildCommand: >
      pip install -r requirements.txt &&
      python migrate_render.py
    startCommand: gunicorn app:app
    envVars:
      - key: DATABASE_URL
        value: postgresql://sowbuilder_jdyx_user:LvUDRxCLtJSQn7tTKhux50kfCsL89cuF@dpg-d61mhge3jp1c7390jcm0-a/sowbuilder_jdyx
```

### Step 2: Deploy to Render

Push these files to your repository:
- `backend/migrate_render.py` - Migration script
- `backend/local_db_backup.sql` - Database dump

Then trigger a new deployment on Render.

### Step 3: Verify Migration

Once deployed, check Render logs:
```
✅ Connected to Render database (internal)
✅ Database restored successfully!
```

### Step 4 (Local): Switch to Render Database

To run backend locally against Render DB, ensure `.env` has:
```env
DB_HOST=dpg-d61mhge3jp1c7390jcm0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=sowbuilder_jdyx
DB_USER=sowbuilder_jdyx_user
DB_PASSWORD=LvUDRxCLtJSQn7tTKhux50kfCsL89cuF
```

### Troubleshooting

**If migration fails on Render:**
1. Check the build logs for connection errors
2. Verify `DATABASE_URL` env var is set correctly
3. Ensure `local_db_backup.sql` is committed to git

**To retry migration:**
- Set env var `SKIP_MIGRATION=true` temporarily
- Manually connect and restore via psql (from Render CLI)
