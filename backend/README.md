# Backend (FastAPI) for Proposal & SOW Builder v2

Run:
```
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```
DB: Uses PostgreSQL for proposals and main data storage. SQLite at `backend/content.db` for content library.
