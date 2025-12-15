#!/bin/bash
# Start script for Render deployment
# Handles finding the backend directory and running migration + server

set -e  # Exit on error

# Find backend directory
if [ -d "backend" ]; then
    BACKEND_DIR="backend"
elif [ -f "app.py" ]; then
    BACKEND_DIR="."
else
    echo "❌ Error: Cannot find backend directory or app.py"
    exit 1
fi

echo "📂 Using backend directory: $BACKEND_DIR"

# Run migration
echo "🔄 Running database migration..."
cd "$BACKEND_DIR"
python migrate_db.py
cd ..

# Start gunicorn
echo "🚀 Starting gunicorn server..."
cd "$BACKEND_DIR"
exec gunicorn -c gunicorn_conf.py -b 0.0.0.0:${PORT:-8000} app:app





