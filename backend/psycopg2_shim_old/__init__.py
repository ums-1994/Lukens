"""
A small compatibility shim for projects that still import `psycopg2`
but run on Python versions where `psycopg2-binary` wheels may not exist (e.g. 3.13).

It adapts a subset of the psycopg2 API to psycopg (v3):
  - psycopg2.connect(...)
  - psycopg2.InterfaceError / IntegrityError / OperationalError / Error
  - psycopg2.extras.RealDictCursor (accepted as cursor_factory=...)
  - psycopg2.pool.SimpleConnectionPool (getconn/putconn/closeall)
  - connection.status + STATUS_IN_TRANSACTION checks (used in your decorators)

This is NOT a full psycopg2 implementation—only what this codebase needs.
"""

from __future__ import annotations

from typing import Any
import psycopg
from psycopg import errors as _errors

# Export common error base classes
Error = psycopg.Error
DatabaseError = psycopg.DatabaseError
OperationalError = psycopg.OperationalError
ProgrammingError = psycopg.ProgrammingError

# Match common psycopg2 exceptions used in code
IntegrityError = getattr(_errors, "IntegrityError", psycopg.Error)
InterfaceError = getattr(_errors, "InterfaceError", psycopg.Error)


class _ConnectionWrapper:
    """Wrap psycopg.Connection to accept psycopg2-style cursor_factory and .status."""

    def __init__(self, conn: psycopg.Connection):
        self._conn = conn

    def __getattr__(self, name: str) -> Any:
        return getattr(self._conn, name)

    def cursor(self, *args: Any, **kwargs: Any):
        # psycopg2 style: cursor_factory=psycopg2.extras.RealDictCursor
        cursor_factory = kwargs.pop("cursor_factory", None)
        if cursor_factory is extras.RealDictCursor:
            # psycopg v3 uses row_factory instead
            kwargs.setdefault("row_factory", psycopg.rows.dict_row)
        return self._conn.cursor(*args, **kwargs)

    @property
    def status(self) -> int:
        """
        psycopg2 has connection.status + STATUS_IN_TRANSACTION checks.
        psycopg v3 uses conn.info.transaction_status.
        We map it to a psycopg2-like status int using our extensions shim.
        """
        try:
            from . import extensions  # local shim providing STATUS_* constants

            tx = self._conn.info.transaction_status
            # psycopg tx statuses: IDLE, INTRANS, INERROR, UNKNOWN
            if tx in (
                psycopg.pq.TransactionStatus.INTRANS,
                psycopg.pq.TransactionStatus.INERROR,
            ):
                return extensions.STATUS_IN_TRANSACTION
            return extensions.STATUS_READY
        except Exception:
            return 0

    def close(self) -> None:
        return self._conn.close()


def connect(*args: Any, **kwargs: Any) -> _ConnectionWrapper:
    """psycopg2.connect compatible wrapper returning a connection supporting cursor_factory."""
    return _ConnectionWrapper(psycopg.connect(*args, **kwargs))


# Import these AFTER _ConnectionWrapper exists (avoids circular import issues)
from . import extras  # noqa: E402
from . import pool    # noqa: E402
