import os
import time
import uuid
import hashlib
import base64
from contextlib import contextmanager

import pytest
import requests
import psycopg2
import psycopg2.extras
from urllib.parse import urlparse, parse_qs


def _build_db_config_from_env():
    database_url = os.getenv("DATABASE_URL")
    if database_url:
        parsed = urlparse(database_url)
        scheme = (parsed.scheme or "").lower()
        if scheme.startswith("postgresql+"):
            scheme = "postgresql"
        if scheme not in ("postgres", "postgresql"):
            raise ValueError("DATABASE_URL must be a Postgres URL")

        db_config = {
            "host": parsed.hostname,
            "database": (parsed.path or "").lstrip("/"),
            "user": parsed.username,
            "password": parsed.password,
            "port": parsed.port or 5432,
        }

        query = parse_qs(parsed.query or "")
        sslmode_from_url = (query.get("sslmode") or [None])[0]
        ssl_mode = sslmode_from_url or os.getenv("DB_SSLMODE")
        if ssl_mode:
            db_config["sslmode"] = ssl_mode
        return db_config

    cfg = {
        "host": os.getenv("DB_HOST", "localhost"),
        "database": os.getenv("DB_NAME", "proposal_db"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", ""),
        "port": int(os.getenv("DB_PORT", "5432")),
    }

    ssl_mode = os.getenv("DB_SSLMODE")
    if ssl_mode:
        cfg["sslmode"] = ssl_mode

    return cfg


@contextmanager
def _db_conn():
    cfg = _build_db_config_from_env()
    conn = psycopg2.connect(**cfg)
    try:
        yield conn
    finally:
        conn.close()


@pytest.fixture()
def db_conn():
    return _db_conn


def _table_columns(cur, table_name: str):
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (table_name,),
    )
    return {r[0] for r in cur.fetchall()}


def _pbkdf2_hash(value: str, salt: bytes, iterations: int = 200_000) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", value.encode("utf-8"), salt, iterations)


def encode_identity_last4(last4: str) -> str:
    salt = (
        os.getenv("IDENTITY_SALT")
        or os.getenv("JWT_SECRET")
        or os.getenv("SECRET_KEY")
        or "dev-identity-salt"
    )
    salt_bytes = salt.encode("utf-8")
    digest = _pbkdf2_hash(last4, salt_bytes)
    return (
        "pbkdf2$"
        + base64.urlsafe_b64encode(salt_bytes).decode("utf-8")
        + "$"
        + base64.urlsafe_b64encode(digest).decode("utf-8")
    )


def pytest_addoption(parser):
    parser.addoption(
        "--api-base-url",
        action="store",
        default=os.getenv("TEST_API_BASE_URL", "http://127.0.0.1:8000"),
        help="Base URL for the running backend server",
    )


@pytest.fixture(scope="session")
def api_base_url(pytestconfig):
    return pytestconfig.getoption("--api-base-url").rstrip("/")


@pytest.fixture(scope="session")
def api_is_up(api_base_url):
    try:
        # cheap health check: preflight to an endpoint that exists
        r = requests.options(f"{api_base_url}/api/client/proposals")
        return r.status_code in (200, 204)
    except Exception:
        return False


@pytest.fixture()
def seeded_client_invitation(api_is_up):
    if not api_is_up:
        pytest.skip("Backend server is not reachable on TEST_API_BASE_URL")

    token = "test_tok_" + uuid.uuid4().hex
    invited_email = f"test_client_{uuid.uuid4().hex[:8]}@example.com"
    last4 = "1234"

    with _db_conn() as conn:
        conn.autocommit = True
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        # Ensure identity column exists if needed
        cols = _table_columns(cur, "proposals")
        if "identity_last4_hash" not in cols:
            cur.execute("ALTER TABLE proposals ADD COLUMN identity_last4_hash TEXT")
            cols.add("identity_last4_hash")

        proposal_id_col_type = None
        cur.execute(
            """
            SELECT data_type
            FROM information_schema.columns
            WHERE table_schema='public' AND table_name='proposals' AND column_name='id'
            """
        )
        row = cur.fetchone()
        if row:
            proposal_id_col_type = (row.get("data_type") if isinstance(row, dict) else row[0])

        # Insert proposal
        proposal_title = "pytest client portal"
        identity_hash = encode_identity_last4(last4)

        insert_cols = []
        insert_vals = []
        if "title" in cols:
            insert_cols.append("title")
            insert_vals.append(proposal_title)
        if "content" in cols:
            insert_cols.append("content")
            insert_vals.append("test")
        if "status" in cols:
            insert_cols.append("status")
            insert_vals.append("Released")
        if "client_email" in cols:
            insert_cols.append("client_email")
            insert_vals.append(invited_email)
        if "client" in cols:
            insert_cols.append("client")
            insert_vals.append("pytest")
        if "identity_last4_hash" in cols:
            insert_cols.append("identity_last4_hash")
            insert_vals.append(identity_hash)

        if not insert_cols:
            raise RuntimeError("Unable to seed proposals table: no known columns")

        placeholders = ", ".join(["%s"] * len(insert_cols))
        col_sql = ", ".join(insert_cols)
        cur.execute(
            f"INSERT INTO proposals ({col_sql}) VALUES ({placeholders}) RETURNING id",
            insert_vals,
        )
        proposal_id = cur.fetchone()["id"]

        # Insert collaboration invitation
        inv_cols = _table_columns(cur, "collaboration_invitations")
        token_col = "access_token" if "access_token" in inv_cols else ("token" if "token" in inv_cols else None)
        email_col = (
            "invited_email"
            if "invited_email" in inv_cols
            else ("invitee_email" if "invitee_email" in inv_cols else ("email" if "email" in inv_cols else None))
        )
        expires_col = "expires_at" if "expires_at" in inv_cols else None

        if not token_col or not email_col or "proposal_id" not in inv_cols:
            raise RuntimeError("collaboration_invitations table missing required columns")

        inv_insert_cols = ["proposal_id", token_col, email_col]
        inv_insert_vals = [proposal_id, token, invited_email]
        if expires_col:
            inv_insert_cols.append(expires_col)
            inv_insert_vals.append("2099-01-01")

        inv_placeholders = ", ".join(["%s"] * len(inv_insert_cols))
        inv_col_sql = ", ".join(inv_insert_cols)
        cur.execute(
            f"INSERT INTO collaboration_invitations ({inv_col_sql}) VALUES ({inv_placeholders})",
            inv_insert_vals,
        )

        yield {
            "proposal_id": proposal_id,
            "access_token": token,
            "invited_email": invited_email,
            "last4": last4,
        }

        # Cleanup (best-effort)
        cur.execute(f"DELETE FROM collaboration_invitations WHERE {token_col} = %s", (token,))
        # dependent tables created by endpoint
        try:
            cur.execute("DELETE FROM client_device_sessions WHERE invitation_token = %s", (token,))
        except Exception:
            pass
        try:
            cur.execute("DELETE FROM client_trusted_devices WHERE invitation_token = %s", (token,))
        except Exception:
            pass
        try:
            cur.execute("DELETE FROM client_identity_access WHERE invitation_token = %s", (token,))
        except Exception:
            pass
        try:
            cur.execute("DELETE FROM proposals WHERE id = %s", (proposal_id,))
        except Exception:
            pass
