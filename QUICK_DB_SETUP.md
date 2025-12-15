# ⚡ Quick Database Setup for Render

## Your Database Connection String
```
postgresql://proposal_sow_builder_user:LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez@dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com/proposal_sow_builder
```

## 🎯 Copy-Paste These Environment Variables

In your **Render Backend Service** → **Environment** tab, add these **exact** values:

```
DB_HOST=dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=proposal_sow_builder_user
DB_PASSWORD=LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez
DB_SSLMODE=require
```

## ✅ Steps

1. Go to Render Dashboard
2. Click your backend service
3. Go to **Environment** tab
4. Click **"Add Environment Variable"** for each one above
5. **Save Changes** (auto-redeploys)
6. Check logs for: `✅ PostgreSQL connection pool created successfully`

## 🔒 SSL Note

The code automatically detects Render databases and uses SSL. Setting `DB_SSLMODE=require` ensures it works.

## 📝 Done!

Your backend will now connect to the database automatically.








