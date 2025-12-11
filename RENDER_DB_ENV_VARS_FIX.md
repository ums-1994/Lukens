# 🔧 Fix Database Connection - Missing Environment Variables

## ❌ Current Error:
```
🔄 Connecting to PostgreSQL: localhost:5432/proposal_sow_builder
psycopg2.OperationalError: connection to server at "localhost" failed: Connection refused
```

## 🔍 Problem:
The backend is trying to connect to `localhost` because the database environment variables are **not set** in Render.

## ✅ Solution: Add Database Environment Variables

### Step 1: Go to Render Dashboard
1. Open your **backend service** (`lukens-backend`)
2. Click on **Environment** tab

### Step 2: Add These Environment Variables

Click **"Add Environment Variable"** for each one:

```env
DB_HOST=dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=proposal_sow_builder_user
DB_PASSWORD=LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez
DB_SSLMODE=require
```

### Step 3: Save and Redeploy
1. Click **"Save Changes"**
2. Render will automatically redeploy
3. Wait for deployment to complete

### Step 4: Verify Connection

After redeployment, check the logs. You should see:
```
🔄 Connecting to PostgreSQL: dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com:5432/proposal_sow_builder
🔒 Using SSL mode: require for external connection
✅ PostgreSQL connection pool created successfully
```

Instead of:
```
🔄 Connecting to PostgreSQL: localhost:5432/proposal_sow_builder
❌ Error creating PostgreSQL connection pool: Connection refused
```

## 📋 Complete Environment Variables Checklist

Make sure you have ALL these set in Render:

### Database (Required):
- ✅ `DB_HOST`
- ✅ `DB_PORT`
- ✅ `DB_NAME`
- ✅ `DB_USER`
- ✅ `DB_PASSWORD`
- ✅ `DB_SSLMODE`

### Python (Already Set):
- ✅ `PYTHON_VERSION=3.11.0`

### Other (Add as needed):
- `OPENROUTER_API_KEY`
- `CLOUDINARY_*`
- `SMTP_*`
- `DOCUSIGN_*`
- `FIREBASE_*`
- `FRONTEND_URL`

## 🎯 Quick Copy-Paste

**In Render Dashboard → Backend Service → Environment:**

Add these 6 variables:
```
DB_HOST=dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=proposal_sow_builder_user
DB_PASSWORD=LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez
DB_SSLMODE=require
```

Save and wait for redeployment!

## ✅ Expected Result

After adding the variables and redeploying:
- ✅ Build successful
- ✅ Database connection successful
- ✅ App starts without errors
- ✅ Your service is live at: `https://lukens-wp8w.onrender.com`







