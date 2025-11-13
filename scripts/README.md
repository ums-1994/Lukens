# Scripts Directory

This directory contains utility scripts for the ProposalHub application, organized by purpose.

## Directory Structure

```
scripts/
├── setup/          # Setup and initialization scripts
├── utils/          # Utility scripts for database management
├── fixes/          # One-time fix scripts (may be outdated)
├── config/         # Configuration-related scripts (legacy/unused)
└── README.md       # This file
```

## Setup Scripts (`setup/`)

Scripts for setting up and starting the application:

- **`setup_backend.py`** - Automated backend setup (installs dependencies, etc.)
- **`setup_postgres.py`** - PostgreSQL database setup
- **`start_python_backend.py`** - Start the Python backend server

### Usage

```bash
# Setup backend
python scripts/setup/setup_backend.py

# Start backend server
python scripts/setup/start_python_backend.py
```

## Utility Scripts (`utils/`)

Database and system utility scripts:

- **`delete_users.py`** - Delete all users from database (use with caution!)
- **`check_content_db.py`** - Check content database structure
- **`remove_sqlite_final.py`** - Remove SQLite database files

### Usage

```bash
# Check content database
python scripts/utils/check_content_db.py

# Delete all users (WARNING: destructive!)
python scripts/utils/delete_users.py
```

## Fix Scripts (`fixes/`)

One-time fix scripts that were used to resolve specific issues. These may be outdated:

- **`fix_app_py.py`** - Fix for app.py truncation issue
- **`fix_indentation.py`** - Fix indentation issues
- **`fix_users_table.py`** - Fix users table structure
- **`final_indent_fix.py`** - Final indentation fix
- **`DOCUSIGN_COPYPASTE_FIX.py`** - DocuSign copy-paste fix

### Note

These fix scripts were created to resolve specific issues and may no longer be needed. They are kept for reference but should be reviewed before use.

## Running Scripts

All scripts should be run from the **project root directory**:

```bash
# From project root
python scripts/setup/start_python_backend.py
python scripts/utils/check_content_db.py
```

## Configuration Scripts (`config/`)

Legacy configuration and shim files:

- **`settings_shim.py`** - Legacy settings shim (unused, kept for reference)

### Note

The `config/` directory contains legacy/unused files that are kept for reference but are not actively used in the application.

## Notes

- Scripts use relative paths to find the backend directory
- Some scripts may require environment variables to be set
- Database utility scripts may require database credentials
- Always review scripts before running, especially destructive ones
- Config scripts are legacy and may not be functional

