"""
Minimal psycopg2.pool surface used by this repo.

The codebase expects:
  psycopg2.pool.SimpleConnectionPool(minconn, maxconn, **db_config)
with methods:
  - getconn()
  - putconn(conn)

We implement a very small in-process pool suitable for local/dev usage.
"""

from __future__ import annotations

import threading
from typing import Any, Dict, List, Optional


class SimpleConnectionPool:
    def __init__(self, minconn: int, maxconn: int, **conn_kwargs: Any):
        if minconn < 0 or maxconn <= 0 or minconn > maxconn:
            raise ValueError("Invalid minconn/maxconn for SimpleConnectionPool")

        self._minconn = minconn
        self._maxconn = maxconn
        self._conn_kwargs = dict(conn_kwargs)
        self._lock = threading.Lock()
        self._pool: List[Any] = []
        self._in_use = 0

        # Pre-create min connections.
        for _ in range(self._minconn):
            self._pool.append(self._new_conn())

    def _new_conn(self) -> Any:
        from . import connect

        return connect(**self._conn_kwargs)

    def getconn(self) -> Any:
        with self._lock:
            if self._pool:
                self._in_use += 1
                return self._pool.pop()
            if self._in_use < self._maxconn:
                self._in_use += 1
                return self._new_conn()
            raise RuntimeError("No available connections in pool")

    def putconn(self, conn: Any) -> None:
        with self._lock:
            try:
                # If connection seems closed, don't re-pool it.
                closed = getattr(conn, "closed", False)
                if callable(closed):
                    closed = closed()
            except Exception:
                closed = False

            if closed:
                try:
                    conn.close()
                except Exception:
                    pass
                self._in_use = max(0, self._in_use - 1)
                return

            self._pool.append(conn)
            self._in_use = max(0, self._in_use - 1)

    def closeall(self) -> None:
        with self._lock:
            for conn in self._pool:
                try:
                    conn.close()
                except Exception:
                    pass
            self._pool.clear()


__all__ = ["SimpleConnectionPool"]

