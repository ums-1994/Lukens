# Backend (FastAPI) for Proposal & SOW Builder v2

Run:
```
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```
DB: Uses SQLite at `backend/content.db` for content library and a `storage.json` for proposals (simple demo).
