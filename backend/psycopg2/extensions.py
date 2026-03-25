"""
Minimal psycopg2.extensions surface used by this repo.

Only constants accessed in the codebase are provided.
"""

# psycopg2 connection status codes (subset)
STATUS_READY = 1
STATUS_IN_TRANSACTION = 2

__all__ = ["STATUS_READY", "STATUS_IN_TRANSACTION"]

