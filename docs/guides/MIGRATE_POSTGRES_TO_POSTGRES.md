# 🗄️ Migrate Local PostgreSQL to Production PostgreSQL (Render)

This guide will help you migrate your local PostgreSQL database to your production PostgreSQL database on Render.

## 🚀 Quick Migration

### Step 1: Set Up Environment Variables

Create or update your `.env` file in the `backend/` directory:

```bash
# Source Database (Local PostgreSQL - your current database)
SOURCE_DB_HOST=localhost
SOURCE_DB_NAME=proposal_sow_builder
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=your_local_password
SOURCE_DB_PORT=5432

# Destination Database (Render PostgreSQL - production)
DEST_DB_HOST=dpg-xxxxx-a.render.com
DEST_DB_NAME=your_render_db_name
DEST_DB_USER=your_render_db_user
DEST_DB_PASSWORD=your_render_db_password
DEST_DB_PORT=5432
DEST_DB_SSLMODE=require  # Required for Render
```

**Or use RENDER_DB_* prefix (alternative):**

```bash
RENDER_DB_HOST=dpg-xxxxx-a.render.com
RENDER_DB_NAME=your_render_db_name
RENDER_DB_USER=your_render_db_user
RENDER_DB_PASSWORD=your_render_db_password
RENDER_DB_PORT=5432
```

### Step 2: Run the Migration Script

```bash
cd backend
python migrate_postgres_to_postgres.py
```

The script will:
- ✅ Connect to your local PostgreSQL database
- ✅ Connect to your Render PostgreSQL database
- ✅ Initialize destination schema (if needed)
- ✅ Migrate all tables and data
- ✅ Preserve foreign key relationships
- ✅ Verify migration by comparing row counts

## 📊 What Gets Migrated

The migration script migrates all tables from local PostgreSQL to Render PostgreSQL, including:

- **Users** - All user accounts and authentication data
- **Clients** - Client information and access tokens
- **Proposals** - All proposal documents and status
- **Content** - Content library items
- **Notifications** - User notifications
- **Collaborators** - Collaboration invitations and access
- **Comments** - All comments and discussions
- **AI Usage** - AI analytics data
- **And all other tables** in your database

## 🔧 Migration Options

### Option 1: Skip Existing Data (Default - Safe)

```bash
# This will skip tables that already have data
python migrate_postgres_to_postgres.py
```

**Use this if:**
- You've already migrated some data
- You want to preserve existing production data
- You're doing incremental updates

### Option 2: Truncate and Re-migrate (Full Migration)

```bash
# Set environment variable
export MIGRATE_TRUNCATE=true

# Run migration (will ask for confirmation)
python migrate_postgres_to_postgres.py
```

**Use this if:**
- You want a fresh copy of your local database
- You're doing a complete replacement
- You're okay with deleting existing production data

## 🔍 Verification

After migration, the script will automatically verify:

1. **Row Counts** - Compares row counts between local and production
2. **Table Structure** - Ensures all tables exist in production
3. **Data Integrity** - Checks for migration errors

### Manual Verification

You can also verify manually:

```bash
# Connect to Render PostgreSQL
psql -h dpg-xxxxx-a.render.com -U your_user -d your_database

# Check table counts
SELECT 'users' as table_name, COUNT(*) FROM users
UNION ALL
SELECT 'proposals', COUNT(*) FROM proposals
UNION ALL
SELECT 'clients', COUNT(*) FROM clients;
```

## 🚨 Troubleshooting

### "Destination database not configured"

**Solution:**
Make sure you've set the destination database environment variables:

```bash
export DEST_DB_HOST=your-render-host.render.com
export DEST_DB_NAME=your_database_name
export DEST_DB_USER=your_database_user
export DEST_DB_PASSWORD=your_database_password
export DEST_DB_SSLMODE=require
```

### "Connection refused" or "SSL required"

**Solution:**
- For Render: Set `DEST_DB_SSLMODE=require`
- Check firewall settings
- Verify database credentials from Render dashboard

### "Table already exists" or "Duplicate key"

**Solution:**
The script skips existing data by default. To force re-migration:

1. Use truncate mode:
```bash
export MIGRATE_TRUNCATE=true
python migrate_postgres_to_postgres.py
```

2. Or manually truncate tables:
```sql
TRUNCATE TABLE table_name CASCADE;
```

### "Foreign key constraint violation"

**Solution:**
The script migrates tables in dependency order. If you still get errors:

1. Ensure schema is initialized:
```bash
python migrate_db.py
```

2. Check table dependencies and migrate in correct order

## 📝 Migration Process Details

1. **Schema Initialization**
   - Runs `init_pg_schema()` on destination to ensure all tables exist
   - Creates missing tables and columns

2. **Data Migration**
   - Migrates tables in dependency order:
     - Users/Clients first
     - Proposals second
     - Related tables last
   - Uses batch inserts (1000 rows at a time) for performance

3. **Error Handling**
   - Skips duplicate entries (unique constraint violations)
   - Continues on errors (logs them)
   - Rolls back failed transactions

4. **Verification**
   - Compares row counts
   - Reports mismatches

## 🎯 After Migration

### 1. Update Your Render Environment Variables

Make sure your Render service uses the production database:

```bash
# In Render Dashboard → Environment
DB_HOST=dpg-xxxxx-a.render.com
DB_NAME=your_render_db_name
DB_USER=your_render_db_user
DB_PASSWORD=your_render_db_password
DB_PORT=5432
DB_SSLMODE=require
```

### 2. Test Your Application

```bash
# Your Render start command should be:
python migrate_db.py && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app
```

This ensures:
- Schema is up-to-date on each deploy
- Server starts with Gunicorn

### 3. Verify Data

- Login with existing users
- Check proposals are visible
- Verify all relationships work
- Test all features

## 🔄 Incremental Updates

If you need to update production with new local data:

```bash
# Just run the migration again
# It will skip existing data by default
python migrate_postgres_to_postgres.py
```

Or for specific tables, you can truncate and re-migrate:

```bash
# Connect to production
psql -h your-host -U your-user -d your-database

# Truncate specific table
TRUNCATE TABLE proposals CASCADE;

# Run migration (will re-migrate that table)
python migrate_postgres_to_postgres.py
```

## ✅ Success Checklist

After migration, verify:

- [ ] All tables migrated
- [ ] Row counts match between local and production
- [ ] Users can login on production
- [ ] Proposals are visible
- [ ] Foreign keys work
- [ ] No errors in Render logs
- [ ] All features work correctly

## 🆘 Need Help?

If migration fails:

1. Check error messages carefully
2. Verify both database credentials
3. Check PostgreSQL logs on both sides
4. Ensure schema is initialized on destination
5. Try migrating tables individually
6. Check network connectivity to Render

## 📚 Related Commands

### Render Start Command

Your Render start command should include schema migration:

```bash
python migrate_db.py && gunicorn -c gunicorn_conf.py -b 0.0.0.0:$PORT app:app
```

This ensures:
1. Schema is up-to-date (`migrate_db.py`)
2. Server starts with Gunicorn

### Manual Schema Update

If you only need to update schema (not migrate data):

```bash
# On Render, this runs automatically on deploy
python migrate_db.py
```

---

**Note:** The migration script preserves your local database. It only reads from local and writes to production.

