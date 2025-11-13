# Config Scripts

This directory contains configuration-related scripts and shims.

## Files

### `settings_shim.py` (LEGACY/UNUSED)

**Status**: ⚠️ **Not currently used**

This was a shim file that allowed importing `from settings import router` 
instead of `from backend.settings import router`. However:

- The backend uses **Flask**, not FastAPI
- `backend/settings.py` uses **FastAPI** (APIRouter)
- No code in the backend actually imports from this shim
- This appears to be legacy/unused code

**Recommendation**: 
- If you need settings functionality, use `backend.settings` directly
- This file can be safely removed if not needed
- Kept here for reference in case it's needed in the future

## Notes

- This directory is for configuration-related scripts
- Files here may be legacy or reference implementations
- Review before using in production

