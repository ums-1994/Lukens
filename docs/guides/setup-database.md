# PostgreSQL Database Setup Guide

## Option 1: Using Docker (Recommended)

### 1. Install Docker Desktop
- Download from [docker.com](https://www.docker.com/products/docker-desktop/)
- Install and start Docker Desktop

### 2. Run PostgreSQL with Docker
```bash
# Create a Docker network
docker network create proposal-network

# Run PostgreSQL container
docker run --name proposal-postgres \
  --network proposal-network \
  -e POSTGRES_DB=proposal_sow_builder \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password123 \
  -p 5432:5432 \
  -d postgres:15

# Verify container is running
docker ps
```

### 3. Connect to Database and Run Schema
```bash
# Connect to the database
docker exec -it proposal-postgres psql -U postgres -d proposal_sow_builder

# Run the schema (copy and paste the contents of database/schema.sql)
# Or run it from file:
docker exec -i proposal-postgres psql -U postgres -d proposal_sow_builder < database/schema.sql
```

## Option 2: Local PostgreSQL Installation

### 1. Install PostgreSQL
- Download from [postgresql.org](https://www.postgresql.org/download/windows/)
- Install with default settings
- Remember the password you set for the 'postgres' user

### 2. Create Database
```sql
-- Connect to PostgreSQL as superuser
psql -U postgres

-- Create database
CREATE DATABASE proposal_sow_builder;

-- Create user (optional)
CREATE USER proposal_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE proposal_sow_builder TO proposal_user;

-- Exit psql
\q
```

### 3. Run Schema
```bash
# Run the schema file
psql -U postgres -d proposal_sow_builder -f database/schema.sql
```

## Option 3: Using PostgreSQL with pgAdmin

### 1. Install pgAdmin
- Download from [pgadmin.org](https://www.pgadmin.org/download/)
- Install and open pgAdmin

### 2. Create Database
- Right-click "Databases" → "Create" → "Database"
- Name: `proposal_sow_builder`
- Click "Save"

### 3. Run Schema
- Right-click the new database → "Query Tool"
- Copy and paste the contents of `database/schema.sql`
- Click "Execute" (F5)

## Environment Configuration

### 1. Copy Environment File
```bash
cp env.example .env
```

### 2. Update .env with your database credentials
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=proposal_sow_builder
DB_USER=postgres
DB_PASSWORD=your_password_here
```

## Test Database Connection

### 1. Start the API server
```bash
npm run dev
```

### 2. Test health endpoint
```bash
curl http://localhost:3000/health
```

### 3. Check database connection in logs
You should see: "Connected to PostgreSQL database"

## Troubleshooting

### Connection Refused
- Make sure PostgreSQL is running
- Check if port 5432 is available
- Verify credentials in .env file

### Authentication Failed
- Check username and password
- Make sure the user has proper permissions

### Database Not Found
- Make sure the database exists
- Run the schema.sql file

### Docker Issues
- Make sure Docker Desktop is running
- Check if port 5432 is already in use
- Try: `docker logs proposal-postgres` for error details
