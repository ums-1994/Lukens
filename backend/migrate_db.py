#!/usr/bin/env python3
"""
Non-interactive database migration script
Automatically runs migration to ensure all tables are up to date
"""
import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def _build_db_config_from_env():
    """
    Build a psycopg2.connect()-compatible config from either:
    - DATABASE_URL (preferred), or
    - DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD

    This keeps migrations consistent with the runtime app, and prevents Render
    deployments from accidentally falling back to localhost when only DATABASE_URL
    is set.
    """
    database_url = os.getenv("DATABASE_URL")
    if database_url:
        from urllib.parse import urlparse, parse_qs

        parsed = urlparse(database_url)
        scheme = (parsed.scheme or "").lower()
        if scheme.startswith("postgresql+"):
            scheme = "postgresql"
        if scheme not in ("postgres", "postgresql"):
            raise ValueError(
                "DATABASE_URL must start with postgres:// or postgresql:// "
                "(optionally with a driver like postgresql+psycopg2://)"
            )

        db_config = {
            "host": parsed.hostname,
            "database": (parsed.path or "").lstrip("/"),
            "user": parsed.username,
            "password": parsed.password,
            "port": parsed.port or 5432,
        }

        query = parse_qs(parsed.query or "")
        sslmode_from_url = (query.get("sslmode") or [None])[0]

        ssl_mode = sslmode_from_url or os.getenv("DB_SSLMODE")
        if not ssl_mode:
            if os.getenv("DB_REQUIRE_SSL", "false").lower() == "true":
                ssl_mode = "require"
            elif db_config.get("host") and "render.com" in (db_config["host"] or "").lower():
                ssl_mode = "require"
            else:
                ssl_mode = "prefer"

        if ssl_mode:
            db_config["sslmode"] = ssl_mode

        missing = [k for k in ("host", "database", "user") if not db_config.get(k)]
        if missing:
            raise ValueError(f"DATABASE_URL missing required parts: {', '.join(missing)}")

        return db_config

    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432")),
        "database": os.getenv("DB_NAME", "proposal_sow_builder"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", ""),
        "sslmode": os.getenv("DB_SSLMODE", "prefer"),
    }

def run_migration():
    """Run the database schema migration"""
    print("=" * 60)
    print("🔄 RUNNING DATABASE MIGRATION")
    print("=" * 60)
    db_config = _build_db_config_from_env()
    print(
        "🔗 Connecting to: "
        f"{db_config.get('host')}:{db_config.get('port')}/{db_config.get('database')}"
    )
    if db_config.get("sslmode"):
        print(f"🔒 SSL mode: {db_config.get('sslmode')}")
    
    try:
        # Import the schema initialization function
        # Handle being run from root directory (backend/migrate_db.py) or backend directory (migrate_db.py)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if script_dir not in sys.path:
            sys.path.insert(0, script_dir)
        
        # Change to backend directory for proper imports
        os.chdir(script_dir)
        
        from api.utils.database import init_pg_schema
        
        print("\n📋 Initializing PostgreSQL schema...")
        print("   (This will create any missing tables/columns)")
        init_pg_schema()
        print("\n✅ Schema migration completed successfully!")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error running migration: {e}")
        import traceback
        traceback.print_exc()
        return False


def check_tables():
    """Quick check of tables after migration"""
    try:
        import psycopg2

        db_config = _build_db_config_from_env()
        conn = psycopg2.connect(**db_config)
        
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        """)
        
        existing_tables = [row[0] for row in cursor.fetchall()]
        
        print(f"\n📊 Database now has {len(existing_tables)} tables")
        print("   Key tables:")
        key_tables = ['users', 'proposals', 'content', 'notifications', 'clients']
        for table in key_tables:
            if table in existing_tables:
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    print(f"   ✅ {table}: {count} rows")
                except:
                    print(f"   ✅ {table}: exists")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"⚠️  Could not verify tables: {e}")


def main():
    """Main function"""
    print("\n" + "=" * 60)
    print("🗄️  DATABASE MIGRATION TOOL")
    print("=" * 60)
    
    if run_migration():
        check_tables()
        print("\n" + "=" * 60)
        print("✅ MIGRATION COMPLETED SUCCESSFULLY")
        print("=" * 60)
        return 0
    else:
        print("\n" + "=" * 60)
        print("❌ MIGRATION FAILED")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())

