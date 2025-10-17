# 🗄️ KhonoPro Proposal System - Setup Without Docker

This guide will help you set up the PostgreSQL database and application without using Docker.

## 📋 Prerequisites

- Python 3.8+
- Flutter SDK
- PostgreSQL 12+ (or SQLite for development)

## 🐘 PostgreSQL Installation

### Windows
1. Download PostgreSQL from [postgresql.org](https://www.postgresql.org/download/windows/)
2. Run the installer and follow the setup wizard
3. Remember the password you set for the `postgres` user
4. Add PostgreSQL to your PATH

### macOS
```bash
# Using Homebrew
brew install postgresql
brew services start postgresql

# Or using MacPorts
sudo port install postgresql15
```

### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

## 🗄️ Database Setup

### 1. Create Database and User

```bash
# Connect to PostgreSQL as superuser
psql -U postgres

# Create database and user
CREATE DATABASE khonopro;
CREATE USER khonopro_user WITH PASSWORD 'khonopro_password';
GRANT ALL PRIVILEGES ON DATABASE khonopro TO khonopro_user;
\q
```

### 2. Apply Database Schema

```bash
# Apply the schema
psql -U khonopro_user -d khonopro -f backend/database_schema.sql
```

### 3. Verify Setup

```bash
# Connect to verify
psql -U khonopro_user -d khonopro

# Check tables
\dt

# Check sample data
SELECT * FROM clients;
\q
```

## 🐍 Python Backend Setup

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Set Environment Variables (Optional)

```bash
# Windows (PowerShell)
$env:DATABASE_URL="postgresql+psycopg2://khonopro_user:khonopro_password@localhost:5432/khonopro"

# Windows (Command Prompt)
set DATABASE_URL=postgresql+psycopg2://khonopro_user:khonopro_password@localhost:5432/khonopro

# Linux/macOS
export DATABASE_URL="postgresql+psycopg2://khonopro_user:khonopro_password@localhost:5432/khonopro"
```

### 3. Initialize Database

```bash
python setup_database.py
```

### 4. Start Backend

```bash
python -m uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

## 📱 Flutter Frontend Setup

### 1. Navigate to Flutter Directory

```bash
cd frontend_flutter
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Start Flutter App

```bash
flutter run -d chrome --web-port 3000
```

## 🧪 Alternative: SQLite for Development

If you prefer SQLite for development (easier setup):

### 1. Set Environment Variable

```bash
# Windows
set USE_SQLITE=true

# Linux/macOS
export USE_SQLITE=true
```

### 2. Run Setup

```bash
cd backend
python setup_database.py
```

This will create a `khonopro_client.db` file in your backend directory.

## 🔧 Configuration Files

### Database Configuration

The system automatically detects your setup:

- **PostgreSQL**: Uses `postgresql+psycopg2://...` connection
- **SQLite**: Uses `sqlite:///./khonopro_client.db` connection

### Connection Details

| Setting | PostgreSQL | SQLite |
|---------|------------|--------|
| Host | localhost | N/A |
| Port | 5432 | N/A |
| Database | khonopro | khonopro_client.db |
| Username | khonopro_user | N/A |
| Password | khonopro_password | N/A |

## 🚀 Testing the Setup

### 1. Test Backend

```bash
# Test health endpoint
curl http://localhost:8000/

# Test database connection
curl http://localhost:8000/api/status
```

### 2. Test Flutter App

1. Open `http://localhost:3000` in your browser
2. You should see the Flutter app loading

### 3. Test Client Dashboard

1. Send a proposal email (this creates a token)
2. Click the "Open Full Dashboard" link
3. You should be redirected to the Flutter client dashboard

## 🛠️ Troubleshooting

### PostgreSQL Issues

**Connection Refused:**
```bash
# Check if PostgreSQL is running
# Windows
net start postgresql-x64-15

# Linux/macOS
sudo systemctl status postgresql
# or
brew services list | grep postgresql
```

**Permission Denied:**
```sql
-- Grant proper permissions
GRANT ALL PRIVILEGES ON DATABASE khonopro TO khonopro_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO khonopro_user;
```

**Port Already in Use:**
```bash
# Find process using port 8000
netstat -ano | findstr :8000

# Kill the process (Windows)
taskkill /PID <PID> /F

# Kill the process (Linux/macOS)
kill -9 <PID>
```

### Flutter Issues

**Path Not Found:**
```bash
# Make sure you're in the correct directory
cd frontend_flutter
ls  # Should see pubspec.yaml
```

**Port 3000 in Use:**
```bash
# Use a different port
flutter run -d chrome --web-port 3001
```

### Python Issues

**Module Not Found:**
```bash
# Install missing dependencies
pip install -r requirements.txt

# Or install specific packages
pip install sqlalchemy psycopg2-binary
```

## 📊 Database Management

### Using psql (Command Line)

```bash
# Connect
psql -U khonopro_user -d khonopro

# List tables
\dt

# View table structure
\d clients

# Run queries
SELECT * FROM clients;

# Exit
\q
```

### Using pgAdmin (GUI)

1. Download pgAdmin from [pgadmin.org](https://www.pgadmin.org/)
2. Install and open pgAdmin
3. Add server:
   - Host: localhost
   - Port: 5432
   - Username: khonopro_user
   - Password: khonopro_password
4. Browse the `khonopro` database

## 🎯 Next Steps

1. ✅ Database setup complete
2. ✅ Backend running on port 8000
3. ✅ Flutter app running on port 3000
4. 🧪 Test the complete client dashboard flow
5. 📊 Monitor database performance
6. 🚀 Deploy to production

## 🔄 Development Workflow

```bash
# 1. Start PostgreSQL (if not running)
# Windows: net start postgresql-x64-15
# Linux/macOS: sudo systemctl start postgresql

# 2. Start backend
cd backend
python -m uvicorn app:app --host 127.0.0.1 --port 8000 --reload

# 3. Start Flutter (in new terminal)
cd frontend_flutter
flutter run -d chrome --web-port 3000

# 4. Test the application
# Open http://localhost:3000
```

---

**Need help?** Check the troubleshooting section or the main `DATABASE_SETUP.md` file for more details.
