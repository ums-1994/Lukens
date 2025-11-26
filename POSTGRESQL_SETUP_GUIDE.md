# 🗄️ PostgreSQL Database Setup Guide with pgAdmin

Complete guide to set up your Khonology Proposals database locally.

---

## 📋 **Prerequisites**

1. **PostgreSQL** installed (v12 or higher)
2. **pgAdmin 4** installed (comes with PostgreSQL)

**Download PostgreSQL:** https://www.postgresql.org/download/

---

## 🚀 **Step-by-Step Setup**

### **Step 1: Open pgAdmin**

1. Launch **pgAdmin 4** from your Start menu
2. Enter your master password (set during PostgreSQL installation)
3. The pgAdmin interface will open

### **Step 2: Create a New Database**

1. In the left sidebar, expand **Servers** → **PostgreSQL 15** (or your version)
2. Right-click on **Databases**
3. Select **Create** → **Database...**
4. In the dialog:
   - **Database name:** `khonology_proposals`
   - **Owner:** `postgres`
   - **Encoding:** `UTF8`
5. Click **Save**

### **Step 3: Open Query Tool**

1. Right-click on your newly created database: **khonology_proposals**
2. Select **Query Tool** (or press Alt+Shift+Q)
3. A new query window will open

### **Step 4: Run the Setup Script**

1. Open the file: `backend/setup_complete_database.sql`
2. **Copy all the contents** of that file
3. **Paste** into the pgAdmin Query Tool window
4. Click the **Execute/Run** button (▶️) or press **F5**
5. Wait for the script to complete (should take a few seconds)

You should see messages like:
```
CREATE TABLE
CREATE INDEX
CREATE TRIGGER
INSERT 0 3
Query returned successfully in XXX msec.
```

### **Step 5: Verify the Setup**

1. In pgAdmin's left sidebar, right-click on **khonology_proposals**
2. Select **Refresh**
3. Expand **khonology_proposals** → **Schemas** → **public** → **Tables**
4. You should see all these tables:
   - ✅ users
   - ✅ proposals
   - ✅ content
   - ✅ settings
   - ✅ proposal_versions
   - ✅ document_comments
   - ✅ collaboration_invitations
   - ✅ collaboration_sessions
   - ✅ clients
   - ✅ approvals
   - ✅ client_dashboard_tokens
   - ✅ proposal_feedback

---

## 🔧 **Configure Your Backend**

### **Update Environment Variables**

Create or update your `.env` file in the `backend` folder:

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=khonology_proposals
DB_USER=postgres
DB_PASSWORD=your_postgres_password

# Flask Configuration
FLASK_ENV=development
SECRET_KEY=your-secret-key-change-in-production
ENCRYPTION_KEY=your-encryption-key-32-chars

# Cloudinary (if using image uploads)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

**Important:** Replace `your_postgres_password` with the actual password you set during PostgreSQL installation!

---

## 🧪 **Test Database Connection**

Run this command from the `backend` folder:

```bash
cd backend
python check_db_connection.py
```

You should see:
```
✅ Database connection successful!
✅ All tables exist
```

---

## 👤 **Test Login Credentials**

Three test users were created with these credentials:

| Role | Email | Password |
|------|-------|----------|
| **Admin** | admin@khonology.com | password123 |
| **CEO** | ceo@khonology.com | password123 |
| **Financial Manager** | financial@khonology.com | password123 |

You can use any of these to log into your Flutter app!

---

## 🔍 **Common Issues & Solutions**

### Issue: "Connection refused"
**Solution:** Make sure PostgreSQL service is running:
- Open **Services** (Windows + R → `services.msc`)
- Find **postgresql-x64-15** (or your version)
- Right-click → **Start**

### Issue: "Password authentication failed"
**Solution:** 
1. Check your `.env` file has the correct password
2. Verify password in pgAdmin: Right-click server → Properties → Connection

### Issue: "Database does not exist"
**Solution:** Make sure you created the database in Step 2 above

### Issue: "Permission denied"
**Solution:** Make sure you're logged in as `postgres` user or a superuser

---

## 📊 **View Your Data in pgAdmin**

To see data in any table:
1. Expand **Tables** in the left sidebar
2. Right-click on a table (e.g., **users**)
3. Select **View/Edit Data** → **All Rows**

---

## 🗑️ **Reset Database (if needed)**

If you need to start fresh:

1. Right-click on **khonology_proposals** database
2. Select **Delete/Drop**
3. Confirm deletion
4. Go back to **Step 2** and recreate everything

---

## 🚀 **Start Your Application**

Once database is set up:

### 1. Start Backend:
```bash
cd backend
python app.py
```

### 2. Start Frontend:
```bash
cd frontend_flutter
flutter run -d chrome
```

### 3. Login with test credentials!

---

## 📞 **Need Help?**

- Check PostgreSQL logs in pgAdmin
- View error messages in the Query Tool
- Ensure all environment variables are set correctly
- Make sure PostgreSQL service is running

---

## ✅ **Checklist**

- [ ] PostgreSQL installed and running
- [ ] Database `khonology_proposals` created
- [ ] Setup script executed successfully
- [ ] All tables visible in pgAdmin
- [ ] `.env` file configured with correct credentials
- [ ] Backend connection test passed
- [ ] Can log in with test credentials

---

**🎉 You're all set! Your database is ready to use!**
















































