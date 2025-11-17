"""
Firestore configuration
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Firestore configuration
USE_FIRESTORE = os.getenv('USE_FIRESTORE', 'false').lower() == 'true'
FIRESTORE_DATABASE_ID = os.getenv('FIRESTORE_DATABASE_ID', '(default)')

# Database selection helper
def get_database_type():
    """Get the database type to use"""
    return 'firestore' if USE_FIRESTORE else 'postgresql'

