#!/usr/bin/env python3
"""
Apply the email verification database migration.
"""
import sys
from pathlib import Path
from api.utils.database import get_db_connection


def apply_sql_file(sql_path: Path) -> None:
	"""Execute a .sql file against the configured PostgreSQL database."""
	if not sql_path.exists():
		raise FileNotFoundError(f"SQL file not found: {sql_path}")
	sql_text = sql_path.read_text(encoding="utf-8")
	with get_db_connection() as conn:
		cursor = conn.cursor()
		cursor.execute(sql_text)
		conn.commit()


def main() -> None:
	try:
		root = Path(__file__).parent
		sql_file = root / "create_email_verification_tables.sql"
		print(f"Applying migration: {sql_file}")
		apply_sql_file(sql_file)
		print("Migration applied successfully.")
	except Exception as e:
		print(f"Error applying migration: {e}")
		sys.exit(1)


if __name__ == "__main__":
	main()


