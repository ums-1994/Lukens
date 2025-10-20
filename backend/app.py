from fastapi import FastAPI, HTTPException, Body, Query, Depends, status, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, Field, EmailStr, field_validator, ValidationError
from typing import List, Optional, Dict, Any, Literal
import json, os, uuid, time, sqlite3
from datetime import datetime, timedelta
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
import io
from fastapi.responses import StreamingResponse, HTMLResponse
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
import secrets
import psycopg2
import psycopg2.extras
import tempfile
from contextlib import contextmanager
from settings import router as settings_router
from dotenv import load_dotenv
from cloudinary_config import upload_to_cloudinary

# Load environment variables
load_dotenv()

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, "storage.json")
SQLITE_PATH = os.path.join(BASE_DIR, "content.db")
USERS_DB_PATH = os.path.join(BASE_DIR, "users.json")
VERIFICATION_TOKENS_PATH = os.path.join(BASE_DIR, "verification_tokens.json")

# PostgreSQL Database Configuration
PG_HOST = os.getenv("DB_HOST", "localhost")
PG_PORT = int(os.getenv("DB_PORT", 5432))
PG_NAME = os.getenv("DB_NAME", "proposal_sow_builder")
PG_USER = os.getenv("DB_USER", "postgres")
PG_PASSWORD = os.getenv("DB_PASSWORD", "Password123")

@contextmanager
def _pg_conn():
    """Context manager for PostgreSQL connections"""
    conn = psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        database=PG_NAME,
        user=PG_USER,
        password=PG_PASSWORD
    )
    try:
        yield conn
    finally:
        conn.close()

def init_pg_content_table():
    """Initialize content_blocks table in PostgreSQL"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                CREATE TABLE IF NOT EXISTS content_blocks (
                    id SERIAL PRIMARY KEY,
                    key TEXT UNIQUE NOT NULL,
                    label TEXT NOT NULL,
                    content TEXT,
                    category TEXT DEFAULT 'Templates',
                    is_folder BOOLEAN DEFAULT FALSE,
                    parent_id INTEGER REFERENCES content_blocks(id) ON DELETE CASCADE,
                    public_id TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """)
                conn.commit()
                # Add category column if it doesn't exist (for existing tables)
                cur.execute("""
                    ALTER TABLE content_blocks ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Templates'
                """)
                conn.commit()
                # Update existing NULL categories to default 'Templates'
                cur.execute("""
                    UPDATE content_blocks SET category = 'Templates' WHERE category IS NULL
                """)
                conn.commit()
                # Add public_id column if it doesn't exist
                cur.execute("""
                    ALTER TABLE content_blocks ADD COLUMN IF NOT EXISTS public_id TEXT
                """)
                conn.commit()
        print("✓ PostgreSQL content_blocks table initialized")
    except Exception as e:
        print(f"✗ Error initializing PostgreSQL: {e}")

# Authentication settings
SECRET_KEY = "your-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Email configuration
MAIL_USERNAME = "umsibanda.1994@gmail.com"
MAIL_PASSWORD = "aozi xfgg mdcn ylae"
MAIL_FROM = "umsibanda.1994@gmail.com"
MAIL_PORT = 587
MAIL_SERVER = "smtp.gmail.com"
MAIL_FROM_NAME = "Proposal & SOW Builder"

# Email configuration
conf = ConnectionConfig(
    MAIL_USERNAME=MAIL_USERNAME,
    MAIL_PASSWORD=MAIL_PASSWORD,
    MAIL_FROM=MAIL_FROM,
    MAIL_PORT=MAIL_PORT,
    MAIL_SERVER=MAIL_SERVER,
    MAIL_FROM_NAME=MAIL_FROM_NAME,
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def now_iso() -> str:
    return datetime.utcnow().isoformat() + "Z"

# ---------- Authentication Functions ----------
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def load_users():
    if not os.path.exists(USERS_DB_PATH):
        with open(USERS_DB_PATH, "w", encoding="utf-8") as f:
            json.dump({"users": []}, f, indent=2)
    with open(USERS_DB_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_users(users_data):
    with open(USERS_DB_PATH, "w", encoding="utf-8") as f:
        json.dump(users_data, f, indent=2)

def load_verification_tokens():
    if not os.path.exists(VERIFICATION_TOKENS_PATH):
        with open(VERIFICATION_TOKENS_PATH, "w", encoding="utf-8") as f:
            json.dump({"tokens": []}, f, indent=2)
    with open(VERIFICATION_TOKENS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_verification_tokens(tokens_data):
    with open(VERIFICATION_TOKENS_PATH, "w", encoding="utf-8") as f:
        json.dump(tokens_data, f, indent=2)

def generate_verification_token():
    return secrets.token_urlsafe(32)

async def send_verification_email(email: str, token: str):
    verification_url = f"http://localhost:8000/?verify=true&token={token}"
    
    message = MessageSchema(
        subject="Verify Your Email - Proposal & SOW Builder",
        recipients=[email],
        body=f"""
        <html>
        <body>
            <h2>Welcome to Proposal & SOW Builder!</h2>
            <p>Thank you for registering. Please click the link below to verify your email address:</p>
            <p><a href="{verification_url}" style="background-color: #3498DB; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Verify Email</a></p>
            <p>Or copy and paste this link into your browser:</p>
            <p>{verification_url}</p>
            <p>This link will expire in 24 hours.</p>
            <p>If you didn't create an account, please ignore this email.</p>
        </body>
        </html>
        """,
        subtype=MessageType.html
    )
    
    fm = FastMail(conf)
    await fm.send_message(message)

def get_user(username: str):
    users_data = load_users()
    for user in users_data["users"]:
        if user["username"] == username:
            return user
    return None

def authenticate_user(username: str, password: str):
    user = get_user(username)
    if not user:
        return False
    if not verify_password(password, user["hashed_password"]):
        return False
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = get_user(username)
    if user is None:
        raise credentials_exception
    return user

def init_sqlite():
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS content_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE,
        label TEXT,
        content TEXT,
        is_folder BOOLEAN DEFAULT 0,
        parent_id INTEGER,
        created_at TEXT,
        updated_at TEXT
    )
    """)
    
    # Migrate existing table to add missing columns
    cur.execute("PRAGMA table_info(content_blocks)")
    columns = {row[1] for row in cur.fetchall()}
    
    if "is_folder" not in columns:
        cur.execute("ALTER TABLE content_blocks ADD COLUMN is_folder BOOLEAN DEFAULT 0")
    if "parent_id" not in columns:
        cur.execute("ALTER TABLE content_blocks ADD COLUMN parent_id INTEGER")
    
    conn.commit()
    conn.close()

def load_db():
    if not os.path.exists(DB_PATH):
        with open(DB_PATH, "w", encoding="utf-8") as f:
            json.dump({"proposals": [], "templates": []}, f, indent=2)
    with open(DB_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_db(db):
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)

# Initialize PostgreSQL and seed content blocks
init_pg_content_table()

def seed_pg_content_blocks():
    """Seed default content blocks into PostgreSQL"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM content_blocks")
                if cur.fetchone()[0] == 0:
                    blocks = [
                        ("company_profile","Company Profile","Khonology is a specialist consultancy focused on data and AI.", False, None),
                        ("capabilities","Capabilities","Data, AI, Cloud, Advisory.", False, None),
                        ("delivery_approach","Delivery Approach","Agile, Iterative, Outcome-driven.", False, None),
                        ("assumptions","Assumptions","Client provides timely access to stakeholders and data.", False, None),
                        ("risks","Risks","Potential scope creep; third-party dependencies.", False, None),
                        ("references","References","Case studies: Project A — improved X by 40%.", False, None),
                        ("bios","Team Bios","Jane Doe (Lead) — 10 years in data projects.", False, None),
                        ("terms","Terms","Standard Khonology terms and conditions.", False, None)
                    ]
                    cur.executemany(
                        "INSERT INTO content_blocks (key, label, content, is_folder, parent_id) VALUES (%s,%s,%s,%s,%s)",
                        blocks
                    )
                    conn.commit()
                    print("✓ Default content blocks seeded")
    except Exception as e:
        print(f"✗ Error seeding content blocks: {e}")

# seed_pg_content_blocks()  # Disabled: remove seeded content

# ---------- Data Models ----------
Status = Literal["Draft","Pending CEO Approval","Rejected","Approved","Sent to Client","Client Viewing","Signed","Declined by Client","Archived"]
Stage = Literal["Delivery","Legal","Exec"]
DocType = Literal["Proposal","SOW","RFI"]

class ApprovalState(BaseModel):
    mode: Literal["sequential","parallel"] = "sequential"
    order: List[Stage] = ["Delivery","Legal","Exec"]
    approvals: Dict[Stage, Dict[str, Any]] = {}

class Proposal(BaseModel):
    id: str
    title: str
    client: str
    dtype: DocType = "Proposal"
    status: Status = "Draft"
    sections: Dict[str, Any] = {}
    mandatory_sections: List[str] = ["Executive Summary","Scope & Deliverables","Delivery Approach","Assumptions","Risks","References","Team Bios"]
    created_at: str = Field(default_factory=now_iso)
    updated_at: str = Field(default_factory=now_iso)
    approval: ApprovalState = Field(default_factory=ApprovalState)
    readiness_score: float = 0.0
    readiness_issues: List[str] = []
    signed_at: Optional[str] = None
    signed_by: Optional[str] = None
    # RBAC fields
    creator_id: Optional[str] = None
    current_approver_role: Optional[str] = None  # "CEO" when awaiting CEO approval
    approval_history: List[Dict[str, Any]] = []  # Track all approvals/rejections
    financial_data: Optional[Dict[str, Any]] = None  # Pricing, margins, etc.
    client_actions: Optional[Dict[str, Any]] = None  # Sent time, viewed time, signed time

class ProposalCreate(BaseModel):
    title: str
    client: str
    dtype: DocType = "Proposal"
    template_key: Optional[str] = None

class ProposalUpdate(BaseModel):
    title: Optional[str] = None
    client: Optional[str] = None
    sections: Optional[Dict[str, Any]] = None
    dtype: Optional[DocType] = None

class ContentBlockIn(BaseModel):
    key: str
    label: str
    content: str
    category: str = "Templates"
    is_folder: bool = False
    parent_id: Optional[int] = None

class ContentBlockOut(BaseModel):
    id: int
    key: str
    label: str
    content: str
    category: str
    is_folder: bool
    parent_id: Optional[int]
    created_at: str
    updated_at: str

class SignPayload(BaseModel):
    signer_name: str

# ---------- Authentication Models ----------
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    full_name: str
    role: Literal["CEO", "Financial Manager", "Client"] = "Financial Manager"

    @field_validator("password")
    @classmethod
    def strong_password(cls, v: str):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must include an uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must include a number")
        if not any(c in "!@#$%^&*(),.?\":{}|<>_-[]\\/`~+=;'" for c in v):
            raise ValueError("Password must include a special character")
        return v

class UserLogin(BaseModel):
    username: str
    password: str

class EmailLogin(BaseModel):
    email: EmailStr
    password: str

class User(BaseModel):
    id: str
    username: str
    email: str
    full_name: str
    role: str
    is_active: bool = True
    is_verified: bool = False
    created_at: str
    updated_at: str

class UserInDB(User):
    hashed_password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class EmailVerification(BaseModel):
    token: str

class VerificationResponse(BaseModel):
    message: str
    verified: bool

class TokenData(BaseModel):
    username: Optional[str] = None

class SendProposalEmailRequest(BaseModel):
    to: List[EmailStr]
    cc: Optional[List[EmailStr]] = None
    subject: str
    body: str
    include_dashboard_link: bool = True
    include_pdf: bool = False
    proposal_data: Optional[Dict[str, Any]] = None

# ---------- App ----------
app = FastAPI(title="Proposal & SOW Builder API v2", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include settings router
app.include_router(settings_router, prefix="/api", tags=["settings"])

# ---------- Postgres helpers (Content Library) ----------
def _pg_conn():
    host = os.getenv("DB_HOST", "localhost")
    port = int(os.getenv("DB_PORT", "5432"))
    name = os.getenv("DB_NAME", "proposal_sow_builder")
    user = os.getenv("DB_USER", "postgres")
    pwd = os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
    return psycopg2.connect(
        host=host,
        port=port,
        dbname=name,
        user=user,
        password=pwd,
    )

# ---------- Helpers ----------
def compute_readiness_and_risk(p: Proposal) -> Proposal:
    issues = []
    filled = 0
    for sec in p.mandatory_sections:
        v = p.sections.get(sec)
        if not v or (isinstance(v, str) and not v.strip()):
            issues.append(f"Missing mandatory section: {sec}")
        else:
            filled += 1
    readiness_score = round(100.0 * filled / max(1, len(p.mandatory_sections)), 2)

    minor_devs = 0
    suggestions = []
    a = p.sections.get("Assumptions") or ""
    if not a or (isinstance(a,str) and len(a.strip())<20):
        minor_devs += 1
        suggestions.append("Clarify Assumptions (provide specifics and owner responsibilities).")
    bios = p.sections.get("Team Bios") or ""
    if not bios or (isinstance(bios,str) and len(bios.strip())<30):
        minor_devs += 1
        suggestions.append("Complete Team Bios with roles and key experience (>=30 chars).")
    risks = p.sections.get("Risks") or ""
    if not risks or (isinstance(risks,str) and ("TBD" in risks or "To be defined" in risks)):
        minor_devs += 1
        suggestions.append("Define Risks and associated mitigation actions.")
    acceptance = p.sections.get("Acceptance Criteria") or ""
    if acceptance and isinstance(acceptance,str) and "accept" not in acceptance.lower():
        suggestions.append("Review Acceptance Criteria to ensure it contains clear acceptance language.")

    # detect altered terms compared to content library terms
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT content FROM content_blocks WHERE key='terms' LIMIT 1")
    row = cur.fetchone()
    if row and p.sections.get("Terms") and p.sections.get("Terms") != row[0]:
        minor_devs += 1
        suggestions.append("Terms were altered—request Legal review.")
    conn.close()

    p.readiness_score = readiness_score
    p.readiness_issues = issues + suggestions
    p._compound_minor_devs = minor_devs
    return p

def get_proposal_or_404(pid:str) -> Proposal:
    db = load_db()
    for pr in db["proposals"]:
        if pr["id"] == pid:
            return Proposal(**pr)
    raise HTTPException(status_code=404, detail="Proposal not found")

def save_proposal(p: Proposal):
    db = load_db()
    for i, pr in enumerate(db["proposals"]):
        if pr["id"] == p.id:
            db["proposals"][i] = p.model_dump()
            save_db(db)
            return
    db["proposals"].append(p.model_dump())
    save_db(db)

# ---------- Routes: Content Library (PostgreSQL) ----------

@app.get("/content")
def get_content(category: Optional[str] = Query(None)):
    """Get all content blocks, optionally filtered by category"""
    try:
        with _pg_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                if category:
                    cur.execute("""
                        SELECT id, key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at
                        FROM content_blocks 
                        WHERE category = %s
                        ORDER BY updated_at DESC
                    """, (category,))
                else:
                    cur.execute("""
                        SELECT id, key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at
                        FROM content_blocks 
                        ORDER BY updated_at DESC
                    """)
                rows = cur.fetchall()
                return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching content: {str(e)}")

@app.post("/content")
def create_content(
    key: str = Body(...),
    label: str = Body(...),
    content: str = Body(""),
    category: Optional[str] = Body("Templates"),
    is_folder: bool = Body(False),
    parent_id: Optional[int] = Body(None),
    public_id: Optional[str] = Body(None),
):
    """Create a new content block"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO content_blocks (key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
                    RETURNING id, key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at
                """, (key, label, content, category, is_folder, parent_id, public_id))
                result = cur.fetchone()
                conn.commit()
                return {
                    "id": result[0],
                    "key": result[1],
                    "label": result[2],
                    "content": result[3],
                    "category": result[4],
                    "is_folder": result[5],
                    "parent_id": result[6],
                    "public_id": result[7],
                    "created_at": result[8],
                    "updated_at": result[9],
                }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating content: {str(e)}")

@app.put("/content/{content_id}")
def update_content(
    content_id: int,
    label: Optional[str] = Body(None),
    content: Optional[str] = Body(None),
    category: Optional[str] = Body(None),
    public_id: Optional[str] = Body(None),
):
    """Update a content block"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                # Build dynamic update query
                updates = []
                params = []
                if label is not None:
                    updates.append("label=%s")
                    params.append(label)
                if content is not None:
                    updates.append("content=%s")
                    params.append(content)
                if category is not None:
                    updates.append("category=%s")
                    params.append(category)
                if public_id is not None:
                    updates.append("public_id=%s")
                    params.append(public_id)
                
                if not updates:
                    raise HTTPException(status_code=400, detail="No fields to update")
                
                updates.append("updated_at=NOW()")
                params.append(content_id)
                
                query = f"UPDATE content_blocks SET {', '.join(updates)} WHERE id=%s RETURNING id, key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at"
                cur.execute(query, params)
                result = cur.fetchone()
                if not result:
                    raise HTTPException(status_code=404, detail="Content block not found")
                conn.commit()
                
                return {
                    "id": result[0],
                    "key": result[1],
                    "label": result[2],
                    "content": result[3],
                    "category": result[4],
                    "is_folder": result[5],
                    "parent_id": result[6],
                    "public_id": result[7],
                    "created_at": result[8],
                    "updated_at": result[9],
                }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating content: {str(e)}")

@app.delete("/content/{content_id}")
def delete_content(content_id: int):
    """Delete a content block"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM content_blocks WHERE id=%s", (content_id,))
                if cur.rowcount == 0:
                    raise HTTPException(status_code=404, detail="Content block not found")
                conn.commit()
                return {"message": "deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting content: {str(e)}")

