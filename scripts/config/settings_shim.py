"""
Top-level settings shim (LEGACY/UNUSED)

This file was originally meant to allow `from settings import router` 
instead of `from backend.settings import router`, but it appears to be unused.

The backend uses Flask, while backend/settings.py uses FastAPI, so this shim
may not be functional. This file has been moved to scripts/config/ for reference.

If you need to use backend settings, import directly from backend.settings instead.
"""
try:
    from backend.settings import router  # type: ignore
except Exception:
    # Fallback: provide a minimal router if backend.settings is not available
    from fastapi import APIRouter
    router = APIRouter()

    @router.get('/ping')
    def _ping():
        return {'status': 'ok', 'source': 'shim'}
