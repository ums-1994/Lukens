"""
Minimal psycopg2.extras surface used by this repo.

The codebase primarily uses RealDictCursor via:
  conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

In psycopg (v3) this is achieved via `row_factory=psycopg.rows.dict_row`.
"""

from __future__ import annotations

from typing import Any, Callable


try:
    from psycopg.rows import dict_row as _DICT_ROW_FACTORY  # type: ignore
except Exception:  # pragma: no cover
    _DICT_ROW_FACTORY = None  # type: ignore


class RealDictCursor:  # marker class for cursor_factory checks
    pass


def _ensure_available() -> None:
    if _DICT_ROW_FACTORY is None:
        raise RuntimeError(
            "psycopg row factories are unavailable. Install psycopg v3:\n"
            "  pip install \"psycopg[binary]\""
        )


def real_dict_cursor_kwargs() -> dict[str, Any]:
    _ensure_available()
    return {"row_factory": _DICT_ROW_FACTORY}


__all__ = ["RealDictCursor"]

