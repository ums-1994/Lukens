"""
Database configuration for KhonoPro Proposal System
"""
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from models_client import Base

# Load environment variables from .env file
load_dotenv()

# Database URL configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    f"postgresql+psycopg2://{os.getenv('DB_USER', 'postgres')}:{os.getenv('DB_PASSWORD', 'Password123')}@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'proposal_sow_builder')}"
)

# For development, you can also use SQLite as fallback
SQLITE_URL = "sqlite:///./khonopro_client.db"

def get_database_url():
    """Get the appropriate database URL based on environment"""
    if os.getenv("USE_SQLITE", "false").lower() == "true":
        return SQLITE_URL
    return DATABASE_URL

def create_database_engine():
    """Create database engine with appropriate configuration"""
    database_url = get_database_url()
    
    if "sqlite" in database_url:
        # SQLite configuration
        engine = create_engine(
            database_url,
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
    else:
        # PostgreSQL configuration
        engine = create_engine(
            database_url,
            pool_pre_ping=True,
            pool_recycle=300,
        )
    
    return engine

def create_tables():
    """Create all tables in the database"""
    engine = create_database_engine()
    Base.metadata.create_all(bind=engine)
    return engine

def get_session():
    """Get database session"""
    engine = create_database_engine()
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return SessionLocal()

# Dependency for FastAPI
def get_db():
    """FastAPI dependency for database sessions"""
    db = get_session()
    try:
        yield db
    finally:
        db.close()
