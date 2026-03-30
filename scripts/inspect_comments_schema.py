import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app import get_db_connection


def main() -> None:
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = 'document_comments'
            ORDER BY ordinal_position
            """
        )
        print("COLUMNS:")
        for row in cur.fetchall():
            print(row)

        cur.execute(
            """
            SELECT id, proposal_id, highlighted_text, start_offset, end_offset, block_id, section_index
            FROM document_comments
            ORDER BY id DESC
            LIMIT 10
            """
        )
        print("\nSAMPLE ROWS:")
        for row in cur.fetchall():
            print(row)


if __name__ == "__main__":
    main()
