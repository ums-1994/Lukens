"""
Utility script to inspect tables in the current database.

This uses the same database configuration as the main app
(`database_config.create_database_engine`), so when run on
Render it will connect to the Render Postgres instance.
"""

from sqlalchemy import text

from database_config import create_database_engine


def main() -> None:
    engine = create_database_engine()
    print("Connecting to database using:", engine.url)

    with engine.connect() as conn:
        result = conn.execute(
            text(
                """
                SELECT table_schema, table_name
                FROM information_schema.tables
                WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
                ORDER BY table_schema, table_name;
                """
            )
        )

        rows = list(result)
        print(f"\nFound {len(rows)} tables:\n")
        for schema, name in rows:
            print(f"- {schema}.{name}")


if __name__ == "__main__":
    main()

