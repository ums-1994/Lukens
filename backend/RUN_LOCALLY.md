# Running Backend Locally

## Quick Setup

### 1. Create/Update `.env` file in `backend/` directory

You can use your Render database credentials. Create `backend/.env` with:

```env
# Database Configuration (using Render database)
DB_HOST=dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=proposal_sow_builder_user
DB_PASSWORD=LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez
DB_SSLMODE=require

# Firebase (if you have these)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email

# Other environment variables (optional for local testing)
FLASK_ENV=development
DEBUG=True
```

### 2. Install Dependencies

```bash
cd backend
python -m venv .venv

# Windows (PowerShell - create .venv first if it doesn't exist):
#   .\.venv\Scripts\Activate.ps1
# Windows (CMD):
#   .venv\Scripts\activate.bat

# Mac/Linux:
source .venv/bin/activate

pip install -r requirements.txt
```

### 3. Run the Backend

```bash
# Make sure you're in the backend directory
cd backend

# Run Flask directly
python app.py
```

The server will start on `http://localhost:8000`

### 4. Test the Connection

Open another terminal and test:
```bash
curl http://localhost:8000/health
```

You should see a JSON response with database status.

## Debugging the Commit Issue

When you run locally, you'll see detailed logs in the terminal. Watch for:
- `[FIREBASE] Auto-created user: ...`
- `[FIREBASE] Commit executed. Connection status: ...`
- `[FIREBASE] ✅ Verified user exists...` or `⚠️ WARNING: User not found...`

This will help us see exactly what's happening with the database commits.

## Troubleshooting

### Connection Errors
- Make sure your `.env` file is in the `backend/` directory
- Check that the database credentials are correct
- Verify SSL mode is set to `require` for Render database

### "SSL connection has been closed unexpectedly" (Render Postgres)
This often happens when connecting from your machine to Render's free PostgreSQL (firewall, TLS, or network). Options:

1. **Use the External Database URL**  
   In Render Dashboard → your Postgres service → **Connect** → copy **External Database URL**.  
   In `.env` set:
   ```env
   DATABASE_URL=postgresql://user:pass@hostname/dbname?sslmode=require
   ```
   (or use `DATABASE_URL_EXTERNAL` if your app supports it and you also set `DATABASE_URL` to the internal URL.)

2. **Use a local PostgreSQL for development**  
   Install Postgres locally and in `.env` set:
   ```env
   DATABASE_URL=postgresql://postgres:yourpassword@localhost:5432/your_db_name
   ```
   No `DB_SSLMODE` needed for localhost. Create the DB first: `createdb your_db_name`.

3. **Timeouts / keepalives**  
   The backend now adds `connect_timeout` and TCP keepalives for remote hosts. If it still fails, try increasing timeout in `.env`:
   ```env
   DB_CONNECT_TIMEOUT=30
   ```

### Import Errors
- Make sure you activated the virtual environment
- Run `pip install -r requirements.txt` again

### Port Already in Use
- Change the port in `app.py` line 1635: `app.run(debug=True, host='0.0.0.0', port=8001)`

