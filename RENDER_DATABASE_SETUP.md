# 🗄️ Render Database Configuration

## Your Database Connection String

```
postgresql://proposal_sow_builder_user:LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez@dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com/proposal_sow_builder
```

## 📋 Parsed Connection Details

From your connection string, here are the individual components:

- **Host**: `dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com`
- **Port**: `5432` (PostgreSQL default - not in URL but standard)
- **Database**: `proposal_sow_builder`
- **Username**: `proposal_sow_builder_user`
- **Password**: `LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez`

## 🔧 Setting Environment Variables in Render

### Option 1: Individual Variables (Recommended)

In your **backend service** on Render, go to **Environment** tab and add:

```env
DB_HOST=dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=proposal_sow_builder_user
DB_PASSWORD=LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez
DB_SSLMODE=require
```

**Note**: The code automatically detects Render databases and uses SSL, but it's good to set it explicitly.

### Option 2: Using Connection String (Alternative)

If your backend supports `DATABASE_URL`, you can also use:

```env
DATABASE_URL=postgresql://proposal_sow_builder_user:LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez@dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com:5432/proposal_sow_builder
```

## ⚠️ Important Notes

1. **Internal vs External URL**: 
   - The URL you provided is the **external** connection string
   - Render services can also use an **internal** connection string (faster, no SSL required)
   - If your backend is on Render, use the **internal** connection string from the database dashboard

2. **SSL Connection**: 
   - External connections require SSL
   - Your backend code should handle SSL connections properly
   - Add `?sslmode=require` if needed

3. **Security**: 
   - ⚠️ **Never commit passwords to Git**
   - Always use Render's environment variables
   - The password shown here should be kept secret

## 🔍 Finding Internal Connection String

1. Go to your PostgreSQL database in Render dashboard
2. Look for **"Internal Database URL"** (different from external)
3. Use that for better performance if backend is on Render

## ✅ Verification

After setting environment variables:

1. **Save** the environment variables in Render
2. **Redeploy** your backend service (auto-happens when you save env vars)
3. **Check logs** to verify database connection:
   ```
   ✅ PostgreSQL connection pool created successfully
   ✅ Database schema initialized successfully
   ```

## 🐛 Troubleshooting

**Connection refused:**
- Verify all environment variables are set correctly
- Check host includes port if needed
- Ensure database is running (not paused)

**Authentication failed:**
- Double-check username and password
- Verify password doesn't have special characters that need escaping

**SSL required:**
- Add `?sslmode=require` to connection string
- Or configure SSL in database connection code

## 📝 Next Steps

1. ✅ Set environment variables in Render backend service
2. ✅ Deploy/restart backend service
3. ✅ Check logs for successful database connection
4. ✅ Database schema will auto-initialize on first request

