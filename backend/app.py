from fastapi import FastAPI, HTTPException, Body, Query, Depends, status
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

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, "storage.json")
SQLITE_PATH = os.path.join(BASE_DIR, "content.db")
USERS_DB_PATH = os.path.join(BASE_DIR, "users.json")
VERIFICATION_TOKENS_PATH = os.path.join(BASE_DIR, "verification_tokens.json")

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
        created_at TEXT,
        updated_at TEXT
    )
    """)
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

# Initialize sqlite and seed content blocks
init_sqlite()
def seed_content_blocks():
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    # Seed only if table empty
    cur.execute("SELECT COUNT(*) FROM content_blocks")
    if cur.fetchone()[0] == 0:
        now = now_iso()
        blocks = [
            ("company_profile","Company Profile","Khonology is a specialist consultancy focused on data and AI.", now, now),
            ("capabilities","Capabilities","Data, AI, Cloud, Advisory.", now, now),
            ("delivery_approach","Delivery Approach","Agile, Iterative, Outcome-driven.", now, now),
            ("assumptions","Assumptions","Client provides timely access to stakeholders and data.", now, now),
            ("risks","Risks","Potential scope creep; third-party dependencies.", now, now),
            ("references","References","Case studies: Project A — improved X by 40%.", now, now),
            ("bios","Team Bios","Jane Doe (Lead) — 10 years in data projects.", now, now),
            ("terms","Terms","Standard Khonology terms and conditions.", now, now)
        ]
        cur.executemany("INSERT INTO content_blocks (key,label,content,created_at,updated_at) VALUES (?,?,?,?,?)", blocks)
        conn.commit()
    conn.close()

seed_content_blocks()

# ---------- Data Models ----------
Status = Literal["Draft","In Review","Released","Signed","Archived"]
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

class ProposalDraft(BaseModel):
    sections: Dict[str, Any] = {}
    version: str = "draft"
    auto_saved: bool = False
    timestamp: str = Field(default_factory=now_iso)
    user_id: Optional[str] = None

class ProposalVersion(BaseModel):
    id: str
    proposal_id: str
    title: str
    description: str
    sections: Dict[str, Any] = {}
    is_major: bool = False
    created_by: str
    created_at: str = Field(default_factory=now_iso)
    restored_from: Optional[str] = None

class VersionCreate(BaseModel):
    title: str
    description: str
    sections: Dict[str, Any] = {}
    is_major: bool = False
    created_by: str

class ContentBlockIn(BaseModel):
    key: str
    label: str
    content: str

class ContentBlockOut(BaseModel):
    id: int
    key: str
    label: str
    content: str
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
    role: Literal["Business Developer", "Reviewer / Approver", "Admin"] = "Business Developer"

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

# ---------- App ----------
app = FastAPI(title="Proposal & SOW Builder API v2", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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

# ---------- Routes: Content Library (SQLite) ----------
@app.get("/content", response_model=List[ContentBlockOut])
def list_content():
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT id,key,label,content,created_at,updated_at FROM content_blocks ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()
    out = []
    for r in rows:
        out.append({"id": r[0], "key": r[1], "label": r[2], "content": r[3], "created_at": r[4], "updated_at": r[5]})
    return out

@app.post("/content", response_model=ContentBlockOut)
def create_content(block: ContentBlockIn):
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    now = now_iso()
    try:
        cur.execute("INSERT INTO content_blocks (key,label,content,created_at,updated_at) VALUES (?,?,?,?,?)",
                    (block.key, block.label, block.content, now, now))
        conn.commit()
        cid = cur.lastrowid
        cur.execute("SELECT id,key,label,content,created_at,updated_at FROM content_blocks WHERE id=?", (cid,))
        r = cur.fetchone()
        conn.close()
        return {"id": r[0], "key": r[1], "label": r[2], "content": r[3], "created_at": r[4], "updated_at": r[5]}
    except sqlite3.IntegrityError as e:
        conn.close()
        raise HTTPException(status_code=400, detail="Key already exists or invalid.")

@app.put("/content/{cid}", response_model=ContentBlockOut)
def update_content(cid: int, block: ContentBlockIn):
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    now = now_iso()
    cur.execute("UPDATE content_blocks SET key=?,label=?,content=?,updated_at=? WHERE id=?",
                (block.key, block.label, block.content, now, cid))
    conn.commit()
    cur.execute("SELECT id,key,label,content,created_at,updated_at FROM content_blocks WHERE id=?", (cid,))
    r = cur.fetchone()
    conn.close()
    if not r:
        raise HTTPException(status_code=404, detail="Content block not found")
    return {"id": r[0], "key": r[1], "label": r[2], "content": r[3], "created_at": r[4], "updated_at": r[5]}

@app.delete("/content/{cid}")
def delete_content(cid: int):
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM content_blocks WHERE id=?", (cid,))
    conn.commit()
    affected = cur.rowcount
    conn.close()
    if affected == 0:
        raise HTTPException(status_code=404, detail="Content block not found")
    return {"deleted": cid}

# ---------- Routes: Templates & Proposals (JSON storage) ----------
@app.get("/templates")
def list_templates():
    db = load_db()
    return db.get("templates", [])

@app.get("/proposals")
def list_proposals():
    return load_db()["proposals"]

@app.post("/proposals", response_model=Proposal)
def create_proposal(payload: ProposalCreate):
    db = load_db()
    p = Proposal(
        id=str(uuid.uuid4()),
        title=payload.title,
        client=payload.client,
        dtype=payload.dtype or "Proposal",
    )
    if payload.template_key:
        tmpl = next((t for t in db.get("templates",[]) if t.get("key")==payload.template_key), None)
        if tmpl:
            for sec in tmpl.get("sections",[]):
                p.sections[sec] = ""
            p.mandatory_sections = tmpl.get("sections", p.mandatory_sections)
            p.dtype = tmpl.get("dtype", p.dtype)
    p = compute_readiness_and_risk(p)
    save_proposal(p)
    return p

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

@app.post("/proposals/{pid}/submit", response_model=Proposal)
def submit_for_review(pid: str):
    p = get_proposal_or_404(pid)
    p = compute_readiness_and_risk(p)
    if p.readiness_issues and any(i.startswith("Missing mandatory section") for i in p.readiness_issues):
        raise HTTPException(status_code=400, detail={"message":"Readiness checks failed","issues":p.readiness_issues})
    if getattr(p, "_compound_minor_devs", 0) >= 2:
        raise HTTPException(status_code=400, detail={"message":"Compound minor deviations detected, please resolve","issues":p.readiness_issues})
    p.status = "In Review"
    p.updated_at = now_iso()
    save_proposal(p)
    return p

# Import the new service
from proposal_versions_service import ProposalVersionsService

# Initialize the service
versions_service = ProposalVersionsService()

# Auto-draft endpoints
@app.put("/proposals/{pid}/draft")
def save_draft(pid: str, payload: ProposalDraft):
    """Save auto-draft version of proposal"""
    p = get_proposal_or_404(pid)
    p.sections.update(payload.sections)
    p.updated_at = now_iso()
    save_proposal(p)
    return {"message": "Draft saved successfully", "timestamp": payload.timestamp}

@app.post("/proposals/{pid}/autosave")
def autosave_proposal(pid: str, payload: ProposalDraft):
    """Auto-save proposal and create version history entry"""
    p = get_proposal_or_404(pid)
    
    # Get previous sections for comparison
    previous_sections = p.sections.copy()
    
    # Update proposal with new sections
    p.sections.update(payload.sections)
    p.updated_at = now_iso()
    save_proposal(p)
    
    # Create version history entry if there are changes
    if previous_sections != payload.sections:
        try:
            version = versions_service.create_version(
                proposal_id=pid,
                content=payload.sections,
                created_by=payload.user_id or "system"
            )
            
            return {
                "message": "Autosaved",
                "version_id": version['id'],
                "saved_at": payload.timestamp
            }
        except Exception as e:
            print(f"Error creating version: {e}")
            import traceback
            traceback.print_exc()
            return {
                "message": "Autosaved but version creation failed",
                "saved_at": payload.timestamp
            }
    
    return {
        "message": "No changes to save",
        "saved_at": payload.timestamp
    }

# Versioning endpoints
@app.get("/proposals/{pid}/versions")
def get_proposal_versions(pid: str):
    """Get all versions for a proposal"""
    try:
        versions = versions_service.get_versions(pid)
        return {"versions": versions}
    except Exception as e:
        print(f"Error getting versions: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve versions")

@app.post("/proposals/{pid}/versions")
def create_proposal_version(pid: str, payload: VersionCreate):
    """Create a new version of a proposal"""
    p = get_proposal_or_404(pid)
    
    try:
        version = versions_service.create_version(
            proposal_id=pid,
            content=payload.sections,
            created_by=payload.created_by
        )
        
        # Convert to the expected format for compatibility
        return {
            "id": version['id'],
            "proposal_id": version['proposal_id'],
            "title": payload.title,
            "description": payload.description,
            "sections": version['content'],
            "is_major": payload.is_major,
            "created_by": version['created_by'],
            "created_at": version['created_at']
        }
    except Exception as e:
        print(f"Error creating version: {e}")
        raise HTTPException(status_code=500, detail="Failed to create version")

@app.post("/proposals/{pid}/versions/{version_id}/restore")
def restore_proposal_version(pid: str, version_id: str):
    """Restore a proposal to a specific version"""
    p = get_proposal_or_404(pid)
    
    try:
        # Get the version
        version = versions_service.get_version(pid, version_id)
        if not version:
            raise HTTPException(status_code=404, detail="Version not found")
        
        # Restore sections
        p.sections = version["content"]
        p.updated_at = now_iso()
        save_proposal(p)
        
        return {"message": "Version restored successfully"}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error restoring version: {e}")
        raise HTTPException(status_code=500, detail="Failed to restore version")

@app.delete("/proposals/{pid}/versions/{version_id}")
def delete_proposal_version(pid: str, version_id: str):
    """Delete a specific version"""
    try:
        success = versions_service.delete_version(pid, version_id)
        if not success:
            raise HTTPException(status_code=404, detail="Version not found")
        
        return {"message": "Version deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error deleting version: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete version")

@app.get("/proposals/{pid}/versions/diff")
def get_version_diff(pid: str, from_version: str = Query(..., alias="from"), to_version: str = Query(..., alias="to")):
    """Get differences between two versions"""
    try:
        diff = versions_service.get_version_diff(pid, from_version, to_version)
        return diff
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f"Error getting version diff: {e}")
        raise HTTPException(status_code=500, detail="Failed to get version diff")

@app.post("/proposals/{pid}/approve", response_model=Proposal)
def approve_stage(pid: str, stage: Stage = Query(..., description="Approval stage: Delivery | Legal | Exec")):
    p = get_proposal_or_404(pid)
    if p.status not in ["In Review","Released"]:
        raise HTTPException(status_code=400, detail="Proposal must be In Review to approve stages.")
    p.approval.approvals[stage] = {"approved": True, "at": now_iso()}
    if p.approval.mode == "sequential":
        all_ok = all(s in p.approval.approvals for s in p.approval.order)
    else:
        all_ok = all(s in p.approval.approvals for s in ["Delivery","Legal","Exec"])
    if all_ok:
        p.status = "Released"
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.post("/proposals/{pid}/sign", response_model=Proposal)
def sign_proposal(pid: str, payload: SignPayload):
    p = get_proposal_or_404(pid)
    if p.status != "Released":
        raise HTTPException(status_code=400, detail="Proposal must be Released before client sign-off.")
    p.status = "Signed"
    p.signed_at = now_iso()
    p.signed_by = payload.signer_name
    p.updated_at = now_iso()
    save_proposal(p)
    return p

@app.get("/dashboard_stats")
def dashboard_stats():
    db = load_db()
    counts = {"Draft":0,"In Review":0,"Released":0,"Signed":0,"Archived":0}
    for pr in db["proposals"]:
        counts[pr["status"]] = counts.get(pr["status"],0)+1
    return {"counts":counts,"total":sum(counts.values())}

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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
