"""
psycopg2.pool shim backed by psycopg_pool.ConnectionPool.

Supports both psycopg2 call styles:
  1) SimpleConnectionPool(minconn, maxconn, dsn="postgresql://...")

  2) SimpleConnectionPool(minconn, maxconn, host=..., port=..., user=..., password=..., dbname=... / database=...)
"""

from __future__ import annotations

from typing import Any, Optional
from urllib.parse import quote_plus

from psycopg_pool import ConnectionPool as _ConnectionPool

from . import _ConnectionWrapper


class PoolError(Exception):
    pass


def _build_dsn_from_kwargs(kwargs: dict[str, Any]) -> str:
    host = kwargs.get("host", "localhost")
    port = kwargs.get("port", 5432)

    user = kwargs.get("user") or kwargs.get("username") or ""
    password = kwargs.get("password") or ""
    dbname = kwargs.get("dbname") or kwargs.get("database") or kwargs.get("db") or ""

    # Prefer explicit dsn if provided
    if "dsn" in kwargs and kwargs["dsn"]:
        return str(kwargs["dsn"])

    auth = ""
    if user:
        if password:
            auth = f"{quote_plus(str(user))}:{quote_plus(str(password))}@"
        else:
            auth = f"{quote_plus(str(user))}@"

    return f"postgresql://{auth}{host}:{port}/{dbname}"


class SimpleConnectionPool:
    def __init__(self, minconn: int, maxconn: int, dsn: Optional[str] = None, *args: Any, **kwargs: Any):
        # Accept dsn positional (3rd arg) or keyword, OR build from kwargs.
        conninfo = dsn or kwargs.pop("dsn", None)
        if not conninfo:
            conninfo = _build_dsn_from_kwargs(kwargs)

        self._pool = _ConnectionPool(conninfo=str(conninfo), min_size=minconn, max_size=maxconn)

    def getconn(self) -> _ConnectionWrapper:
        try:
            conn = self._pool.getconn()
            return _ConnectionWrapper(conn)
        except Exception as e:
            raise PoolError(str(e)) from e

    def putconn(self, conn: Any, close: bool = False) -> None:
        try:
            raw = conn._conn if isinstance(conn, _ConnectionWrapper) else conn
            # psycopg_pool.ConnectionPool.putconn() doesn't accept close=
            self._pool.putconn(raw)
        except Exception as e:
            raise PoolError(str(e)) from e

    def closeall(self) -> None:
        self._pool.close()
