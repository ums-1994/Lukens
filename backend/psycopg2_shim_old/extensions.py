"""
psycopg2.extensions shim for psycopg (v3).

Your code uses psycopg2.extensions mainly for:
  - STATUS_IN_TRANSACTION constant checks
and sometimes for exception/type checks.

We provide the minimal subset needed by your decorators.
"""

from __future__ import annotations
import psycopg

# Common exception aliases some code expects
Error = psycopg.Error
DatabaseError = psycopg.DatabaseError
OperationalError = psycopg.OperationalError
ProgrammingError = psycopg.ProgrammingError

# Minimal connection status constants (psycopg2-like)
STATUS_READY = 0
STATUS_BEGIN = 1
STATUS_IN_TRANSACTION = 2
STATUS_PREPARED = 3

# (Optional placeholders; harmless if unused)
ISOLATION_LEVEL_AUTOCOMMIT = 0
ISOLATION_LEVEL_READ_COMMITTED = 1
ISOLATION_LEVEL_REPEATABLE_READ = 2
ISOLATION_LEVEL_SERIALIZABLE = 3
