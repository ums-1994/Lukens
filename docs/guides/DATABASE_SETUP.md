# 🗄️ KhonoPro Proposal System - Database Setup

This guide will help you set up the PostgreSQL database for the KhonoPro Proposal System.

## 🚀 Quick Start (Docker)

### 1. Start PostgreSQL with Docker Compose

```bash
# Start PostgreSQL and PgAdmin
docker-compose up -d

# Check if services are running
docker-compose ps
```

### 2. Set up the database schema

```bash
# Install Python dependencies
cd backend
pip install -r requirements.txt

# Run the database setup script
python setup_database.py
```

### 3. Start the application

```bash
# Start the backend
python -m uvicorn app:app --host 127.0.0.1 --port 8000 --reload

# In another terminal, start the Flutter app
cd frontend_flutter
flutter run -d chrome --web-port 3000
```

## 🛠️ Manual Setup (Without Docker)

### 1. Install PostgreSQL

- **Windows**: Download from [postgresql.org](https://www.postgresql.org/download/windows/)
- **macOS**: `brew install postgresql`
- **Linux**: `sudo apt-get install postgresql postgresql-contrib`

### 2. Create database and user

```sql
-- Connect to PostgreSQL as superuser
psql -U postgres

-- Create database and user
CREATE DATABASE khonopro;
CREATE USER khonopro_user WITH PASSWORD 'khonopro_password';
GRANT ALL PRIVILEGES ON DATABASE khonopro TO khonopro_user;
\q
```

### 3. Run the schema

```bash
# Apply the database schema
psql -U khonopro_user -d khonopro -f backend/database_schema.sql
```

## 📊 Database Schema Overview

### Tables

| Table | Description |
|-------|-------------|
| `clients` | Client information and access tokens |
| `proposals` | Proposal documents and status |
| `approvals` | Approval workflow data |
| `client_dashboard_tokens` | Secure access tokens for client dashboard |
| `proposal_feedback` | Client feedback and ratings |

### Key Features

- **UUID Primary Keys**: All tables use UUID for better security
- **Foreign Key Constraints**: Proper relationships between tables
- **Enums**: Type-safe status and role fields
- **Timestamps**: Automatic created_at and updated_at tracking
- **Indexes**: Optimized for common queries
- **Views**: Pre-built queries for dashboard statistics

## 🔧 Configuration

### Environment Variables

```bash
# Database URL (optional - defaults to local PostgreSQL)
export DATABASE_URL="postgresql+psycopg2://khonopro_user:khonopro_password@localhost:5432/khonopro"

# Use SQLite for development (optional)
export USE_SQLITE="true"
```

### Connection Details

- **PostgreSQL**: `localhost:5432`
- **Database**: `khonopro`
- **Username**: `khonopro_user`
- **Password**: `khonopro_password`
- **PgAdmin**: `http://localhost:5050` (admin@khonology.com / admin123)

## 🧪 Testing the Setup

### 1. Test database connection

```python
from backend.database_config import get_db

# Test connection
db = next(get_db())
print("✅ Database connection successful!")
```

### 2. Test API endpoints

```bash
# Test health endpoint
curl http://localhost:8000/

# Test client dashboard (with valid token)
curl http://localhost:8000/client-dashboard/{token}
```

### 3. Access PgAdmin

1. Open `http://localhost:5050`
2. Login with `admin@khonology.com` / `admin123`
3. Add server: `postgres` / `khonopro_password`
4. Browse the `khonopro` database

## 🚨 Troubleshooting

### Common Issues

1. **Port 5432 already in use**
   ```bash
   # Find and kill the process
   netstat -ano | findstr :5432
   taskkill /PID <PID> /F
   ```

2. **Permission denied**
   ```bash
   # Make sure the user has proper permissions
   GRANT ALL PRIVILEGES ON DATABASE khonopro TO khonopro_user;
   ```

3. **Connection refused**
   ```bash
   # Check if PostgreSQL is running
   docker-compose ps
   # or
   sudo systemctl status postgresql
   ```

### Reset Database

```bash
# Stop services
docker-compose down

# Remove volumes (WARNING: This deletes all data)
docker-compose down -v

# Start fresh
docker-compose up -d
python backend/setup_database.py
```

## 📈 Performance Optimization

### Indexes

The schema includes optimized indexes for:
- Client email lookups
- Proposal status filtering
- Token validation
- Dashboard statistics

### Connection Pooling

The SQLAlchemy configuration includes:
- Connection pooling
- Pre-ping validation
- Connection recycling

## 🔒 Security Features

- **UUID Tokens**: Secure, non-sequential access tokens
- **Token Expiration**: Automatic token expiry
- **Role-based Access**: Client, Approver, Admin roles
- **Audit Trail**: Created/updated timestamps
- **Cascade Deletes**: Proper data cleanup

## 📚 API Integration

The database models are designed to work seamlessly with your FastAPI backend:

```python
from backend.database_config import get_db
from backend.models_client import Client, Proposal

# Example usage in FastAPI
@app.get("/clients")
def get_clients(db: Session = Depends(get_db)):
    return db.query(Client).all()
```

## 🎯 Next Steps

1. ✅ Database setup complete
2. 🔄 Integrate with existing FastAPI endpoints
3. 🧪 Add comprehensive tests
4. 📊 Set up monitoring and logging
5. 🚀 Deploy to production

---

**Need help?** Check the troubleshooting section or create an issue in the repository.