# ---------- New Routes: Content Modules (PostgreSQL) ----------
@app.get("/api/modules/")
def pg_list_modules(q: Optional[str] = Query(""), category: Optional[str] = Query("")):
    sql = "SELECT id::text, title, category, body, version, created_by::text, created_at, updated_at, is_editable FROM content_modules"
    where = []
    params: list = []
    if category:
        where.append("category = %s")
        params.append(category)
    if q:
        where.append("(title ILIKE %s OR body ILIKE %s)")
        like = f"%{q}%"
        params.extend([like, like])
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY updated_at DESC LIMIT 500"
    with _pg_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
    return rows

@app.get("/api/modules/{module_id}")
def pg_get_module(module_id: str):
    with _pg_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id::text, title, category, body, version, created_by::text, created_at, updated_at, is_editable FROM content_modules WHERE id = %s", (module_id,))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Not found")
    return row

class ModuleCreate(BaseModel):
    title: str
    category: str = "Other"
    body: str
    is_editable: bool = False

@app.post("/api/modules/")
def pg_create_module(payload: ModuleCreate):
    with _pg_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO content_modules (title, category, body, is_editable) VALUES (%s,%s,%s,%s) RETURNING id",
                (payload.title, payload.category, payload.body, payload.is_editable),
            )
            module_id = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO module_versions (module_id, version, snapshot, note) VALUES (%s,1,%s,%s)",
                (module_id, payload.body, "Initial version"),
            )
            conn.commit()
    return {"message": "created", "id": str(module_id)}

class ModuleUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    note: Optional[str] = "Edited"

@app.put("/api/modules/{module_id}")
def pg_update_module(module_id: str, payload: ModuleUpdate):
    if payload.title is None and payload.body is None:
        raise HTTPException(status_code=400, detail="No content to update")
    with _pg_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT version, body FROM content_modules WHERE id=%s", (module_id,))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Not found")
            current_version, current_body = row
            new_version = (current_version or 1) + 1
            cur.execute(
                "INSERT INTO module_versions (module_id, version, snapshot, note) VALUES (%s,%s,%s,%s)",
                (module_id, new_version, current_body, payload.note or "Edited"),
            )
            sets = []
            params: list = []
            if payload.title is not None:
                sets.append("title=%s")
                params.append(payload.title)
            if payload.body is not None:
                sets.append("body=%s")
                params.append(payload.body)
            sets.append("version=%s")
            params.append(new_version)
            sets.append("updated_at=NOW()")
            params.append(module_id)
            cur.execute(f"UPDATE content_modules SET {', '.join(sets)} WHERE id=%s", params)
            conn.commit()
    return {"message": "updated", "version": new_version}

@app.delete("/api/modules/{module_id}")
def pg_delete_module(module_id: str):
    with _pg_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM content_modules WHERE id=%s", (module_id,))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Not found")
            conn.commit()
    return {"message": "deleted"}

@app.get("/api/modules/{module_id}/versions")
def pg_list_versions(module_id: str):
    with _pg_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT id::text, module_id::text, version, snapshot, created_by::text, created_at, note FROM module_versions WHERE module_id=%s ORDER BY version DESC",
                (module_id,),
            )
            return cur.fetchall()

class RevertPayload(BaseModel):
    version: int
    note: Optional[str] = None

@app.post("/api/modules/{module_id}/revert")
def pg_revert_module(module_id: str, payload: RevertPayload):
    if payload.version <= 0:
        raise HTTPException(status_code=400, detail="invalid version")
    with _pg_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT snapshot FROM module_versions WHERE module_id=%s AND version=%s", (module_id, payload.version))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="version not found")
            target_snapshot = row[0]
            cur.execute("SELECT version FROM content_modules WHERE id=%s", (module_id,))
            current_version = (cur.fetchone() or [1])[0]
            new_version = (current_version or 1) + 1
            cur.execute(
                "INSERT INTO module_versions (module_id, version, snapshot, note) VALUES (%s,%s,%s,%s)",
                (module_id, new_version, target_snapshot, payload.note or f"Reverted to v{payload.version}"),
            )
            cur.execute(
                "UPDATE content_modules SET body=%s, version=%s, updated_at=NOW() WHERE id=%s",
                (target_snapshot, new_version, module_id),
            )
            conn.commit()
    return {"message": "reverted", "new_version": new_version}

# ---------- Routes: Templates & Proposals (JSON storage) ----------
@app.get("/templates")
def list_templates():
    """Get available proposal templates"""
    templates = [
        {
            "id": "proposal",
            "name": "Proposal",
            "description": "Standard business proposal with executive summary, scope, and pricing",
            "sections": ["executive_summary", "company_profile", "scope_deliverables", "timeline", "investment", "terms_conditions"]
        },
        {
            "id": "sow",
            "name": "Statement of Work (SOW)",
            "description": "Detailed work statement with deliverables, timeline, and responsibilities",
            "sections": ["project_overview", "scope_of_work", "deliverables", "timeline", "resources", "terms"]
        },
        {
            "id": "rfi",
            "name": "RFI Response",
            "description": "Response to Request for Information with technical details and capabilities",
            "sections": ["company_overview", "technical_capabilities", "past_experience", "team_qualifications", "references"]
        }
    ]
    return {"templates": templates}

@app.get("/proposals")
def list_proposals():
    """Get all proposals from PostgreSQL database"""
    try:
        with _pg_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("""
                    SELECT 
                        id::text,
                        title,
                        client_name as client,
                        status,
                        content as sections,
                        created_at,
                        updated_at,
                        budget as estimated_value,
                        timeline_days as timeline
                    FROM proposals 
                    ORDER BY updated_at DESC
                """)
                proposals = cur.fetchall()
                
                # Convert to list of dicts and add required fields
                result = []
                for proposal in proposals:
                    proposal_dict = dict(proposal)
                    # Add required fields that might be missing
                    proposal_dict['dtype'] = 'Proposal'
                    proposal_dict['mandatory_sections'] = [
                        "Executive Summary",
                        "Scope & Deliverables", 
                        "Delivery Approach",
                        "Assumptions",
                        "Risks",
                        "References",
                        "Team Bios"
                    ]
                    proposal_dict['approval'] = {
                        "mode": "sequential",
                        "order": ["Delivery", "Legal", "Exec"],
                        "approvals": {}
                    }
                    proposal_dict['readiness_score'] = 0.0
                    proposal_dict['readiness_issues'] = [
                        "Missing mandatory section: Executive Summary",
                        "Missing mandatory section: Scope & Deliverables",
                        "Missing mandatory section: Delivery Approach",
                        "Missing mandatory section: Assumptions",
                        "Missing mandatory section: Risks",
                        "Missing mandatory section: References",
                        "Missing mandatory section: Team Bios"
                    ]
                    proposal_dict['signed_at'] = None
                    proposal_dict['signed_by'] = None
                    result.append(proposal_dict)
                
                return result
    except Exception as e:
        print(f"Error fetching proposals from database: {e}")
        # Fallback to empty list if database fails
        return []

