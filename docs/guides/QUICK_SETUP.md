# 🚀 Quick Setup for Your Existing Database

Since you already have a PostgreSQL database configured, here's the quick setup:

## 📋 Prerequisites Check

✅ You have a `.env` file with database credentials  
✅ PostgreSQL is running  
✅ Database `proposal_sow_builder` exists  

## 🛠️ Setup Steps

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Set Up Client Tables

```bash
python setup_existing_db.py
```

This will:
- Create the client-side tables in your existing database
- Add sample data (only if no clients exist)
- Test the connection

### 3. Start the Backend

```bash
python -m uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

### 4. Start the Flutter App

```bash
cd frontend_flutter
flutter run -d chrome --web-port 3000
```

## 🧪 Test the Setup

1. **Backend Health Check:**
   ```bash
   curl http://localhost:8000/
   ```

2. **Test Client Dashboard:**
   - Open `http://localhost:3000`
   - The Flutter app should load

3. **Test Email Flow:**
   - Send a proposal email
   - Click "Open Full Dashboard"
   - Should redirect to Flutter client dashboard

## 🔧 Your Database Configuration

Based on your `.env` file:
- **Host:** localhost
- **Port:** 5432
- **Database:** proposal_sow_builder
- **User:** postgres
- **Password:** Password123

## 📊 New Tables Added

The setup will add these tables to your existing database:
- `clients` - Client information
- `proposals` - Proposal documents
- `approvals` - Approval workflow
- `client_dashboard_tokens` - Secure access tokens
- `proposal_feedback` - Client feedback

## 🚨 Troubleshooting

**If setup fails:**
1. Check PostgreSQL is running: `net start postgresql-x64-15`
2. Verify database exists: `psql -U postgres -c "\l"`
3. Check permissions: `GRANT ALL PRIVILEGES ON DATABASE proposal_sow_builder TO postgres;`

**If Flutter path error:**
```bash
# Make sure you're in the right directory
cd frontend_flutter
ls  # Should see pubspec.yaml
```

## 🎯 Next Steps

1. ✅ Database tables created
2. ✅ Backend running on port 8000
3. ✅ Flutter app running on port 3000
4. 🧪 Test the complete client dashboard flow
5. 📧 Test email link functionality

---

**Ready to go!** Your existing database will now support the client dashboard functionality.
