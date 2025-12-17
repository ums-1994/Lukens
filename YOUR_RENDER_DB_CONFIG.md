# 🗄️ Your Render Database Configuration

## ✅ Your Database Connection Details

Based on your Render PostgreSQL connection string, here are the exact values to use:

### Environment Variables for Backend Service

Go to your **backend service** in Render dashboard → **Environment** tab → Add these:

```env
DB_HOST=dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=proposal_sow_builder_user
DB_PASSWORD=LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez
DB_SSLMODE=require
```

## 📋 Quick Setup Steps

1. **Go to Render Dashboard**
   - Navigate to your backend web service

2. **Open Environment Tab**
   - Click on your backend service
   - Go to **"Environment"** tab

3. **Add Database Variables**
   - Click **"Add Environment Variable"**
   - Add each variable from the list above
   - **Important**: Copy-paste the values exactly as shown

4. **Save Changes**
   - Click **"Save Changes"**
   - Render will automatically redeploy your service

5. **Verify Connection**
   - Check the deployment logs
   - Look for: `✅ PostgreSQL connection pool created successfully`
   - If you see errors, check the troubleshooting section below

## 🔍 What Each Variable Does

- **DB_HOST**: The database server address
- **DB_PORT**: PostgreSQL port (always 5432)
- **DB_NAME**: The database name
- **DB_USER**: Database username
- **DB_PASSWORD**: Database password
- **DB_SSLMODE**: SSL connection mode (required for external connections)

## ⚠️ Important Notes

1. **Password Security**: 
   - ⚠️ Never commit this password to Git
   - Only store in Render environment variables
   - The password shown here is already exposed - consider rotating it if needed

2. **Internal vs External**:
   - The connection string you provided is the **external** URL
   - If your backend is also on Render, use the **internal** connection string for better performance
   - Find it in your database dashboard under "Internal Database URL"

3. **SSL Required**:
   - External connections to Render databases require SSL
   - The code has been updated to automatically detect and use SSL for Render databases
   - Setting `DB_SSLMODE=require` ensures secure connection

## ✅ Verification

After setting the variables and redeploying, check your backend logs for:

```
🔄 Connecting to PostgreSQL: dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com:5432/proposal_sow_builder
🔒 Using SSL mode: require for external connection
✅ PostgreSQL connection pool created successfully
✅ Database schema initialized successfully
```

## 🐛 Troubleshooting

### "Connection refused" or "Connection timeout"
- Verify all environment variables are set correctly
- Check that the database is running (not paused)
- Ensure host doesn't have extra spaces

### "Authentication failed"
- Double-check username and password
- Make sure password doesn't have extra spaces or line breaks
- Verify username is exactly: `proposal_sow_builder_user`

### "SSL connection required"
- Ensure `DB_SSLMODE=require` is set
- The code should auto-detect Render databases, but explicit setting helps

### "Database does not exist"
- Verify `DB_NAME=proposal_sow_builder` (exact match)
- Check database name in Render dashboard

## 🚀 Next Steps

1. ✅ Set all environment variables
2. ✅ Save and wait for redeployment
3. ✅ Check logs for successful connection
4. ✅ Database schema will auto-initialize on first request
5. ✅ Test your API endpoints

## 📞 Need Help?

- Check backend logs in Render dashboard
- Verify all variables are set (no typos)
- Ensure database is not paused
- Check Render status page if issues persist