@app.post("/proposals/ai-analysis")
def analyze_proposal_ai(proposal_data: dict = Body(...)):
    """AI-powered proposal analysis endpoint"""
    try:
        # This would integrate with your AI service
        # For now, return a mock analysis
        analysis = {
            "riskScore": 15,
            "status": "At Risk",
            "issues": [
                {
                    "type": "ai_analysis",
                    "title": "Vague Scope Detected",
                    "description": "Scope contains vague language that could lead to scope creep",
                    "points": 6,
                    "priority": "warning",
                    "action": "Make deliverables more specific"
                }
            ]
        }
        return analysis
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI analysis failed: {str(e)}")


@app.get("/content-modules")
def get_content_modules():
    """Get available content modules for proposals"""
    modules = [
        {
            "id": "company_profile",
            "name": "Company Profile",
            "category": "Company",
            "description": "Standard company information and capabilities",
            "required": True
        },
        {
            "id": "executive_summary",
            "name": "Executive Summary",
            "category": "Content",
            "description": "High-level project overview and value proposition",
            "required": True
        },
        {
            "id": "scope_deliverables",
            "name": "Scope & Deliverables",
            "category": "Project",
            "description": "Detailed project scope and deliverable specifications",
            "required": True
        },
        {
            "id": "delivery_approach",
            "name": "Delivery Approach",
            "category": "Methodology",
            "description": "Project methodology and implementation approach",
            "required": False
        },
        {
            "id": "case_studies",
            "name": "Case Studies",
            "category": "Portfolio",
            "description": "Relevant past project examples and success stories",
            "required": False
        },
        {
            "id": "team_bios",
            "name": "Team Bios",
            "category": "Team",
            "description": "Key team member profiles and qualifications",
            "required": False
        },
        {
            "id": "assumptions_risks",
            "name": "Assumptions & Risks",
            "category": "Legal",
            "description": "Project assumptions and risk mitigation strategies",
            "required": False
        },
        {
            "id": "terms_conditions",
            "name": "Terms & Conditions",
            "category": "Legal",
            "description": "Standard legal terms and contract conditions",
            "required": True
        }
    ]
    return {"modules": modules}

@app.post("/proposals", response_model=Proposal)
def create_proposal(payload: ProposalCreate):
    """Create a new proposal in PostgreSQL database"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                # Insert new proposal into PostgreSQL
                cur.execute("""
                    INSERT INTO proposals (user_id, title, client_name, status, content, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (
                    "default_user",  # You might want to get this from auth
                    payload.title,
                    payload.client,
                    "Draft",
                    json.dumps({}),  # Empty sections initially
                    datetime.now(),
                    datetime.now()
                ))
                
                proposal_id = cur.fetchone()[0]
                conn.commit()
                
                # Create Proposal object for response
                p = Proposal(
                    id=str(proposal_id),
                    title=payload.title,
                    client=payload.client,
                    dtype=payload.dtype or "Proposal",
                    status="Draft",
                    sections={},
                    created_at=now_iso(),
                    updated_at=now_iso()
                )
                
                # Apply template if specified
                if payload.template_key:
                    # You can add template logic here if needed
                    pass
                
                return p
                
    except Exception as e:
        print(f"Error creating proposal in database: {e}")
        raise HTTPException(status_code=500, detail="Failed to create proposal")

@app.get("/proposals/{pid}", response_model=Proposal)
def get_proposal(pid: str):
    return get_proposal_or_404(pid)

@app.put("/proposals/{pid}", response_model=Proposal)
def update_proposal(pid: str, payload: ProposalUpdate):
    p = get_proposal_or_404(pid)
    if payload.title is not None:
        p.title = payload.title
    if payload.client is not None:
        p.client = payload.client
    if payload.dtype is not None:
        p.dtype = payload.dtype
    if payload.sections is not None:
        p.sections.update(payload.sections)
    p.updated_at = now_iso()
    p = compute_readiness_and_risk(p)
    save_proposal(p)
    return p

@app.patch("/proposals/{pid}/status")
def update_proposal_status(pid: str, status_data: dict = Body(...)):
    """Update proposal status"""
    p = get_proposal_or_404(pid)
    new_status = status_data.get("status")
    if new_status not in ["Draft", "In Review", "Released", "Signed", "Archived"]:
        raise HTTPException(status_code=400, detail="Invalid status")
    
    p.status = new_status
    p.updated_at = now_iso()
    save_proposal(p)
    return {"message": "Status updated successfully", "status": new_status}

@app.put("/proposals/{pid}/data")
def update_proposal_data(pid: str, proposal_data: dict = Body(...)):
    """Update proposal with enhanced data from compose page"""
    p = get_proposal_or_404(pid)
    
    # Update basic fields
    if "title" in proposal_data:
        p.title = proposal_data["title"]
    if "client" in proposal_data:
        p.client = proposal_data["client"]
    if "clientEmail" in proposal_data:
        p.client_email = proposal_data["clientEmail"]
    if "projectType" in proposal_data:
        p.project_type = proposal_data["projectType"]
    if "estimatedValue" in proposal_data:
        p.estimated_value = proposal_data["estimatedValue"]
    if "timeline" in proposal_data:
        p.timeline = proposal_data["timeline"]
    
    # Update sections with enhanced content
    if "sections" in proposal_data:
        p.sections.update(proposal_data["sections"])
    
    p.updated_at = now_iso()
    p = compute_readiness_and_risk(p)
    save_proposal(p)
    return {"message": "Proposal updated successfully", "proposal": p}

@app.post("/proposals/{pid}/submit", response_model=Proposal)
def submit_for_review(pid: str, current_user: dict = Depends(get_current_user)):
    """Submit proposal for CEO approval - Financial Manager only"""
    if current_user["role"] not in ["Financial Manager", "CEO"]:
        raise HTTPException(status_code=403, detail="Only Financial Managers can submit proposals")
    
    p = get_proposal_or_404(pid)
    p = compute_readiness_and_risk(p)
    if p.readiness_issues and any(i.startswith("Missing mandatory section") for i in p.readiness_issues):
        raise HTTPException(status_code=400, detail={"message":"Readiness checks failed","issues":p.readiness_issues})
    if getattr(p, "_compound_minor_devs", 0) >= 2:
        raise HTTPException(status_code=400, detail={"message":"Compound minor deviations detected, please resolve","issues":p.readiness_issues})
    
    p.status = "Pending CEO Approval"
    p.current_approver_role = "CEO"
    p.approval_history.append({
        "action": "submitted",
        "by_user_id": current_user["id"],
        "by_role": current_user["role"],
        "at": now_iso(),
        "comments": "Submitted for CEO approval"
    })
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.post("/proposals/{pid}/approve", response_model=Proposal)
def approve_proposal(pid: str, comments: str = "", current_user: dict = Depends(get_current_user)):
    """CEO approves proposal"""
    if current_user["role"] != "CEO":
        raise HTTPException(status_code=403, detail="Only CEO can approve proposals")
    
    p = get_proposal_or_404(pid)
    if p.status != "Pending CEO Approval":
        raise HTTPException(status_code=400, detail="Proposal must be pending CEO approval")
    
    p.status = "Approved"
    p.current_approver_role = None
    p.approval_history.append({
        "action": "approved",
        "by_user_id": current_user["id"],
        "by_role": current_user["role"],
        "at": now_iso(),
        "comments": comments or "Approved by CEO"
    })
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.post("/proposals/{pid}/reject", response_model=Proposal)
def reject_proposal(pid: str, comments: str = "", current_user: dict = Depends(get_current_user)):
    """CEO rejects proposal"""
    if current_user["role"] != "CEO":
        raise HTTPException(status_code=403, detail="Only CEO can reject proposals")
    
    p = get_proposal_or_404(pid)
    if p.status != "Pending CEO Approval":
        raise HTTPException(status_code=400, detail="Proposal must be pending CEO approval")
    
    p.status = "Rejected"
    p.current_approver_role = None
    p.approval_history.append({
        "action": "rejected",
        "by_user_id": current_user["id"],
        "by_role": current_user["role"],
        "at": now_iso(),
        "comments": comments or "Rejected by CEO"
    })
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.post("/proposals/{pid}/send_to_client", response_model=Proposal)
def send_to_client(pid: str, current_user: dict = Depends(get_current_user)):
    """Financial Manager sends approved proposal to client"""
    if current_user["role"] not in ["Financial Manager", "CEO"]:
        raise HTTPException(status_code=403, detail="Only Financial Managers or CEO can send proposals to clients")
    
    p = get_proposal_or_404(pid)
    if p.status != "Approved":
        raise HTTPException(status_code=400, detail="Proposal must be approved before sending to client")
    
    p.status = "Sent to Client"
    if not p.client_actions:
        p.client_actions = {}
    p.client_actions["sent_at"] = now_iso()
    p.client_actions["sent_by"] = current_user["id"]
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.post("/proposals/{pid}/sign", response_model=Proposal)
def sign_proposal(pid: str, payload: SignPayload, current_user: dict = Depends(get_current_user)):
    """Client signs proposal"""
    if current_user["role"] != "Client":
        raise HTTPException(status_code=403, detail="Only Clients can sign proposals")
    
    p = get_proposal_or_404(pid)
    if p.status != "Sent to Client":
        raise HTTPException(status_code=400, detail="Proposal must be sent to client before signing")
    
    p.status = "Signed"
    p.signed_at = now_iso()
    p.signed_by = payload.signer_name
    if not p.client_actions:
        p.client_actions = {}
    p.client_actions["signed_at"] = now_iso()
    p.client_actions["signed_by"] = current_user["id"]
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.post("/proposals/{pid}/client_view")
def client_viewed_proposal(pid: str, current_user: dict = Depends(get_current_user)):
    """Track when client views proposal"""
    if current_user["role"] != "Client":
        raise HTTPException(status_code=403, detail="Only Clients can view proposals")
    
    p = get_proposal_or_404(pid)
    if p.status == "Sent to Client":
        p.status = "Client Viewing"
    
    if not p.client_actions:
        p.client_actions = {}
    if "viewed_at" not in p.client_actions:
        p.client_actions["viewed_at"] = now_iso()
        p.updated_at = now_iso()
        save_proposal(p)
    
    return {"message": "View tracked"}

