# 🗄️ Migrate Local Database to PostgreSQL

This guide will help you migrate your local database to PostgreSQL (for production on Render or other platforms).

## 📋 Two Migration Scenarios

### Scenario 1: SQLite → PostgreSQL
If you're using SQLite locally, use: `migrate_sqlite_to_postgres.py`

### Scenario 2: PostgreSQL → PostgreSQL (Local → Production)
If you're already using PostgreSQL locally, use: `migrate_postgres_to_postgres.py` ⭐ **Use this one!**

## 📋 Prerequisites

1. **PostgreSQL database** set up (local or on Render)
2. **Environment variables** configured for PostgreSQL connection
3. **Python dependencies** installed (`psycopg2`, `python-dotenv`)

## 🚀 Quick Migration

### Step 1: Set Up PostgreSQL Connection

Create or update your `.env` file in the `backend/` directory:

```bash
# PostgreSQL Connection (for Render or local)
DB_HOST=your-postgres-host.render.com
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASSWORD=your_database_password
DB_PORT=5432
DB_SSLMODE=require  # Required for Render

# SQLite Database Path (if different from default)
SQLITE_DB_PATH=khonopro_client.db
```

### Step 2: Run the Migration Script

```bash
cd backend
python migrate_sqlite_to_postgres.py
```

The script will:
- ✅ Connect to your SQLite database
- ✅ Connect to your PostgreSQL database
- ✅ Initialize PostgreSQL schema (if needed)
- ✅ Migrate all tables and data
- ✅ Preserve foreign key relationships
- ✅ Verify migration by comparing row counts

## 📊 What Gets Migrated

The migration script migrates all tables from SQLite to PostgreSQL, including:

- **Users** - All user accounts and authentication data
- **Clients** - Client information and access tokens
- **Proposals** - All proposal documents and status
- **Content** - Content library items
- **Notifications** - User notifications
- **Collaborators** - Collaboration invitations and access
- **And all other tables** in your database

## 🔧 Migration Options

### Option 1: Migrate to Local PostgreSQL

```bash
# Set environment variables
export DB_HOST=localhost
export DB_NAME=proposal_sow_builder
export DB_USER=postgres
export DB_PASSWORD=your_password
export DB_PORT=5432

# Run migration
python migrate_sqlite_to_postgres.py
```

### Option 2: Migrate to Render PostgreSQL

```bash
# Set environment variables (from Render dashboard)
export DB_HOST=dpg-xxxxx-a.render.com
export DB_NAME=your_db_name
export DB_USER=your_db_user
export DB_PASSWORD=your_db_password
export DB_PORT=5432
export DB_SSLMODE=require

# Run migration
python migrate_sqlite_to_postgres.py
```

### Option 3: Use .env File

Create `backend/.env`:

```env
DB_HOST=dpg-xxxxx-a.render.com
DB_NAME=your_db_name
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_PORT=5432
DB_SSLMODE=require
SQLITE_DB_PATH=khonopro_client.db
```

Then run:
```bash
python migrate_sqlite_to_postgres.py
```

## 🔍 Verification

After migration, the script will automatically verify:

1. **Row Counts** - Compares row counts between SQLite and PostgreSQL
2. **Table Structure** - Ensures all tables exist in PostgreSQL
3. **Data Integrity** - Checks for migration errors

### Manual Verification

You can also verify manually:

```bash
# Connect to PostgreSQL
psql -h your-host -U your-user -d your-database

# Check table counts
SELECT 'users' as table_name, COUNT(*) FROM users
UNION ALL
SELECT 'proposals', COUNT(*) FROM proposals
UNION ALL
SELECT 'clients', COUNT(*) FROM clients;
```

## 🚨 Troubleshooting

### "SQLite database not found"

**Solution:**
```bash
# Specify the path explicitly
export SQLITE_DB_PATH=/path/to/your/khonopro_client.db
python migrate_sqlite_to_postgres.py
```

### "Connection refused" or "SSL required"

**Solution:**
- For Render: Set `DB_SSLMODE=require`
- Check firewall settings
- Verify database credentials

### "Table already exists"

**Solution:**
The script skips existing tables by default. To force re-migration:

1. Drop the table in PostgreSQL:
```sql
DROP TABLE table_name CASCADE;
```

2. Re-run migration

### "Foreign key constraint violation"

**Solution:**
The script migrates tables in dependency order. If you still get errors:

1. Disable foreign key checks temporarily:
```sql
SET session_replication_role = 'replica';
-- Run migration
SET session_replication_role = 'origin';
```

2. Or migrate tables manually in correct order

## 📝 Migration Process Details

1. **Schema Initialization**
   - Runs `init_pg_schema()` to ensure all tables exist
   - Creates missing tables and columns

2. **Data Migration**
   - Migrates tables in dependency order:
     - Users/Clients first
     - Proposals second
     - Related tables last

3. **Error Handling**
   - Skips duplicate entries (unique constraint violations)
   - Continues on errors (logs them)
   - Rolls back failed transactions

4. **Verification**
   - Compares row counts
   - Reports mismatches

## 🎯 After Migration

### 1. Update Your Application

Make sure your application uses PostgreSQL:

```bash
# Remove or comment out SQLite usage
# export USE_SQLITE=false  # or remove this line
```

### 2. Test Your Application

```bash
# Start backend
python migrate_db.py && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app

# Or locally
python app.py
```

### 3. Verify Data

- Login with existing users
- Check proposals are visible
- Verify all relationships work

## 🔄 Rollback (If Needed)

If you need to rollback:

1. **Keep SQLite backup** (the script doesn't modify SQLite)
2. **Drop PostgreSQL tables** if needed:
```sql
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```

3. **Re-run migration** if needed

## 📚 Related Commands

### Render Start Command

Your Render start command should include migration:

```bash
python migrate_db.py && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app
```

This ensures:
1. Schema is up-to-date (`migrate_db.py`)
2. Server starts with Gunicorn

### Manual Schema Update

If you only need to update schema (not migrate data):

```bash
python migrate_db.py
```

## ✅ Success Checklist

After migration, verify:

- [ ] All tables migrated
- [ ] Row counts match
- [ ] Users can login
- [ ] Proposals are visible
- [ ] Foreign keys work
- [ ] No errors in logs

## 🆘 Need Help?

If migration fails:

1. Check error messages carefully
2. Verify database credentials
3. Check PostgreSQL logs
4. Ensure schema is initialized
5. Try migrating tables individually

---

**Note:** The migration script preserves your SQLite database. It only reads from SQLite and writes to PostgreSQL.

