from fastapi import FastAPI, HTTPException, Body, Query, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional, Dict, Any, Literal
import json, os, uuid, time, sqlite3
import urllib.request, urllib.error
# Load environment variables from a .env file if present
try:
    from dotenv import load_dotenv, find_dotenv
    _dotenv = find_dotenv(usecwd=True) or os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    load_dotenv(_dotenv)
except Exception:
    # If python-dotenv is not installed yet, env vars must come from the shell
    pass
from datetime import datetime, timedelta
from reportlab.lib.pagesizes import A4, letter
from reportlab.pdfgen import canvas
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.units import inch
import io
from fastapi.responses import StreamingResponse, HTMLResponse, FileResponse
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
import secrets
import psycopg2
import psycopg2.extras
import tempfile
from settings import router as settings_router
from reviewer_routes import router as reviewer_router

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

def load_proposal_signatures():
    try:
        with open('proposal_signatures.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

def save_proposal_signatures(signatures_data):
    with open('proposal_signatures.json', 'w') as f:
        json.dump(signatures_data, f, indent=2)

def generate_verification_token():
    return secrets.token_urlsafe(32)

def generate_client_dashboard_token(proposal_id: str, client_email: str, proposal_data: Dict[str, Any] = None):
    """Generate a secure token for client dashboard access"""
    payload = {
        'proposal_id': proposal_id,
        'client_email': client_email,
        'proposal_data': proposal_data or {},
        'exp': datetime.utcnow() + timedelta(days=30)  # 30 days expiry
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def generate_proposal_pdf(proposal_data: Dict[str, Any], filename: str):
    """Generate a professional PDF proposal"""
    try:
        doc = SimpleDocTemplate(filename, pagesize=letter)
        styles = getSampleStyleSheet()
        
        # Custom styles
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            spaceAfter=30,
            alignment=1  # Center alignment
        )
        
        heading_style = ParagraphStyle(
            'CustomHeading',
            parent=styles['Heading2'],
            fontSize=16,
            spaceAfter=12,
            spaceBefore=20
        )
        
        # Build PDF content
        story = []
        
        # Title
        story.append(Paragraph(str(proposal_data.get('title', 'Business Proposal')), title_style))
        story.append(Spacer(1, 20))
        
        # Client info
        story.append(Paragraph(f"<b>Client:</b> {str(proposal_data.get('client', 'N/A'))}", styles['Normal']))
        story.append(Paragraph(f"<b>Date:</b> {datetime.now().strftime('%B %d, %Y')}", styles['Normal']))
        story.append(Spacer(1, 30))
        
        # Executive Summary
        if proposal_data.get('executive_summary'):
            story.append(Paragraph("Executive Summary", heading_style))
            story.append(Paragraph(str(proposal_data['executive_summary']), styles['Normal']))
            story.append(Spacer(1, 20))
        
        # Scope & Deliverables
        if proposal_data.get('scope'):
            story.append(Paragraph("Scope & Deliverables", heading_style))
            story.append(Paragraph(str(proposal_data['scope']), styles['Normal']))
            story.append(Spacer(1, 20))
        
        # Timeline
        if proposal_data.get('timeline'):
            story.append(Paragraph("Project Timeline", heading_style))
            story.append(Paragraph(str(proposal_data['timeline']), styles['Normal']))
            story.append(Spacer(1, 20))
        
        # Investment
        if proposal_data.get('investment'):
            story.append(Paragraph("Investment", heading_style))
            story.append(Paragraph(str(proposal_data['investment']), styles['Normal']))
            story.append(Spacer(1, 20))
        
        # Terms & Conditions
        if proposal_data.get('terms'):
            story.append(Paragraph("Terms & Conditions", heading_style))
            story.append(Paragraph(str(proposal_data['terms']), styles['Normal']))
            story.append(Spacer(1, 20))
        
        # Next Steps
        story.append(Paragraph("Next Steps", heading_style))
        story.append(Paragraph(
            "We look forward to discussing this proposal with you and answering any questions you may have. "
            "Please feel free to contact us to schedule a follow-up meeting.",
            styles['Normal']
        ))
        
        # Build PDF
        doc.build(story)
        print(f"PDF generated successfully: {filename}")
        
    except Exception as e:
        print(f"Error generating PDF: {e}")
        import traceback
        traceback.print_exc()
        raise e

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
    # Ensure SBG ESG sample modules exist (idempotent)
    extras = [
        ("cover_letter_sbg_esg", "Proposal Cover Letter", "To: Sibusiso Ngubeni\n10 April 2025\nKhonology Proposal – SBG ESG Impact Reporting\n\nThank you for the opportunity to collaborate on the SBG. Our aim is to assist SBG with streamlining its ability to submit sustainability metrics in its annual financial statements. The proof of concept we are proposing will look to leverage technologies that will enable a solution that can effectively create easier reporting by mainly automating the process and reduce human or manual touch when creating reports.\n\nYours sincerely,\nName: Africa Nkosi\nPosition: Director\nCompany: Khonology (Pty) Ltd (the RESPONDENT)"),
        ("company_background_purpose", "Company background – Our Purpose", "Khonology is a B-BBEE Level 2 South African digital services company... Our vision is to become Africa's leading digital enabler. Recent clients include InfoCare, Standard Bank, RMB, Auditor General of South Africa, SA Taxi Finance Company, NatWest Bank, ADB Safegate.\n\nRecent Awards:\n• 2023 TopCo Award for Best Fintech Company\n• 2023 Top Empowerment Digital Transformation Award of the Year\n• 2022 DataMagazine.Uk Top 44 Most Innovative Cloud Data Services Start-ups & Companies in South Africa\n• 2022 DataMagazine.Uk Top 14 Most Innovative Cloud Data Services Start-ups & Companies in Johannesburg\n• 2022/23 Prestige Awards Digital Services Company of the Year"),
        ("organizational_structure", "Organizational Structure", "Dapo Adeyemo – CEO – Co-founder\nMosa Nyamande – Head of Delivery - Co-founder\nAfrica Nkosi – Sales & Marketing – Co- founder\nMichael Roberts – Chairman - Co-founder\nLezanne Kruger – Finance Manager\nLerato Thekiso – Legal Partner"),
        ("background_sbg", "Background", "SBG needs to submit sustainability metrics in its annual financial statements... Retrieve deal information at inception and throughout the deal lifecycle, giving a comprehensive picture of planned vs actual impact & sustainability."),
        ("proposed_solution", "Proposed Solution", "Manual effort is required to locate key information in lengthy legal documents. The proposed solution automates extraction, standardisation, and structuring of contract data using document processing, AI-powered language models, and Microsoft SharePoint."),
        ("poc_objectives", "Objective of the PoC", "Validate feasibility and business value of automated data extraction and structuring for legal contracts, including: extracting key information; mapping terminology; storing structured data; UI for validation and monitoring; defining human validation; target OCR accuracy of 85%+."),
        ("approach_proposed_solution", "Approach to the proposed solution", "Two streams: Concept validation (extract key contract data from varied documents; classification and validation layer for auditability; store standardised data; SharePoint UI with natural language search) and Technical validation (assess org-approved technologies, integration points, platform and hosting)."),
        ("team_composition", "Team Composition", "Developer – builds platform and OCR integration.\nData Analyst/Tester – clarifies requirements and validates delivery.\nDelivery Manager – manages delivery and planning.\nAI Lead – guides technology stack and solution direction."),
        ("contact_us", "Contact Us", "Africa Nkosi – africa@khonology.com – +27 81 487 2317\nDapo Adeyemo – dapo@khonology.com – +27 81 379 0109\nMosa Nyamande – mosa@khonology.com – +27 81 487 7001\nKhonology Website / LinkedIn / Facebook / Twitter / Instagram"),
        ("case_studies", "Case Studies", "PowerPulse – connects accredited energy solution providers; CreditConnect – digital bond market platform; Automated Term Sheet – automated loan term sheet generation for RMB; include links and summaries as needed."),
        # Legal & Compliance
        ("legal_confidentiality", "Confidentiality Statement", "This document contains confidential information intended solely for the recipient named. Do not copy, distribute, or disclose without prior written consent from Khonology (Pty) Ltd."),
        ("legal_terms", "Standard Terms", "Engagement subject to mutually agreed Scope of Work, change control, payment terms, and IP ownership terms. ESG commitments adhered to per client policy."),
        # Proposal Modules (templates)
        ("proposal_exec_summary_tpl", "Executive Summary (Template)", "Use this section to succinctly state the client problem, proposed solution, expected outcomes, and next steps."),
        ("proposal_scope_tpl", "Scope & Deliverables (Template)", "Outline in-scope items, deliverables, and assumptions; explicitly note exclusions."),
        ("proposal_risks_tpl", "Risks (Template)", "Identify key delivery risks and mitigations. Include owner and likelihood/impact."),
        ("proposal_approach_tpl", "Delivery Approach (Template)", "Phased, agile delivery with discovery, design, implementation, testing, and handover. Include governance and cadence."),
        # Media Assets (URLs)
        ("media_powerpulse_video", "Media: PowerPulse Demo", "https://youtu.be/placeholder-powerpulse-demo"),
        ("media_company_logo", "Media: Company Logo", "https://khonology.com/assets/logo.png"),
    ]
    for k, label, content in extras:
        cur.execute("SELECT 1 FROM content_blocks WHERE key=? LIMIT 1", (k,))
        if not cur.fetchone():
            cur.execute("INSERT INTO content_blocks (key,label,content,created_at,updated_at) VALUES (?,?,?,?,?)",
                        (k, label, content, now_iso(), now_iso()))
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

class SendProposalEmailRequest(BaseModel):
    to: List[EmailStr]
    cc: List[EmailStr] = []
    subject: str
    body: str
    from_name: str
    from_email: str
    proposal_data: Optional[Dict[str, Any]] = None
    include_pdf: bool = True
    include_dashboard_link: bool = True

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
# ---- AI Routes (appended by automation) ----
# Minimal Ollama/Gemini chat endpoints to support frontend /ai/chat calls
try:
    import google.generativeai as _genai
except Exception:
    _genai = None
import httpx as _httpx
from typing import Literal as _Literal
from pydantic import BaseModel as _BaseModel

_AI_PROVIDER_DEFAULT = os.getenv("AI_PROVIDER", "ollama").lower()
_OLLAMA_MODEL_DEFAULT = os.getenv("OLLAMA_MODEL", "gemma3:4b")
_GEMINI_MODEL_DEFAULT = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
_GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")

class _AIMessage(_BaseModel):
    role: _Literal["system","user","assistant"]
    content: str

class _AIChatRequest(_BaseModel):
    provider: _Literal["ollama","gemini"] | None = None
    model: str | None = None
    messages: list[_AIMessage]

class _AIGenerateSOWRequest(_BaseModel):
    provider: _Literal["ollama","gemini"] | None = None
    model: str | None = None
    title: str
    client: str
    scope_points: list[str] = []
    constraints: list[str] = []
    assumptions: list[str] = []
    risks: list[str] = []

def _ensure_gemini_ready():
    if _genai is None:
        raise HTTPException(status_code=500, detail="google-generativeai not installed")
    if not _GOOGLE_API_KEY:
        raise HTTPException(status_code=400, detail="GOOGLE_API_KEY not set")
    _genai.configure(api_key=_GOOGLE_API_KEY)

async def _ollama_chat(model: str, messages: list[dict[str,str]]) -> str:
    url = "http://localhost:11434/api/chat"
    payload = {"model": model, "messages": messages, "stream": False}
    async with _httpx.AsyncClient(timeout=60) as client:
        r = await client.post(url, json=payload)
        if r.status_code != 200:
            raise HTTPException(status_code=502, detail=f"Ollama error: {r.text}")
        data = r.json()
        msg = data.get("message") or {}
        return msg.get("content", "")

def _gemini_chat(model: str, messages: list[dict[str,str]]) -> str:
    _ensure_gemini_ready()
    contents = []
    for m in messages:
        contents.append({
            "role": "user" if m["role"] in ("user","system") else "model",
            "parts": [{"text": m["content"]}],
        })
    gmodel = _genai.GenerativeModel(model)
    resp = gmodel.generate_content(contents)
    return getattr(resp, "text", None) or (resp.candidates[0].content.parts[0].text if getattr(resp, "candidates", None) else "")

@app.post("/ai/chat")
async def ai_chat(req: _AIChatRequest):
    provider = (req.provider or _AI_PROVIDER_DEFAULT).lower()
    model = req.model or (_OLLAMA_MODEL_DEFAULT if provider == "ollama" else _GEMINI_MODEL_DEFAULT)
    msgs = [{"role": m.role, "content": m.content} for m in req.messages]
    if provider == "ollama":
        reply = await _ollama_chat(model, msgs)
    elif provider == "gemini":
        reply = _gemini_chat(model, msgs)
    else:
        raise HTTPException(status_code=400, detail="Unknown provider")
    return {"provider": provider, "model": model, "reply": reply}

@app.post("/ai/generate-sow")
async def ai_generate_sow(req: _AIGenerateSOWRequest):
    provider = (req.provider or _AI_PROVIDER_DEFAULT).lower()
    model = req.model or (_OLLAMA_MODEL_DEFAULT if provider == "ollama" else _GEMINI_MODEL_DEFAULT)
    prompt = (
        f"You are an expert consulting proposal writer. Draft a professional Statement of Work for the project titled '{req.title}' for client '{req.client}'.\n"
        "Include these sections: Executive Summary, Objectives, Scope & Deliverables, Approach & Methodology, Assumptions, Constraints, Roles & Responsibilities, Timeline, Acceptance Criteria, Risks & Mitigations, Pricing (placeholder), and Terms (placeholder).\n"
        f"Scope points: {req.scope_points}\nConstraints: {req.constraints}\nAssumptions: {req.assumptions}\nRisks: {req.risks}\n"
        "Write concise, business-friendly text with bullet points where helpful."
    )
    system = {"role": "system", "content": "You are a consulting proposal assistant that outputs clear, structured business documents."}
    user = {"role": "user", "content": prompt}
    msgs = [system, user]
    if provider == "ollama":
        reply = await _ollama_chat(model, msgs)
    elif provider == "gemini":
        reply = _gemini_chat(model, msgs)
    else:
        raise HTTPException(status_code=400, detail="Unknown provider")
    return {"provider": provider, "model": model, "title": req.title, "content": reply}
# ---- end AI Routes ----
