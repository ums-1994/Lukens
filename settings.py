"""
Top-level settings shim so backend.app can `from settings import router`.
This file re-exports the router from the backend package settings module.
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
