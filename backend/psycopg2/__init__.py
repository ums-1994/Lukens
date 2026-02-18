"""
Compatibility shim for environments where `psycopg2` can't be installed.

This repo historically used psycopg2. On Windows + Python 3.13, installing
`psycopg2-binary` often fails (no compatible wheel → tries to compile).

To keep the codebase working without large refactors, we provide a minimal
`psycopg2` API backed by psycopg (v3) when the real psycopg2 package is not
available.

If a real psycopg2 installation exists in site-packages, we prefer it.
"""

from __future__ import annotations

import importlib.machinery
import importlib.util
import os
import sys
from types import ModuleType
from typing import Any, Optional


def _try_load_real_psycopg2() -> Optional[ModuleType]:
    """
    Attempt to load the real `psycopg2` package from site-packages even though
    this shim shadows the name inside the repo.
    """
    this_dir = os.path.dirname(__file__)
    # Search sys.path excluding the directory that contains this shim.
    for p in sys.path:
        if not p:
            continue
        try:
            if os.path.samefile(p, os.path.dirname(this_dir)):
                continue
        except Exception:
            # If samefile fails (e.g., non-existent path), ignore.
            pass

        spec = importlib.machinery.PathFinder.find_spec("psycopg2", [p])
        if not spec or not spec.origin:
            continue
        # If it resolves back to this shim, skip.
        try:
            if os.path.samefile(os.path.dirname(spec.origin), this_dir):
                continue
        except Exception:
            pass

        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        # Ensure relative imports inside psycopg2 resolve to the real module,
        # not back to this shim.
        previous = sys.modules.get("psycopg2")
        sys.modules["psycopg2"] = module
        try:
            spec.loader.exec_module(module)
            return module
        except Exception:
            # Restore the shim and keep searching.
            if previous is not None:
                sys.modules["psycopg2"] = previous
            else:
                sys.modules.pop("psycopg2", None)
            continue

    return None


_real = _try_load_real_psycopg2()
if _real is not None:
    # Populate our module namespace with the real package's contents.
    globals().update(_real.__dict__)
    sys.modules[__name__] = _real
else:
    try:
        import psycopg as _psycopg  # type: ignore
        from psycopg import sql as sql  # noqa: F401
    except ModuleNotFoundError as exc:  # pragma: no cover
        raise ModuleNotFoundError(
            "Neither `psycopg2` nor `psycopg` is installed.\n\n"
            "On Python 3.13+ install psycopg v3:\n"
            "  pip install \"psycopg[binary]\"\n\n"
            "Or use Python 3.11/3.12 and install psycopg2-binary:\n"
            "  pip install psycopg2-binary\n"
        ) from exc

    # Re-export common DB-API exceptions under psycopg2 names.
    OperationalError = _psycopg.OperationalError
    InterfaceError = _psycopg.InterfaceError
    DatabaseError = _psycopg.DatabaseError
    Error = _psycopg.Error

    # Provide `extensions`, `extras`, and `pool` submodules.
    from . import extensions as extensions  # noqa: F401
    from . import extras as extras  # noqa: F401
    from . import pool as pool  # noqa: F401


    class _ConnectionProxy:
        """
        Wrap psycopg3 connection to provide psycopg2-ish attributes used here.
        """

        def __init__(self, conn: Any):
            self._conn = conn

        def __getattr__(self, name: str) -> Any:
            return getattr(self._conn, name)

        @property
        def status(self) -> int:
            # psycopg2: STATUS_READY=1, STATUS_IN_TRANSACTION=2 (we emulate these)
            try:
                info = getattr(self._conn, "info", None)
                ts = getattr(info, "transaction_status", None) if info else None
                if ts is None:
                    pgconn = getattr(self._conn, "pgconn", None)
                    ts = getattr(pgconn, "transaction_status", None) if pgconn else None
                if ts is None:
                    return extensions.STATUS_READY
                name = getattr(ts, "name", str(ts))
                if "INTRANS" in name or "IN_TRANSACTION" in name:
                    return extensions.STATUS_IN_TRANSACTION
                return extensions.STATUS_READY
            except Exception:
                return extensions.STATUS_READY

        @property
        def isolation_level(self) -> Any:
            # Best-effort for logging only (used in decorators.py).
            v = getattr(self._conn, "isolation_level", None)
            if v is not None:
                return v
            info = getattr(self._conn, "info", None)
            return getattr(info, "transaction_isolation", None) if info else None

        def cursor(self, *args: Any, **kwargs: Any) -> Any:
            """
            Support psycopg2-style cursor_factory=RealDictCursor.
            """
            cursor_factory = kwargs.pop("cursor_factory", None)
            if cursor_factory is not None:
                from .extras import RealDictCursor, _DICT_ROW_FACTORY

                if cursor_factory is RealDictCursor or isinstance(cursor_factory, type) and cursor_factory.__name__ == "RealDictCursor":
                    kwargs["row_factory"] = _DICT_ROW_FACTORY
            return self._conn.cursor(*args, **kwargs)

        # psycopg2 supports using connection as context manager sometimes;
        # keep parity with psycopg3.
        def __enter__(self) -> "_ConnectionProxy":
            self._conn.__enter__()
            return self

        def __exit__(self, exc_type, exc, tb) -> Any:
            return self._conn.__exit__(exc_type, exc, tb)


    def connect(*args: Any, **kwargs: Any) -> _ConnectionProxy:
        """
        psycopg2.connect() compatible wrapper around psycopg.connect().

        Accepts `database` as an alias for `dbname`.
        """
        if "database" in kwargs and "dbname" not in kwargs:
            kwargs["dbname"] = kwargs.pop("database")
        conn = _psycopg.connect(*args, **kwargs)
        return _ConnectionProxy(conn)


    __all__ = [
        "connect",
        "OperationalError",
        "InterfaceError",
        "DatabaseError",
        "Error",
        "extensions",
        "extras",
        "pool",
    ]