@app.post("/proposals/{pid}/client_decline", response_model=Proposal)
def client_decline_proposal(pid: str, comments: str = "", current_user: dict = Depends(get_current_user)):
    """Client declines proposal"""
    if current_user["role"] != "Client":
        raise HTTPException(status_code=403, detail="Only Clients can decline proposals")
    
    p = get_proposal_or_404(pid)
    if p.status not in ["Sent to Client", "Client Viewing"]:
        raise HTTPException(status_code=400, detail="Proposal must be sent to client")
    
    p.status = "Declined by Client"
    if not p.client_actions:
        p.client_actions = {}
    p.client_actions["declined_at"] = now_iso()
    p.client_actions["decline_reason"] = comments
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.get("/dashboard_stats")
def dashboard_stats(current_user: dict = Depends(get_current_user)):
    """Get dashboard statistics based on user role"""
    db = load_db()
    all_proposals = db["proposals"]
    
    # Filter proposals based on role
    if current_user["role"] == "CEO":
        # CEO sees all proposals
        proposals = all_proposals
    elif current_user["role"] == "Financial Manager":
        # Financial Manager sees only their own proposals
        proposals = [p for p in all_proposals if p.get("creator_id") == current_user["id"]]
    elif current_user["role"] == "Client":
        # Client sees only proposals sent to them (matching their email/username)
        proposals = [p for p in all_proposals if p.get("client") == current_user["email"] or p.get("client") == current_user["username"]]
    else:
        proposals = []
    
    counts = {
        "Draft": 0,
        "Pending CEO Approval": 0,
        "Rejected": 0,
        "Approved": 0,
        "Sent to Client": 0,
        "Client Viewing": 0,
        "Signed": 0,
        "Declined by Client": 0,
        "Archived": 0
    }
    
    for pr in proposals:
        status = pr.get("status", "Draft")
        counts[status] = counts.get(status, 0) + 1
    
    return {
        "counts": counts,
        "total": len(proposals),
        "role": current_user["role"]
    }

@app.get("/proposals/pending_approval")
def get_pending_approvals(current_user: dict = Depends(get_current_user)):
    """Get proposals pending CEO approval - CEO only"""
    if current_user["role"] != "CEO":
        raise HTTPException(status_code=403, detail="Only CEO can view pending approvals")
    
    db = load_db()
    pending = [p for p in db["proposals"] if p.get("status") == "Pending CEO Approval"]
    return {"proposals": pending, "count": len(pending)}

@app.get("/proposals/my_proposals")
def get_my_proposals(current_user: dict = Depends(get_current_user)):
    """Get current user's proposals"""
    db = load_db()
    
    if current_user["role"] == "CEO":
        # CEO sees all proposals
        proposals = db["proposals"]
    elif current_user["role"] == "Financial Manager":
        # Financial Manager sees only their own
        proposals = [p for p in db["proposals"] if p.get("creator_id") == current_user["id"]]
    elif current_user["role"] == "Client":
        # Client sees only proposals sent to them
        proposals = [p for p in db["proposals"] if p.get("client") == current_user["email"] or p.get("client") == current_user["username"]]
    else:
        proposals = []
    
    return {"proposals": proposals, "count": len(proposals)}

# ---------- Authentication Routes ----------
@app.post("/register", response_model=User)
async def register_user(user: UserCreate):
    users_data = load_users()
    
    # Check if username already exists
    if get_user(user.username):
        raise HTTPException(
            status_code=400,
            detail="Username already registered"
        )
    
    # Check if email already exists
    for existing_user in users_data["users"]:
        if existing_user["email"] == user.email:
            raise HTTPException(
                status_code=400,
                detail="Email already registered"
            )
    
    # Create new user (unverified initially)
    user_id = str(uuid.uuid4())
    hashed_password = get_password_hash(user.password)
    now = now_iso()
    
    new_user = {
        "id": user_id,
        "username": user.username,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
        "hashed_password": hashed_password,
        "is_active": True,
        "is_verified": False,
        "created_at": now,
        "updated_at": now
    }
    
    users_data["users"].append(new_user)
    save_users(users_data)
    
    # Generate verification token
    verification_token = generate_verification_token()
    tokens_data = load_verification_tokens()
    tokens_data["tokens"].append({
        "token": verification_token,
        "user_id": user_id,
        "email": user.email,
        "created_at": now,
        "expires_at": (datetime.utcnow() + timedelta(hours=24)).isoformat() + "Z"
    })
    save_verification_tokens(tokens_data)
    
    # Send verification email
    try:
        await send_verification_email(user.email, verification_token)
    except Exception as e:
        # Log error but don't fail registration
        print(f"Failed to send verification email: {e}")
    
    # Return user without password
    return User(
        id=new_user["id"],
        username=new_user["username"],
        email=new_user["email"],
        full_name=new_user["full_name"],
        role=new_user["role"],
        is_active=new_user["is_active"],
        is_verified=new_user["is_verified"],
        created_at=new_user["created_at"],
        updated_at=new_user["updated_at"]
    )

@app.post("/login", response_model=Token)
def login_user(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    if not user.get("is_verified", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified. Please check your email and click the verification link."
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["username"]}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# Add email-based login endpoint
@app.post("/login-email", response_model=Token)
def login_user_email(login_data: EmailLogin):
    # Find user by email
    users_data = load_users()
    user = None
    for u in users_data["users"]:
        if u["email"] == login_data.email:
            user = u
            break
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not verify_password(login_data.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    if not user.get("is_verified", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified. Please check your email and click the verification link."
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["username"]}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/verify-email", response_model=VerificationResponse)
async def verify_email(verification: EmailVerification):
    tokens_data = load_verification_tokens()
    users_data = load_users()
    
    # Find the token
    token_info = None
    for token_entry in tokens_data["tokens"]:
        if token_entry["token"] == verification.token:
            token_info = token_entry
            break
    
    if not token_info:
        raise HTTPException(
            status_code=400,
            detail="Invalid verification token"
        )
    
    # Check if token is expired
    token_expires = datetime.fromisoformat(token_info["expires_at"].replace("Z", "+00:00"))
    if datetime.utcnow().replace(tzinfo=token_expires.tzinfo) > token_expires:
        raise HTTPException(
            status_code=400,
            detail="Verification token has expired"
        )
    
    # Find and update the user
    user_updated = False
    for user in users_data["users"]:
        if user["id"] == token_info["user_id"]:
            user["is_verified"] = True
            user["updated_at"] = now_iso()
            user_updated = True
            break
    
    if not user_updated:
        raise HTTPException(
            status_code=400,
            detail="User not found"
        )
    
    # Save updated user data
    save_users(users_data)
    
    # Remove the used token
    tokens_data["tokens"] = [t for t in tokens_data["tokens"] if t["token"] != verification.token]
    save_verification_tokens(tokens_data)
    
    return VerificationResponse(
        message="Email verified successfully! You can now log in.",
        verified=True
    )

class ResendVerificationRequest(BaseModel):
    email: EmailStr

@app.post("/resend-verification")
async def resend_verification_email(request: ResendVerificationRequest):
    users_data = load_users()
    tokens_data = load_verification_tokens()
    
    # Find user by email
    user = None
    for u in users_data["users"]:
        if u["email"] == request.email:
            user = u
            break
    
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found with this email address"
        )
    
    if user.get("is_verified", False):
        raise HTTPException(
            status_code=400,
            detail="Email is already verified"
        )
    
    # Remove any existing verification tokens for this user
    tokens_data["tokens"] = [t for t in tokens_data["tokens"] if t["user_id"] != user["id"]]
    
    # Generate new verification token
    verification_token = generate_verification_token()
    now = now_iso()
    tokens_data["tokens"].append({
        "token": verification_token,
        "user_id": user["id"],
        "email": user["email"],
        "created_at": now,
        "expires_at": (datetime.utcnow() + timedelta(hours=24)).isoformat() + "Z"
    })
    save_verification_tokens(tokens_data)
    
    # Send verification email
    try:
        await send_verification_email(user["email"], verification_token)
        return {"message": "Verification email sent successfully"}
    except Exception as e:
        print(f"Failed to send verification email: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to send verification email. Please try again later."
        )


# ---------- Password reset (forgot password) ----------
class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

async def send_reset_password_email(email: str, token: str):
    # Frontend reset page (adjust port/origin if your frontend runs elsewhere)
    frontend_reset_url = f"http://localhost:57787/reset-password?token={token}"
    backend_reset_url = f"http://localhost:8000/reset-password?token={token}"

    message = MessageSchema(
        subject="Reset your password - Proposal & SOW Builder",
        recipients=[email],
        body=f"""
        <html>
        <body>
            <h2>Password reset request</h2>
            <p>We received a request to reset the password for your account.</p>
            <p>You can use the button below to open the password reset page (frontend):</p>
            <p><a href="{frontend_reset_url}" style="background-color: #e74c3c; color: white; padding: 10px 18px; text-decoration: none; border-radius: 5px;">Reset password</a></p>
            <p>Or use the direct backend endpoint (for testing/API clients):</p>
            <p>{backend_reset_url}</p>
            <p>This link will expire in 1 hour. If you did not request a password reset, you can ignore this email.</p>
        </body>
        </html>
        """,
        subtype=MessageType.html
    )

    fm = FastMail(conf)
    await fm.send_message(message)


@app.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest):
    users_data = load_users()
    tokens_data = load_verification_tokens()

    # Find user by email
    user = next((u for u in users_data["users"] if u["email"] == request.email), None)

    # Always return success message to avoid user enumeration
    if not user:
        return {"message": "If an account exists with that email, a password reset email has been sent."}

    # Remove existing reset tokens for this user
    tokens_data["tokens"] = [t for t in tokens_data["tokens"] if not (t.get("user_id") == user["id"] and t.get("type") == "reset_password")]

    # Generate new reset token
    reset_token = generate_verification_token()
    now = now_iso()
    tokens_data["tokens"].append({
        "token": reset_token,
        "user_id": user["id"],
        "email": user["email"],
        "type": "reset_password",
        "created_at": now,
        "expires_at": (datetime.utcnow() + timedelta(hours=1)).isoformat() + "Z"
    })
    save_verification_tokens(tokens_data)

    try:
        await send_reset_password_email(user["email"], reset_token)
    except Exception as e:
        print(f"Failed to send reset password email: {e}")
        # Do not expose mail errors to client

    return {"message": "If an account exists with that email, a password reset email has been sent."}


@app.post("/reset-password")
async def reset_password(request: ResetPasswordRequest):
    tokens_data = load_verification_tokens()
    users_data = load_users()

    # Find token entry specifically for password reset
    token_entry = next((t for t in tokens_data["tokens"] if t.get("token") == request.token and t.get("type") == "reset_password"), None)
    if not token_entry:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    # Check expiry
    token_expires = datetime.fromisoformat(token_entry["expires_at"].replace("Z", "+00:00"))
    if datetime.utcnow().replace(tzinfo=token_expires.tzinfo) > token_expires:
        # Remove expired token
        tokens_data["tokens"] = [t for t in tokens_data["tokens"] if t.get("token") != request.token]
        save_verification_tokens(tokens_data)
        raise HTTPException(status_code=400, detail="Reset token has expired")

    # Find the user and update password
    user = next((u for u in users_data["users"] if u["id"] == token_entry.get("user_id")), None)
    if not user:
        raise HTTPException(status_code=400, detail="User not found for this token")

    # Update password
    user["hashed_password"] = get_password_hash(request.new_password)
    user["updated_at"] = now_iso()
    save_users(users_data)

    # Remove used token
    tokens_data["tokens"] = [t for t in tokens_data["tokens"] if t.get("token") != request.token]
    save_verification_tokens(tokens_data)

    return {"message": "Password has been reset successfully. You can now log in with your new password."}


@app.post("/send-proposal-email")
async def send_proposal_email(request: SendProposalEmailRequest):
    """Send proposal email to clients with PDF attachment and dashboard link"""
    try:
        # Validate email addresses
        if not request.to or len(request.to) == 0:
            raise HTTPException(status_code=400, detail="At least one recipient email is required")
        
        # Validate email format
        for email in request.to:
            if '@' not in email or '.' not in email.split('@')[1]:
                raise HTTPException(status_code=400, detail=f"Invalid email format: {email}")
        
        # Generate proposal ID if not provided
        proposal_id = str(uuid.uuid4())
        
        # Generate client dashboard token
        primary_recipient = request.to[0]
        dashboard_token = generate_client_dashboard_token(proposal_id, primary_recipient, request.proposal_data)
        dashboard_url = f"http://localhost:8000/client-dashboard-mini/{dashboard_token}"
        
        # Enhanced email body with dashboard link
        enhanced_body = request.body
        if request.include_dashboard_link:
            enhanced_body += f"""
            <br><br>
            <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <h3 style="color: #2c3e50; margin-top: 0;">📊 Client Dashboard</h3>
                <p>Access your personalized client dashboard to:</p>
                <ul>
                    <li>View the full proposal online</li>
                    <li>Track project progress</li>
                    <li>Communicate with our team</li>
                    <li>Sign documents digitally</li>
                </ul>
                <a href="{dashboard_url}" style="background-color: #3498db; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 10px;">
                    Access Client Dashboard
                </a>
            </div>
            """
        
        # Create email message
        message_data = {
            'subject': request.subject,
            'recipients': request.to,
            'body': enhanced_body,
            'subtype': MessageType.html
        }
        
        # Only add cc if there are CC recipients
        if request.cc and len(request.cc) > 0:
            message_data['cc'] = request.cc
            
        # Ensure recipients is a list of strings
        if isinstance(message_data['recipients'], str):
            message_data['recipients'] = [message_data['recipients']]
        
        # Debug: Print email details
        print(f"Email Details:")
        print(f"  Subject: {message_data['subject']}")
        print(f"  Recipients: {message_data['recipients']}")
        print(f"  CC: {message_data.get('cc', 'None')}")
        print(f"  Body length: {len(message_data['body'])}")
            
        message = MessageSchema(**message_data)
        
        # Generate and attach PDF if requested
        if request.include_pdf and request.proposal_data:
            try:
                # Create temporary PDF file
                tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.pdf')
                pdf_path = tmp_file.name
                tmp_file.close()
                
                # Generate PDF
                generate_proposal_pdf(request.proposal_data, pdf_path)
                
                # Read PDF content
                with open(pdf_path, 'rb') as pdf_file:
                    pdf_content = pdf_file.read()
                
                # Attach PDF to email
                message.attachments = [{
                    'filename': f'Proposal_{proposal_id[:8]}.pdf',
                    'content': pdf_content,
                    'content_type': 'application/pdf'
                }]
                
                # Clean up temporary file
                os.unlink(pdf_path)
                print(f"PDF attachment created successfully: {len(pdf_content)} bytes")
                
            except Exception as pdf_error:
                print(f"Warning: Failed to generate PDF attachment: {pdf_error}")
                import traceback
                traceback.print_exc()
                # Continue without PDF attachment
        
        # Send email
        try:
            fm = FastMail(conf)
            await fm.send_message(message)
            print(f"Email sent successfully to: {request.to}")
            
            return {
                "message": "Proposal email sent successfully",
                "sent_to": request.to,
                "cc": request.cc if request.cc else [],
                "proposal_id": proposal_id,
                "dashboard_url": dashboard_url if request.include_dashboard_link else None,
                "pdf_attached": request.include_pdf and request.proposal_data is not None
            }
        except Exception as smtp_error:
            print(f"SMTP Error: {smtp_error}")
            print(f"Recipients: {request.to}")
            print(f"CC: {request.cc}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to send email: {str(smtp_error)}"
            )
    except Exception as e:
        print(f"Failed to send proposal email: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send email: {str(e)}"
        )

@app.get("/client-dashboard/{token}")
async def client_dashboard_json(token: str):
    """Client dashboard JSON data for Flutter app"""
    try:
        # Verify and decode token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        proposal_id = payload.get('proposal_id')
        client_email = payload.get('client_email')
        proposal_data = payload.get('proposal_data', {})
        
        if not proposal_id or not client_email:
            raise HTTPException(status_code=400, detail="Invalid token")
        
        return {
            "client_email": client_email,
            "proposal_id": proposal_id,
            "proposal_data": proposal_data,
            "status": "success"
        }
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/client-dashboard-html/{token}", response_class=HTMLResponse)
async def client_dashboard_html(token: str):
    """Client dashboard with secure token access - HTML version"""
    try:
        # Verify and decode token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        proposal_id = payload.get('proposal_id')
        client_email = payload.get('client_email')
        proposal_data = payload.get('proposal_data', {})
        
        if not proposal_id or not client_email:
            raise HTTPException(status_code=400, detail="Invalid token")
        
        # Generate dashboard HTML
        dashboard_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Proposal Review - {proposal_data.get('title', 'Business Proposal')}</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {{ margin: 0; padding: 0; box-sizing: border-box; }}
                body {{ 
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                    background-color: #f8f9fa; 
                    line-height: 1.6;
                }}
                .container {{ 
                    max-width: 1000px; 
                    margin: 0 auto; 
                    padding: 20px; 
                }}
                .proposal-header {{
                    background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
                    color: white; 
                    padding: 40px 30px; 
                    border-radius: 12px; 
                    margin-bottom: 30px; 
                    position: relative;
                    overflow: hidden;
                }}
                .proposal-header::before {{
                    content: '';
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="25" cy="25" r="1" fill="white" opacity="0.1"/><circle cx="75" cy="75" r="1" fill="white" opacity="0.1"/><circle cx="50" cy="10" r="0.5" fill="white" opacity="0.1"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>');
                    opacity: 0.3;
                }}
                .brand {{
                    display: flex;
                    align-items: center;
                    margin-bottom: 20px;
                    position: relative;
                    z-index: 1;
                }}
                .brand-icon {{
                    width: 40px;
                    height: 40px;
                    background: #3498db;
                    border-radius: 8px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin-right: 15px;
                    font-size: 20px;
                }}
                .brand-name {{
                    font-size: 24px;
                    font-weight: bold;
                }}
                .proposal-title {{
                    font-size: 32px;
                    font-weight: 300;
                    margin-bottom: 10px;
                    text-align: center;
                    position: relative;
                    z-index: 1;
                }}
                .proposal-meta {{
                    text-align: center;
                    opacity: 0.9;
                    font-size: 16px;
                    position: relative;
                    z-index: 1;
                }}
                .proposal-content {{
                    background: white; 
                    border-radius: 12px; 
                    box-shadow: 0 4px 20px rgba(0,0,0,0.1); 
                    margin-bottom: 30px;
                    overflow: hidden;
                }}
                .section {{
                    padding: 30px;
                    border-bottom: 1px solid #eee;
                }}
                .section:last-child {{
                    border-bottom: none;
                }}
                .section-header {{
                    display: flex;
                    align-items: center;
                    margin-bottom: 20px;
                }}
                .section-icon {{
                    width: 40px;
                    height: 40px;
                    background: #3498db;
                    border-radius: 8px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin-right: 15px;
                    color: white;
                    font-size: 18px;
                }}
                .section-title {{
                    font-size: 20px;
                    font-weight: 600;
                    color: #2c3e50;
                }}
                .section-content {{
                    color: #555;
                    line-height: 1.8;
                    white-space: pre-line;
                }}
                .pricing-table {{
                    background: #f8f9fa;
                    border-radius: 8px;
                    padding: 20px;
                    margin: 15px 0;
                }}
                .pricing-row {{
                    display: flex;
                    justify-content: space-between;
                    padding: 10px 0;
                    border-bottom: 1px solid #dee2e6;
                }}
                .pricing-row:last-child {{
                    border-bottom: none;
                    font-weight: bold;
                    font-size: 18px;
                    color: #2c3e50;
                }}
                .action-buttons {{
                    background: white;
                    padding: 30px;
                    border-radius: 12px;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
                    text-align: center;
                }}
                .btn {{
                    background: #3498db;
                    color: white;
                    padding: 15px 30px;
                    border: none;
                    border-radius: 8px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    margin: 10px;
                    transition: all 0.3s ease;
                    text-decoration: none;
                    display: inline-block;
                }}
                .btn:hover {{
                    background: #2980b9;
                    transform: translateY(-2px);
                    box-shadow: 0 4px 15px rgba(52, 152, 219, 0.3);
                }}
                .btn-success {{
                    background: #27ae60;
                }}
                .btn-success:hover {{
                    background: #229954;
                    box-shadow: 0 4px 15px rgba(39, 174, 96, 0.3);
                }}
                .btn-outline {{
                    background: transparent;
                    color: #3498db;
                    border: 2px solid #3498db;
                }}
                .btn-outline:hover {{
                    background: #3498db;
                    color: white;
                }}
                .status-badge {{
                    display: inline-block;
                    padding: 8px 16px;
                    background: #f39c12;
                    color: white;
                    border-radius: 20px;
                    font-size: 14px;
                    font-weight: 600;
                    margin-left: 15px;
                }}
                .signature-section {{
                    background: #f8f9fa;
                    padding: 25px;
                    border-radius: 8px;
                    margin-top: 20px;
                }}
                .signature-fields {{
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 20px;
                    margin-bottom: 20px;
                }}
                .form-group {{
                    margin-bottom: 15px;
                }}
                .form-label {{
                    display: block;
                    margin-bottom: 5px;
                    font-weight: 600;
                    color: #2c3e50;
                }}
                .form-input {{
                    width: 100%;
                    padding: 12px;
                    border: 2px solid #ddd;
                    border-radius: 6px;
                    font-size: 14px;
                    transition: border-color 0.3s;
                }}
                .form-input:focus {{
                    outline: none;
                    border-color: #3498db;
                }}
                .signature-pad {{
                    width: 100%;
                    height: 120px;
                    border: 2px dashed #ddd;
                    border-radius: 6px;
                    background: white;
                    cursor: crosshair;
                    transition: all 0.3s;
                    position: relative;
                }}
                .signature-pad:hover {{
                    border-color: #3498db;
                    background: #f8f9fa;
                }}
                .signature-pad canvas {{
                    width: 100%;
                    height: 100%;
                    border-radius: 4px;
                }}
                .signature-placeholder {{
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: #999;
                    pointer-events: none;
                }}
                .signature-actions {{
                    margin-top: 10px;
                    text-align: right;
                }}
                .btn-small {{
                    padding: 8px 16px;
                    font-size: 12px;
                    margin-left: 5px;
                }}
                @media (max-width: 768px) {{
                    .container {{ padding: 10px; }}
                    .proposal-title {{ font-size: 24px; }}
                    .signature-fields {{ grid-template-columns: 1fr; }}
                    .btn {{ display: block; width: 100%; margin: 10px 0; }}
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <!-- Professional Proposal Header -->
                <div class="proposal-header">
                    <div class="brand">
                        <div class="brand-icon">🚀</div>
                        <div class="brand-name">PROPOSIFY</div>
                    </div>
                    <h1 class="proposal-title">{proposal_data.get('title', 'Professional Business Proposal')}</h1>
                    <div class="proposal-meta">
                        Date: {datetime.now().strftime('%B %d, %Y')} | Proposal #: {proposal_id[:8].upper()}
                        <span class="status-badge">Under Review</span>
                    </div>
                </div>
                
                <!-- Proposal Content -->
                <div class="proposal-content">
                    <!-- Executive Summary -->
                    <div class="section">
                        <div class="section-header">
                            <div class="section-icon">📋</div>
                            <h2 class="section-title">Executive Summary</h2>
                        </div>
                        <div class="section-content">{proposal_data.get('executive_summary', 'No summary provided.')}</div>
                    </div>
                    
                    <!-- Scope of Work -->
                    <div class="section">
                        <div class="section-header">
                            <div class="section-icon">🎯</div>
                            <h2 class="section-title">Scope of Work</h2>
                        </div>
                        <div class="section-content">{proposal_data.get('scope', 'No scope details provided.')}</div>
                    </div>
                    
                    <!-- Timeline -->
                    <div class="section">
                        <div class="section-header">
                            <div class="section-icon">⏰</div>
                            <h2 class="section-title">Project Timeline</h2>
                        </div>
                        <div class="section-content">{proposal_data.get('timeline', 'No timeline provided.')}</div>
                    </div>
                    
                    <!-- Investment -->
                    <div class="section">
                        <div class="section-header">
                            <div class="section-icon">💰</div>
                            <h2 class="section-title">Investment Summary</h2>
                        </div>
                        <div class="pricing-table">
                            <div class="section-content">{proposal_data.get('investment', 'No investment details provided.')}</div>
                        </div>
                    </div>
                    
                    <!-- Terms & Conditions -->
                    <div class="section">
                        <div class="section-header">
                            <div class="section-icon">📄</div>
                            <h2 class="section-title">Terms & Conditions</h2>
                        </div>
                        <div class="section-content">{proposal_data.get('terms', 'No terms provided.')}</div>
                    </div>
                </div>
                
                <!-- Action Buttons -->
                <div class="action-buttons">
                    <h3 style="margin-bottom: 20px; color: #2c3e50;">Ready to Proceed?</h3>
                    <button class="btn btn-outline" onclick="downloadPDF()">📥 Download PDF</button>
                    <button class="btn btn-outline" onclick="contactTeam()">💬 Contact Team</button>
                    <button class="btn btn-success" onclick="showSignatureModal()">✍️ Approve & Sign</button>
                </div>
                
                <!-- Signature Modal -->
                <div id="signatureModal" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000;">
                    <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: white; padding: 30px; border-radius: 12px; width: 90%; max-width: 600px;">
                        <h3 style="margin-bottom: 20px; color: #2c3e50;">Approve & Sign Proposal</h3>
                        <div class="signature-section">
                            <div class="signature-fields">
                                <div class="form-group">
                                    <label class="form-label">Full Name</label>
                                    <input type="text" class="form-input" id="signerName" placeholder="Enter your full name">
                                </div>
                                <div class="form-group">
                                    <label class="form-label">Title/Position</label>
                                    <input type="text" class="form-input" id="signerTitle" placeholder="Enter your title">
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Digital Signature</label>
                                <div class="signature-pad" id="signaturePad">
                                    <canvas id="signatureCanvas" width="400" height="120"></canvas>
                                    <div class="signature-placeholder" id="signaturePlaceholder">Click and drag to sign</div>
                                </div>
                                <div class="signature-actions">
                                    <button class="btn btn-outline btn-small" onclick="clearSignature()">Clear</button>
                                </div>
                            </div>
                            <div style="margin-top: 20px;">
                                <button class="btn btn-success" onclick="submitSignature()">Submit Signature</button>
                                <button class="btn btn-outline" onclick="closeSignatureModal()">Cancel</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <script>
                let isDrawing = false;
                let hasSignature = false;
                let canvas, ctx;
                
                function downloadPDF() {{
                    alert('PDF download functionality will be implemented');
                }}
                
                function contactTeam() {{
                    alert('Contact team functionality will be implemented');
                }}
                
                function showSignatureModal() {{
                    document.getElementById('signatureModal').style.display = 'block';
                    // Initialize signature pad when modal opens
                    setTimeout(initSignaturePad, 100);
                }}
                
                function closeSignatureModal() {{
                    document.getElementById('signatureModal').style.display = 'none';
                    // Reset signature pad
                    if (canvas && ctx) {{
                        ctx.clearRect(0, 0, canvas.width, canvas.height);
                        hasSignature = false;
                        document.getElementById('signaturePlaceholder').style.display = 'block';
                    }}
                }}
                
                function initSignaturePad() {{
                    canvas = document.getElementById('signatureCanvas');
                    ctx = canvas.getContext('2d');
                    
                    // Set up canvas properties
                    ctx.strokeStyle = '#2c3e50';
                    ctx.lineWidth = 2;
                    ctx.lineCap = 'round';
                    ctx.lineJoin = 'round';
                    
                    // Mouse events
                    canvas.addEventListener('mousedown', startDrawing);
                    canvas.addEventListener('mousemove', draw);
                    canvas.addEventListener('mouseup', stopDrawing);
                    canvas.addEventListener('mouseout', stopDrawing);
                    
                    // Touch events for mobile
                    canvas.addEventListener('touchstart', handleTouch);
                    canvas.addEventListener('touchmove', handleTouch);
                    canvas.addEventListener('touchend', stopDrawing);
                }}
                
                function startDrawing(e) {{
                    isDrawing = true;
                    hasSignature = true;
                    document.getElementById('signaturePlaceholder').style.display = 'none';
                    
                    const rect = canvas.getBoundingClientRect();
                    const x = e.clientX - rect.left;
                    const y = e.clientY - rect.top;
                    
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                }}
                
                function draw(e) {{
                    if (!isDrawing) return;
                    
                    const rect = canvas.getBoundingClientRect();
                    const x = e.clientX - rect.left;
                    const y = e.clientY - rect.top;
                    
                    ctx.lineTo(x, y);
                    ctx.stroke();
                }}
                
                function stopDrawing() {{
                    isDrawing = false;
                    ctx.beginPath();
                }}
                
                function handleTouch(e) {{
                    e.preventDefault();
                    const touch = e.touches[0];
                    const mouseEvent = new MouseEvent(e.type === 'touchstart' ? 'mousedown' : 
                                                   e.type === 'touchmove' ? 'mousemove' : 'mouseup', {{
                        clientX: touch.clientX,
                        clientY: touch.clientY
                    }});
                    canvas.dispatchEvent(mouseEvent);
                }}
                
                function clearSignature() {{
                    if (canvas && ctx) {{
                        ctx.clearRect(0, 0, canvas.width, canvas.height);
                        hasSignature = false;
                        document.getElementById('signaturePlaceholder').style.display = 'block';
                    }}
                }}
                
                function submitSignature() {{
                    const name = document.getElementById('signerName').value;
                    const title = document.getElementById('signerTitle').value;
                    
                    if (!name || !title) {{
                        alert('Please fill in all required fields');
                        return;
                    }}
                    
                    if (!hasSignature) {{
                        alert('Please provide your digital signature');
                        return;
                    }}
                    
                    // Get signature as data URL
                    const signatureData = canvas.toDataURL('image/png');
                    
                    // Submit signature to backend
                    fetch('/submit-signature', {{
                        method: 'POST',
                        headers: {{
                            'Content-Type': 'application/json',
                        }},
                        body: JSON.stringify({{
                            proposal_id: '{proposal_id}',
                            signer_name: name,
                            signer_title: title,
                            signature_data: signatureData
                        }})
                    }})
                    .then(response => response.json())
                    .then(data => {{
                        console.log('Signature submitted successfully:', data);
                        alert('Proposal approved and signed! Thank you for your business.');
                        closeSignatureModal();
                        
                        // Update the status badge to show approved
                        const statusBadge = document.querySelector('.status-badge');
                        if (statusBadge) {{
                            statusBadge.textContent = 'Approved';
                            statusBadge.style.backgroundColor = '#27ae60';
                        }}
                    }})
                    .catch(error => {{
                        console.error('Error submitting signature:', error);
                        alert('Error submitting signature. Please try again.');
                    }});
                }}
                
                // Close modal when clicking outside
                document.getElementById('signatureModal').addEventListener('click', function(e) {{
                    if (e.target === this) {{
                        closeSignatureModal();
                    }}
                }});
            </script>
        </body>
        </html>
        """
        
        return HTMLResponse(content=dashboard_html)
        
    except JWTError:
        return HTMLResponse(content="""
        <!DOCTYPE html>
        <html>
        <head><title>Invalid Access</title></head>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h1 style="color: #e74c3c;">Invalid or Expired Link</h1>
            <p>The dashboard link is invalid or has expired.</p>
            <p>Please contact us for a new access link.</p>
        </body>
        </html>
        """)
    except Exception as e:
        print(f"Dashboard error: {e}")
        return HTMLResponse(content=f"""
        <!DOCTYPE html>
        <html>
        <head><title>Error</title></head>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h1 style="color: #e74c3c;">Error</h1>
            <p>An error occurred while loading the dashboard.</p>
        </body>
        </html>
        """)

# Pydantic model for signature submission
class SignatureSubmission(BaseModel):
    proposal_id: str
    signer_name: str
    signer_title: str
    signature_data: str  # Base64 encoded signature image

@app.post("/submit-signature")
async def submit_signature(request: SignatureSubmission):
    """Submit client signature for proposal approval"""
    try:
        # Load existing signatures
        signatures = load_proposal_signatures()
        
        # Store signature data
        signatures[request.proposal_id] = {
            "proposal_id": request.proposal_id,
            "signer_name": request.signer_name,
            "signer_title": request.signer_title,
            "signature_data": request.signature_data,
            "signed_at": datetime.now().isoformat(),
            "status": "approved"
        }
        
        # Save signatures
        save_proposal_signatures(signatures)
        
        print(f"Signature submitted for proposal {request.proposal_id} by {request.signer_name}")
        
        return {
            "message": "Signature submitted successfully",
            "proposal_id": request.proposal_id,
            "status": "approved"
        }
        
    except Exception as e:
        print(f"Error submitting signature: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to submit signature"
        )

@app.get("/proposal-status/{proposal_id}")
async def get_proposal_status(proposal_id: str):
    """Get proposal approval status for business development dashboard"""
    try:
        signatures = load_proposal_signatures()
        
        if proposal_id in signatures:
            signature_data = signatures[proposal_id]
            return {
                "proposal_id": proposal_id,
                "status": signature_data["status"],
                "signed_by": signature_data["signer_name"],
                "signed_title": signature_data["signer_title"],
                "signed_at": signature_data["signed_at"],
                "is_approved": True
            }
        else:
            return {
                "proposal_id": proposal_id,
                "status": "pending",
                "is_approved": False
            }
            
    except Exception as e:
        print(f"Error getting proposal status: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get proposal status"
        )

@app.get("/me", response_model=User)
async def read_users_me(current_user: dict = Depends(get_current_user)):
    return User(
        id=current_user["id"],
        username=current_user["username"],
        email=current_user["email"],
        full_name=current_user["full_name"],
        role=current_user["role"],
        is_active=current_user["is_active"],
        is_verified=current_user.get("is_verified", False),
        created_at=current_user["created_at"],
        updated_at=current_user["updated_at"]
    )

@app.get("/", response_class=HTMLResponse)
async def verification_page(verify: bool = False, token: str = None):
    """Handle email verification page"""
    if verify and token:
        # Try to verify the token
        try:
            tokens_data = load_verification_tokens()
            users_data = load_users()
            
            # Find the token
            token_info = None
            for token_entry in tokens_data["tokens"]:
                if token_entry["token"] == token:
                    token_info = token_entry
                    break
            
            if not token_info:
                return HTMLResponse(content="""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Email Verification - Invalid Token</title>
                    <style>
                        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                        .error { color: #e74c3c; }
                        .success { color: #27ae60; }
                    </style>
                </head>
                <body>
                    <h1 class="error">Invalid Verification Token</h1>
                    <p>The verification token is invalid or has already been used.</p>
                    <p>Please try registering again or contact support.</p>
                </body>
                </html>
                """)
            
            # Check if token is expired
            token_expires = datetime.fromisoformat(token_info["expires_at"].replace("Z", "+00:00"))
            if datetime.utcnow().replace(tzinfo=token_expires.tzinfo) > token_expires:
                return HTMLResponse(content="""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Email Verification - Expired Token</title>
                    <style>
                        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                        .error { color: #e74c3c; }
                        .success { color: #27ae60; }
                    </style>
                </head>
                <body>
                    <h1 class="error">Verification Token Expired</h1>
                    <p>The verification token has expired. Please request a new verification email.</p>
                    <p>You can do this by trying to log in with your credentials.</p>
                </body>
                </html>
                """)
            
            # Find and update the user
            user_updated = False
            for user in users_data["users"]:
                if user["id"] == token_info["user_id"]:
                    user["is_verified"] = True
                    user["updated_at"] = now_iso()
                    user_updated = True
                    break
            
            if not user_updated:
                return HTMLResponse(content="""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Email Verification - User Not Found</title>
                    <style>
                        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                        .error { color: #e74c3c; }
                        .success { color: #27ae60; }
                    </style>
                </head>
                <body>
                    <h1 class="error">User Not Found</h1>
                    <p>The user associated with this verification token was not found.</p>
                    <p>Please try registering again or contact support.</p>
                </body>
                </html>
                """)
            
            # Save updated user data
            save_users(users_data)
            
            # Remove the used token
            tokens_data["tokens"] = [t for t in tokens_data["tokens"] if t["token"] != token]
            save_verification_tokens(tokens_data)
            
            return HTMLResponse(content="""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Email Verification - Success</title>
                <style>
                    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                    .error { color: #e74c3c; }
                    .success { color: #27ae60; }
                    .button { 
                        background-color: #3498DB; 
                        color: white; 
                        padding: 10px 20px; 
                        text-decoration: none; 
                        border-radius: 5px; 
                        display: inline-block;
                        margin: 10px;
                    }
                </style>
            </head>
            <body>
                <h1 class="success">Email Verified Successfully!</h1>
                <p>Your email has been verified. You can now log in to your account.</p>
                <a href="http://localhost:3000" class="button">Go to Login</a>
            </body>
            </html>
            """)
            
        except Exception as e:
            return HTMLResponse(content=f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Email Verification - Error</title>
                <style>
                    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                    .error { color: #e74c3c; }
                    .success { color: #27ae60; }
                </style>
            </head>
            <body>
                <h1 class="error">Verification Error</h1>
                <p>An error occurred during verification: {str(e)}</p>
                <p>Please try again or contact support.</p>
            </body>
            </html>
            """)
    
    # Default page (no verification parameters)
    return HTMLResponse(content="""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Proposal & SOW Builder API</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
            .api-link { color: #3498DB; text-decoration: none; }
        </style>
    </head>
    <body>
        <h1>Proposal & SOW Builder API</h1>
        <p>Backend API is running successfully!</p>
        <p><a href="/docs" class="api-link">View API Documentation</a></p>
    </body>
    </html>
    """)

@app.get("/users", response_model=List[User])
async def list_users(current_user: dict = Depends(get_current_user)):
    # Only admins can list all users
    if current_user["role"] != "Admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    users_data = load_users()
    users = []
    for user in users_data["users"]:
        users.append(User(
            id=user["id"],
            username=user["username"],
            email=user["email"],
            full_name=user["full_name"],
            role=user["role"],
            is_active=user["is_active"],
            created_at=user["created_at"],
            updated_at=user["updated_at"]
        ))
    return users

@app.put("/users/{user_id}/role")
async def update_user_role(
    user_id: str, 
    new_role: Literal["Business Developer", "Reviewer / Approver", "Admin"],
    current_user: dict = Depends(get_current_user)
):
    # Only admins can update user roles
    if current_user["role"] != "Admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    users_data = load_users()
    user_found = False
    
    for user in users_data["users"]:
        if user["id"] == user_id:
            user["role"] = new_role
            user["updated_at"] = now_iso()
            user_found = True
            break
    
    if not user_found:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    save_users(users_data)
    return {"message": "User role updated successfully"}

# ---------- Client Portal Routes ----------
@app.get("/client/proposals")
async def get_client_proposals():
    """Get proposals visible to clients (only released and signed proposals)"""
    db = load_db()
    client_proposals = []
    for proposal in db["proposals"]:
        if proposal["status"] in ["Released", "Signed"]:
            client_proposals.append({
                "id": proposal["id"],
                "title": proposal["title"],
                "client": proposal["client"],
                "status": proposal["status"],
                "created_at": proposal["created_at"],
                "signed_at": proposal.get("signed_at"),
                "signed_by": proposal.get("signed_by"),
            })
    return client_proposals

@app.get("/client/proposals/{proposal_id}")
async def get_client_proposal(proposal_id: str):
    """Get a specific proposal for client review"""
    db = load_db()
    for proposal in db["proposals"]:
        if proposal["id"] == proposal_id and proposal["status"] in ["Released", "Signed"]:
            return {
                "id": proposal["id"],
                "title": proposal["title"],
                "client": proposal["client"],
                "status": proposal["status"],
                "sections": proposal["sections"],
                "created_at": proposal["created_at"],
                "signed_at": proposal.get("signed_at"),
                "signed_by": proposal.get("signed_by"),
            }
    raise HTTPException(status_code=404, detail="Proposal not found or not accessible")

@app.post("/client/proposals/{proposal_id}/sign")
async def client_sign_proposal(proposal_id: str, payload: SignPayload):
    """Allow clients to sign proposals"""
    db = load_db()
    for i, proposal in enumerate(db["proposals"]):
        if proposal["id"] == proposal_id and proposal["status"] == "Released":
            db["proposals"][i]["status"] = "Signed"
            db["proposals"][i]["signed_at"] = now_iso()
            db["proposals"][i]["signed_by"] = payload.signer_name
            db["proposals"][i]["updated_at"] = now_iso()
            save_db(db)
            return {"message": "Proposal signed successfully"}
    raise HTTPException(status_code=404, detail="Proposal not found or not available for signing")


# Simple feedback storage
FEEDBACK_PATH = os.path.join(BASE_DIR, "proposal_feedback.json")

def load_feedback():
    if not os.path.exists(FEEDBACK_PATH):
        with open(FEEDBACK_PATH, "w", encoding="utf-8") as f:
            json.dump({"feedback": []}, f, indent=2)
    with open(FEEDBACK_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_feedback(data):
    with open(FEEDBACK_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


@app.post("/client/proposals/feedback")
async def submit_client_feedback(payload: Dict[str, Any]):
    """Accepts { email, message, proposal_id? } and stores feedback."""
    fb = load_feedback()
    entry = {
        "id": str(uuid.uuid4()),
        "email": payload.get("email"),
        "message": payload.get("message"),
        "proposal_id": payload.get("proposal_id"),
        "created_at": now_iso()
    }
    fb["feedback"].append(entry)
    save_feedback(fb)
    return {"message": "Feedback received"}



# Signature endpoints for client dashboard
@app.post("/client-dashboard/{token}/sign")
async def sign_proposal_with_token(
    token: str,
    signature_data: dict
):
    """Sign a proposal using the client token"""
    try:
        # Validate token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        client_email = payload.get('client_email')
        proposal_id = payload.get('proposal_id')
        
        if not client_email or not proposal_id:
            raise HTTPException(status_code=400, detail="Invalid token")
        
        # Update proposal status to signed
        db = load_db()
        if proposal_id in db["proposals"]:
            db["proposals"][proposal_id]["status"] = "Signed"
            db["proposals"][proposal_id]["signed_by"] = client_email
            db["proposals"][proposal_id]["signed_at"] = datetime.now().isoformat()
            save_db(db)
            
            return {"message": "Proposal signed successfully", "status": "Signed"}
        else:
            raise HTTPException(status_code=404, detail="Proposal not found")
            
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/client-dashboard/{token}/pdf")
async def get_signed_pdf_url(token: str):
    """Get signed PDF URL for a proposal"""
    try:
        # Validate token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        proposal_id = payload.get('proposal_id')
        
        if not proposal_id:
            raise HTTPException(status_code=400, detail="Invalid token")
        
        # For demo purposes, return a placeholder URL
        # In production, this would generate and return the actual signed PDF URL
        return {"pdf_url": f"http://localhost:8000/signed-pdfs/{proposal_id}_signed.pdf"}
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/client-dashboard-mini/{token}", response_class=HTMLResponse)
async def client_dashboard_mini(token: str):
        """Redirect to Flutter client portal with token"""
        try:
                # Validate token first
                payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                client_email = payload.get('client_email')
                if not client_email:
                        raise HTTPException(status_code=400, detail="Invalid token")

                # Create a redirect page that loads the Flutter app
                html = f"""
                <!doctype html>
                <html>
                <head>
                    <meta charset="utf-8" />
                    <meta name="viewport" content="width=device-width, initial-scale=1" />
                    <title>Client Dashboard - Loading...</title>
                    <style>
                        body {{
                            font-family: 'Segoe UI', Arial, sans-serif;
                            margin: 0;
                            padding: 0;
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            height: 100vh;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                        }}
                        .loading-container {{
                            text-align: center;
                            color: white;
                        }}
                        .spinner {{
                            border: 4px solid #f3f3f3;
                            border-top: 4px solid #3498db;
                            border-radius: 50%;
                            width: 50px;
                            height: 50px;
                            animation: spin 2s linear infinite;
                            margin: 20px auto;
                        }}
                        @keyframes spin {{
                            0% {{ transform: rotate(0deg); }}
                            100% {{ transform: rotate(360deg); }}
                        }}
                        .redirect-btn {{
                            background: #3498db;
                            color: white;
                            padding: 12px 24px;
                            border: none;
                            border-radius: 6px;
                            font-size: 16px;
                            cursor: pointer;
                            margin-top: 20px;
                        }}
                        .redirect-btn:hover {{
                            background: #2980b9;
                        }}
                    </style>
                </head>
                <body>
                    <div class="loading-container">
                        <h2>Client Dashboard</h2>
                        <p>Welcome, {client_email}</p>
                        <div class="spinner"></div>
                        <p>Loading your dashboard...</p>
                        <button class="redirect-btn" onclick="openFlutterApp()">Open Full Dashboard</button>
                    </div>
                    
                    <script>
                        // Store token in localStorage for Flutter app
                        localStorage.setItem('client_token', '{token}');
                        localStorage.setItem('client_email', '{client_email}');
                        
                        function openFlutterApp() {{
                            // Try to open Flutter app in new tab
                            const flutterUrl = 'http://localhost:3000/enhanced-client-dashboard?token={token}';
                            window.open(flutterUrl, '_blank');
                        }}
                        
                        // Auto-redirect after 3 seconds
                        setTimeout(() => {{
                            openFlutterApp();
                        }}, 3000);
                    </script>
                </body>
                </html>
                """
                return HTMLResponse(content=html)
        except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))

@app.get("/client/dashboard_stats")
async def get_client_dashboard_stats():
    """Get dashboard statistics for client portal"""
    db = load_db()
    stats = {
        "pending_review": 0,
        "signed_documents": 0,
        "total_proposals": 0,
        "avg_response_time": 4.2,  # Mock data
        "active_projects": 2,  # Mock data
    }
    
    for proposal in db["proposals"]:
        if proposal["status"] == "Released":
            stats["pending_review"] += 1
        elif proposal["status"] == "Signed":
            stats["signed_documents"] += 1
        if proposal["status"] in ["Released", "Signed"]:
            stats["total_proposals"] += 1
    
    return stats

# PDF export (same as before)
@app.get("/proposals/{pid}/export_pdf")
def export_proposal_pdf(pid: str):
    p = get_proposal_or_404(pid)
    buffer = io.BytesIO()
    c = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    margin = 50
    y = height - margin
    c.setFont("Helvetica-Bold", 16)
    c.drawString(margin, y, (p.title or "")[:80])
    c.setFont("Helvetica", 11)
    y -= 30
    c.drawString(margin, y, f"Type: {p.dtype}    Client: {p.client}    Status: {p.status}")
    y -= 20
    c.drawString(margin, y, f"Readiness: {p.readiness_score}%")
    y -= 30
    for k, v in p.sections.items():
        c.setFont("Helvetica-Bold", 12)
        if y < 120:
            c.showPage()
            y = height - margin
        c.drawString(margin, y, str(k))
        y -= 18
        c.setFont("Helvetica", 10)
        text = str(v)[:3000]
        lines = []
        while text:
            lines.append(text[:120])
            text = text[120:]
        for ln in lines:
            if y < 80:
                c.showPage()
                y = height - margin
            c.drawString(margin, y, ln)
            y -= 14
        y -= 10
    if p.signed_by:
        c.setFont("Helvetica", 10)
        c.drawString(margin, 40, f"Signed by {p.signed_by} at {p.signed_at}")
    c.showPage()
    c.save()
    buffer.seek(0)
    return StreamingResponse(buffer, media_type="application/pdf", headers={"Content-Disposition":f"attachment; filename=proposal_{p.id}.pdf"})

# ---------- Cloudinary Upload Endpoints ----------
from fastapi import File, UploadFile
from cloudinary_config import get_cloudinary_upload_signature, upload_to_cloudinary, delete_from_cloudinary
import tempfile

@app.post("/upload/signature")
async def get_upload_signature(payload: dict = Body(...)):
    """Generate a signed upload signature for frontend direct uploads"""
    try:
        public_id = payload.get("public_id", f"upload_{uuid.uuid4()}")
        sig_data = get_cloudinary_upload_signature(public_id)
        return {"success": True, **sig_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upload/image")
async def upload_image(file: UploadFile = File(...)):
    """Upload an image to Cloudinary via backend"""
    tmp_path = None
    try:
        # Save file temporarily with proper flushing
        with tempfile.NamedTemporaryFile(delete=False, suffix='.tmp') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp.flush()  # Ensure data is written to disk
            tmp_path = tmp.name
        
        # Upload to Cloudinary
        result = upload_to_cloudinary(tmp_path, resource_type="image", folder="proposal_builder/images")
        
        if result["success"]:
            return {
                "success": True,
                "url": result["url"],
                "public_id": result["public_id"],
                "filename": file.filename,
                "size": result.get("size", 0),
            }
        else:
            raise HTTPException(status_code=500, detail=result["error"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up temp file
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except:
                pass

@app.post("/upload/template")
async def upload_template(file: UploadFile = File(...)):
    """Upload a template file to Cloudinary"""
    tmp_path = None
    try:
        # Save file temporarily with proper flushing
        with tempfile.NamedTemporaryFile(delete=False, suffix='.tmp') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp.flush()  # Ensure data is written to disk
            tmp_path = tmp.name
        
        # Upload to Cloudinary
        result = upload_to_cloudinary(tmp_path, resource_type="raw", folder="proposal_builder/templates")
        
        if result["success"]:
            return {
                "success": True,
                "url": result["url"],
                "public_id": result["public_id"],
                "filename": file.filename,
                "size": result.get("size", 0),
            }
        else:
            raise HTTPException(status_code=500, detail=result["error"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up temp file
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except:
                pass

@app.delete("/upload/{public_id}")
async def delete_upload(public_id: str):
    """Delete an uploaded file from Cloudinary"""
    try:
        result = delete_from_cloudinary(public_id)
        if result["success"]:
            return {"success": True, "message": "File deleted from Cloudinary"}
        else:
            raise HTTPException(status_code=500, detail=result["error"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# E-sign request mock (same as before)
@app.post("/proposals/{pid}/create_esign_request")
def create_esign_request(pid: str, payload: dict = Body({})):
    p = get_proposal_or_404(pid)
    if p.status != "Released":
        raise HTTPException(status_code=400, detail="Document must be Released before sending e-sign request.")
    provider = os.environ.get("ESIGN_PROVIDER","").lower()
    if not provider:
        p.sections["_esign_request"] = {"status":"mock_sent","url":f"https://example.com/mock-sign/{p.id}","requested_at":now_iso()}
        p.updated_at = now_iso()
        save_proposal(p)
        return {"mode":"mock","sign_url":p.sections["_esign_request"]["url"]}
    raise HTTPException(status_code=501, detail="Real provider integration not implemented in this demo.")

# ---------- AI-Powered Features ----------
# Import AI service
try:
    from ai_service import ai_service
    AI_ENABLED = True
except Exception as e:
    print(f"Warning: AI service not available: {e}")
    AI_ENABLED = False

class AIAnalysisRequest(BaseModel):
    proposal_id: str

class AIGenerateRequest(BaseModel):
    section_type: str
    context: Dict[str, Any]

class AIImproveRequest(BaseModel):
    content: str
    section_type: str

@app.post("/ai/analyze-risks")
async def analyze_proposal_risks(request: AIAnalysisRequest, current_user: dict = Depends(get_current_user)):
    """
    AI-powered risk analysis for proposals (Wildcard Challenge)
    Detects compound risks and compliance issues
    """
    if not AI_ENABLED:
        raise HTTPException(status_code=503, detail="AI service not available")
    
    try:
        # Get proposal
        p = get_proposal_or_404(request.proposal_id)
        
        # Prepare proposal data for AI analysis
        proposal_data = {
            "id": p.id,
            "title": p.title,
            "client": p.client,
            "type": p.dtype,
            "status": p.status,
            "sections": p.sections,
            "mandatory_sections": p.mandatory_sections,
            "readiness_score": p.readiness_score,
            "readiness_issues": p.readiness_issues
        }
        
        # Call AI service
        analysis = ai_service.analyze_proposal_risks(proposal_data)
        
        return {
            "success": True,
            "proposal_id": request.proposal_id,
            "analysis": analysis
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI analysis failed: {str(e)}")

@app.post("/ai/generate-section")
async def generate_section(request: AIGenerateRequest, current_user: dict = Depends(get_current_user)):
    """
    AI-powered content generation for proposal sections
    """
    if not AI_ENABLED:
        raise HTTPException(status_code=503, detail="AI service not available")
    
    try:
        content = ai_service.generate_proposal_section(
            section_type=request.section_type,
            context=request.context
        )
        
        return {
            "success": True,
            "section_type": request.section_type,
            "generated_content": content
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Content generation failed: {str(e)}")

@app.post("/ai/improve-content")
async def improve_content(request: AIImproveRequest, current_user: dict = Depends(get_current_user)):
    """
    AI-powered content improvement suggestions
    """
    if not AI_ENABLED:
        raise HTTPException(status_code=503, detail="AI service not available")
    
    try:
        improvements = ai_service.improve_content(
            content=request.content,
            section_type=request.section_type
        )
        
        return {
            "success": True,
            "improvements": improvements
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Content improvement failed: {str(e)}")

@app.post("/ai/check-compliance")
async def check_compliance(request: AIAnalysisRequest, current_user: dict = Depends(get_current_user)):
    """
    AI-powered compliance checking
    """
    if not AI_ENABLED:
        raise HTTPException(status_code=503, detail="AI service not available")
    
    try:
        # Get proposal
        p = get_proposal_or_404(request.proposal_id)
        
        # Prepare proposal data
        proposal_data = {
            "id": p.id,
            "title": p.title,
            "client": p.client,
            "type": p.dtype,
            "sections": p.sections,
            "mandatory_sections": p.mandatory_sections
        }
        
        # Call AI service
        compliance = ai_service.check_compliance(proposal_data)
        
        return {
            "success": True,
            "proposal_id": request.proposal_id,
            "compliance": compliance
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Compliance check failed: {str(e)}")

@app.get("/ai/status")
async def ai_status():
    """Check if AI service is available"""
    return {
        "ai_enabled": AI_ENABLED,
        "model": os.getenv("OPENROUTER_MODEL", "not configured") if AI_ENABLED else None,
        "status": "operational" if AI_ENABLED else "unavailable"
    }

# ---------- Content Library Endpoints ----------

@app.get("/content", response_model=List[ContentBlockOut])
async def get_content(category: Optional[str] = None):
    """Get all content blocks or filter by category"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                if category:
                    cur.execute(
                        "SELECT id, key, label, content, COALESCE(category, 'Templates'), is_folder, parent_id, created_at, updated_at FROM content_blocks WHERE COALESCE(category, 'Templates') = %s ORDER BY created_at DESC",
                        (category,)
                    )
                else:
                    cur.execute(
                        "SELECT id, key, label, content, COALESCE(category, 'Templates'), is_folder, parent_id, created_at, updated_at FROM content_blocks ORDER BY created_at DESC"
                    )
                rows = cur.fetchall()
                return [
                    {
                        "id": row[0],
                        "key": row[1],
                        "label": row[2],
                        "content": row[3],
                        "category": row[4],
                        "is_folder": row[5],
                        "parent_id": row[6],
                        "created_at": row[7].isoformat() if hasattr(row[7], 'isoformat') else str(row[7]),
                        "updated_at": row[8].isoformat() if hasattr(row[8], 'isoformat') else str(row[8])
                    }
                    for row in rows
                ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/content", response_model=ContentBlockOut)
async def create_content(block: ContentBlockIn):
    """Create a new content block"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO content_blocks (key, label, content, category, is_folder, parent_id, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id, key, label, content, COALESCE(category, 'Templates'), is_folder, parent_id, created_at, updated_at""",
                    (block.key, block.label, block.content, block.category, block.is_folder, block.parent_id)
                )
                row = cur.fetchone()
                conn.commit()
                return {
                    "id": row[0],
                    "key": row[1],
                    "label": row[2],
                    "content": row[3],
                    "category": row[4],
                    "is_folder": row[5],
                    "parent_id": row[6],
                    "created_at": row[7].isoformat() if hasattr(row[7], 'isoformat') else str(row[7]),
                    "updated_at": row[8].isoformat() if hasattr(row[8], 'isoformat') else str(row[8])
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/content/{content_id}", response_model=ContentBlockOut)
async def update_content(content_id: int, block: ContentBlockIn):
    """Update an existing content block"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE content_blocks 
                    SET key = %s, label = %s, content = %s, category = %s, is_folder = %s, parent_id = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                    RETURNING id, key, label, content, COALESCE(category, 'Templates'), is_folder, parent_id, created_at, updated_at""",
                    (block.key, block.label, block.content, block.category, block.is_folder, block.parent_id, content_id)
                )
                row = cur.fetchone()
                conn.commit()
                if not row:
                    raise HTTPException(status_code=404, detail="Content block not found")
                return {
                    "id": row[0],
                    "key": row[1],
                    "label": row[2],
                    "content": row[3],
                    "category": row[4],
                    "is_folder": row[5],
                    "parent_id": row[6],
                    "created_at": row[7].isoformat() if hasattr(row[7], 'isoformat') else str(row[7]),
                    "updated_at": row[8].isoformat() if hasattr(row[8], 'isoformat') else str(row[8])
                }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/content/{content_id}")
async def delete_content(content_id: int):
    """Delete a content block"""
    try:
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM content_blocks WHERE id = %s", (content_id,))
                if cur.rowcount == 0:
                    raise HTTPException(status_code=404, detail="Content block not found")
                conn.commit()
                return {"message": "Content block deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ---------- File Upload Endpoints ----------

@app.post("/upload/image")
async def upload_image(file: UploadFile = File(...)):
    """Upload an image to Cloudinary"""
    try:
        # Validate file extension
        allowed_extensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico', 'tiff'}
        file_ext = file.filename.split('.')[-1].lower() if file.filename else ""
        
        if file_ext not in allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed types: {', '.join(allowed_extensions)}"
            )
        
        # Read file content
        content = await file.read()
        
        # Save temporarily to upload via Cloudinary SDK
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as temp_file:
            temp_file.write(content)
            temp_path = temp_file.name
        
        try:
            # Upload to Cloudinary
            result = upload_to_cloudinary(temp_path, resource_type="image", folder="proposal_builder/images")
            
            if result.get("success"):
                return {
                    "success": True,
                    "url": result.get("url"),
                    "public_id": result.get("public_id"),
                    "resource_type": result.get("resource_type")
                }
            else:
                raise HTTPException(
                    status_code=500,
                    detail=f"Cloudinary upload failed: {result.get('error', 'Unknown error')}"
                )
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@app.post("/upload/template")
async def upload_template(file: UploadFile = File(...)):
    """Upload a document/template to Cloudinary"""
    try:
        # Validate file extension
        allowed_extensions = {
            'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt',  # Documents
            'jpg', 'jpeg', 'png'  # Images for sections
        }
        file_ext = file.filename.split('.')[-1].lower() if file.filename else ""
        
        if file_ext not in allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed types: {', '.join(sorted(allowed_extensions))}"
            )
        
        # Read file content
        content = await file.read()
        
        # Save temporarily to upload via Cloudinary SDK
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as temp_file:
            temp_file.write(content)
            temp_path = temp_file.name
        
        try:
            # Determine resource type based on file extension
            resource_type = "image" if file_ext in {'jpg', 'jpeg', 'png'} else "raw"
            
            # Upload to Cloudinary
            result = upload_to_cloudinary(temp_path, resource_type=resource_type, folder="proposal_builder/documents")
            
            if result.get("success"):
                return {
                    "success": True,
                    "url": result.get("url"),
                    "public_id": result.get("public_id"),
                    "resource_type": result.get("resource_type")
                }
            else:
                raise HTTPException(
                    status_code=500,
                    detail=f"Cloudinary upload failed: {result.get('error', 'Unknown error')}"
                )
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
