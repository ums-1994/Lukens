"""
Client role routes - Viewing proposals, commenting, approving/rejecting, signing
"""
from flask import Blueprint, request, jsonify
import os
import json
import traceback
import secrets
import hashlib
import hmac
import base64
from urllib.parse import unquote
from psycopg2 import sql
import psycopg2.extras
from datetime import datetime, timedelta

from api.utils.database import get_db_connection
from api.utils.decorators import token_required
from api.utils.jwt_validator import validate_jwt_token, JWTValidationError
from api.utils.helpers import log_status_change
from api.utils.email import send_email

bp = Blueprint('client', __name__)


def _now_utc():
    return datetime.utcnow()


def _client_session_pepper() -> bytes:
    return (
        os.getenv('CLIENT_SESSION_TOKEN_PEPPER')
        or os.getenv('SESSION_TOKEN_PEPPER')
        or os.getenv('JWT_SECRET')
        or os.getenv('SECRET_KEY')
        or 'dev-client-session-pepper'
    ).encode('utf-8')


def _hash_client_session_token(token: str) -> str:
    digest = hmac.new(_client_session_pepper(), token.encode('utf-8'), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode('utf-8')


def _hash_client_otp(code: str, challenge_salt: str) -> str:
    msg = f"{challenge_salt}:{code}".encode('utf-8')
    digest = hmac.new(_client_session_pepper(), msg, hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode('utf-8')


def _ensure_client_device_session_schema(cursor):
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS client_trusted_devices (
            invitation_token TEXT NOT NULL,
            device_id TEXT NOT NULL,
            first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            PRIMARY KEY (invitation_token, device_id)
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS client_device_otp_challenges (
            id TEXT PRIMARY KEY,
            invitation_token TEXT NOT NULL,
            device_id TEXT NOT NULL,
            challenge_salt TEXT NOT NULL,
            otp_hash TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            expires_at TIMESTAMPTZ NOT NULL,
            verified_at TIMESTAMPTZ NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS client_device_sessions (
            id TEXT PRIMARY KEY,
            invitation_token TEXT NOT NULL,
            device_id TEXT NOT NULL,
            session_token_hash TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            expires_at TIMESTAMPTZ NOT NULL,
            revoked_at TIMESTAMPTZ NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE INDEX IF NOT EXISTS client_device_sessions_invitation_device_idx
        ON client_device_sessions(invitation_token, device_id)
        """
    )


def _extract_client_device_session():
    device_id = (request.headers.get('X-Client-Device-Id') or request.args.get('device_id') or '').strip()
    session_token = (request.headers.get('X-Client-Session-Token') or request.args.get('session_token') or '').strip()
    if not device_id:
        device_id = (request.headers.get('X-Device-Id') or request.args.get('deviceId') or '').strip()
    return device_id or None, session_token or None


def _create_client_session(cursor, invitation_token: str, device_id: str):
    session_token = secrets.token_urlsafe(32)
    token_hash = _hash_client_session_token(session_token)
    session_id = secrets.token_urlsafe(24)
    now = _now_utc()
    expires_at = now + timedelta(hours=1)
    cursor.execute(
        """
        INSERT INTO client_device_sessions (id, invitation_token, device_id, session_token_hash, created_at, last_seen_at, expires_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (session_id, invitation_token, device_id, token_hash, now, now, expires_at),
    )
    return {
        'session_token': session_token,
        'session_id': session_id,
        'expires_at': expires_at,
    }


def _require_client_device_session(cursor, invitation_token: str, device_id: str | None, session_token: str | None):
    if not device_id or not session_token:
        return False, {
            'detail': 'Device verification required',
            'requires_device_session': True,
            'otp_required': False,
            'identity_required': True,
            'requires_identity_verification': True,
        }, 428
    token_hash = _hash_client_session_token(session_token)
    now = _now_utc()
    cursor.execute(
        """
        SELECT id, expires_at, revoked_at
        FROM client_device_sessions
        WHERE invitation_token = %s AND device_id = %s AND session_token_hash = %s
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (invitation_token, device_id, token_hash),
    )
    row = cursor.fetchone()
    if not row:
        return False, {
            'detail': 'Device verification required',
            'requires_device_session': True,
            'otp_required': False,
            'identity_required': True,
            'requires_identity_verification': True,
        }, 428
    expires_at = row.get('expires_at') if isinstance(row, dict) else None
    revoked_at = row.get('revoked_at') if isinstance(row, dict) else None
    if revoked_at is not None:
        return False, {
            'detail': 'Session revoked',
            'requires_device_session': True,
            'otp_required': False,
            'identity_required': True,
            'requires_identity_verification': True,
        }, 428
    if expires_at is not None and now > expires_at:
        return False, {
            'detail': 'Session expired',
            'requires_device_session': True,
            'otp_required': False,
            'identity_required': True,
            'requires_identity_verification': True,
        }, 428
    cursor.execute(
        """
        UPDATE client_device_sessions
        SET last_seen_at = NOW()
        WHERE id = %s
        """,
        (row.get('id') if isinstance(row, dict) else row[0],),
    )
    return True, None, 200


def _pbkdf2_hash(value: str, salt: bytes, iterations: int = 200_000) -> bytes:
    return hashlib.pbkdf2_hmac('sha256', value.encode('utf-8'), salt, iterations)


def _encode_identity_hash(last4: str) -> str:
    salt = os.getenv('IDENTITY_SALT') or os.getenv('JWT_SECRET') or os.getenv('SECRET_KEY') or 'dev-identity-salt'
    salt_bytes = salt.encode('utf-8')
    digest = _pbkdf2_hash(last4, salt_bytes)
    return "pbkdf2$" + base64.urlsafe_b64encode(salt_bytes).decode('utf-8') + "$" + base64.urlsafe_b64encode(digest).decode('utf-8')


def _verify_identity_hash(last4: str, encoded: str) -> bool:
    if not encoded or not isinstance(encoded, str):
        return False
    parts = encoded.split('$')
    if len(parts) != 3 or parts[0] != 'pbkdf2':
        return False
    try:
        salt = base64.urlsafe_b64decode(parts[1].encode('utf-8'))
        expected = base64.urlsafe_b64decode(parts[2].encode('utf-8'))
    except Exception:
        return False
    actual = _pbkdf2_hash(last4, salt)
    return hmac.compare_digest(actual, expected)


def _ensure_identity_schema(cursor):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'proposals'
        """
    )
    cols = {r['column_name'] if isinstance(r, dict) else r[0] for r in cursor.fetchall() or []}
    if 'identity_last4_hash' not in cols:
        cursor.execute("ALTER TABLE proposals ADD COLUMN identity_last4_hash TEXT")

    cursor.execute("SELECT to_regclass(%s)", ("public.client_identity_access",))
    table_row = cursor.fetchone()
    if isinstance(table_row, dict):
        table_val = next(iter(table_row.values()), None)
    else:
        table_val = table_row[0] if table_row else None
    has_table = table_val is not None
    if not has_table:
        cursor.execute(
            """
            CREATE TABLE client_identity_access (
                invitation_token TEXT PRIMARY KEY,
                proposal_id INTEGER,
                attempts INTEGER DEFAULT 0,
                locked_at TIMESTAMP NULL,
                verified_at TIMESTAMP NULL,
                last_attempt_at TIMESTAMP NULL,
                unlocked_token TEXT NULL,
                unlocked_expires_at TIMESTAMP NULL
            )
            """
        )


def _lookup_invitation_by_token(cursor, token: str):
    inv_info = _get_invitation_column_info(cursor)
    token_col = inv_info['token_col']
    email_col = inv_info['email_col']
    expires_col = inv_info['expires_col']
    if not token_col:
        return None, {'detail': 'Client invitations not configured (missing token column)'}, 500
    if not email_col:
        return None, {'detail': 'Client invitations not configured (missing invited email column)'}, 500

    expires_select = (
        sql.Identifier(expires_col)
        if expires_col
        else sql.SQL('NULL::timestamp')
    )
    cursor.execute(
        sql.SQL(
            """
            SELECT proposal_id, {email_col} as invited_email, {expires_col} as expires_at
            FROM collaboration_invitations
            WHERE {token_col} = %s
            """
        ).format(
            email_col=sql.Identifier(email_col),
            expires_col=expires_select,
            token_col=sql.Identifier(token_col),
        ),
        (token,),
    )
    invitation = cursor.fetchone()
    if not invitation:
        return None, {'detail': 'Invalid access token'}, 404
    if invitation.get('expires_at') and datetime.now() > invitation['expires_at']:
        return None, {'detail': 'Access token has expired'}, 403
    return invitation, None, None


def _proposal_identity_hash(cursor, proposal_id: int):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'proposals'
        """
    )
    cols = {r['column_name'] if isinstance(r, dict) else r[0] for r in cursor.fetchall() or []}
    if 'identity_last4_hash' not in cols:
        return None
    cursor.execute("SELECT identity_last4_hash FROM proposals WHERE id = %s", (proposal_id,))
    row = cursor.fetchone()
    if not row:
        return None
    if isinstance(row, dict):
        return row.get('identity_last4_hash')
    return row[0]


def _require_identity_configured(cursor, proposal_id: int):
    expected_hash = _proposal_identity_hash(cursor, proposal_id)
    if expected_hash:
        return True, expected_hash, 200
    return False, {
        'detail': 'Identity verification is required but not configured for this proposal',
        'identity_required': True,
        'requires_identity_verification': True,
        'configured': False,
    }, 403


def _identity_access_row(cursor, invitation_token: str, proposal_id: int):
    cursor.execute(
        """
        SELECT invitation_token, proposal_id, attempts, locked_at, verified_at, unlocked_token, unlocked_expires_at
        FROM client_identity_access
        WHERE invitation_token = %s
        """,
        (invitation_token,),
    )
    row = cursor.fetchone()
    if not row:
        cursor.execute(
            """
            INSERT INTO client_identity_access (invitation_token, proposal_id, attempts, locked_at, verified_at, last_attempt_at)
            VALUES (%s, %s, 0, NULL, NULL, NULL)
            RETURNING invitation_token, proposal_id, attempts, locked_at, verified_at, unlocked_token, unlocked_expires_at
            """,
            (invitation_token, proposal_id),
        )
        row = cursor.fetchone()
    return dict(row) if isinstance(row, dict) else {
        'invitation_token': row[0],
        'proposal_id': row[1],
        'attempts': row[2],
        'locked_at': row[3],
        'verified_at': row[4],
        'unlocked_token': row[5],
        'unlocked_expires_at': row[6],
    }


def _is_unlocked(access_row: dict) -> bool:
    if not access_row:
        return False
    if access_row.get('locked_at') is not None:
        return False
    if not access_row.get('verified_at'):
        return False
    token = (access_row.get('unlocked_token') or '').strip()
    if not token:
        return False
    exp = access_row.get('unlocked_expires_at')
    if exp and isinstance(exp, datetime) and _now_utc() > exp:
        return False
    return True


def _require_unlocked_for_invitation(cursor, invitation_token: str, proposal_id: int):
    access_row = _identity_access_row(cursor, invitation_token, proposal_id)
    if access_row.get('locked_at') is not None:
        return False, {
            'detail': 'Access locked due to too many failed identity attempts',
            'locked': True,
            'identity_required': True,
            'requires_identity_verification': True,
        }, 423
    if not _is_unlocked(access_row):
        remaining = max(0, 3 - int(access_row.get('attempts') or 0))
        return False, {
            'detail': 'Identity verification required',
            'identity_required': True,
            'requires_identity_verification': True,
            'attempts_remaining': remaining,
        }, 428
    return True, access_row, 200


def _validate_unlocked_token(cursor, unlocked_token: str):
    cursor.execute(
        """
        SELECT invitation_token, proposal_id, attempts, locked_at, verified_at, unlocked_token, unlocked_expires_at
        FROM client_identity_access
        WHERE unlocked_token = %s
        """,
        (unlocked_token,),
    )
    row = cursor.fetchone()
    if not row:
        return None
    access_row = dict(row) if isinstance(row, dict) else {
        'invitation_token': row[0],
        'proposal_id': row[1],
        'attempts': row[2],
        'locked_at': row[3],
        'verified_at': row[4],
        'unlocked_token': row[5],
        'unlocked_expires_at': row[6],
    }
    if not _is_unlocked(access_row):
        return None
    return access_row


def _normalize_access_token(raw_token: str | None) -> str | None:
    if raw_token is None:
        return None
    token = unquote(str(raw_token)).strip().strip('"').strip("'")
    return token.strip() or None


def _resolve_invitation_token(cursor, token: str):
    access_row = _validate_unlocked_token(cursor, token)
    if access_row:
        return access_row.get('invitation_token') or token
    return token


def _notify_hard_lock(cursor, proposal_id: int, invited_email: str | None, invitation_token: str | None = None):
    try:
        from api.utils.helpers import create_notification
    except Exception:
        create_notification = None
    if create_notification is None:
        return

    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'proposals'
        """
    )
    cols = {r['column_name'] if isinstance(r, dict) else r[0] for r in cursor.fetchall() or []}
    owner_col = 'owner_id' if 'owner_id' in cols else ('user_id' if 'user_id' in cols else None)
    if not owner_col:
        return

    cursor.execute(f"SELECT {owner_col} FROM proposals WHERE id = %s", (proposal_id,))
    prow = cursor.fetchone()
    if not prow:
        return
    owner_identifier = prow.get(owner_col) if isinstance(prow, dict) else prow[0]

    msg = "A client has been locked out after 3 failed identity verification attempts."
    if invited_email:
        msg += f" Client email: {invited_email}."
    if invitation_token:
        msg += ""

    create_notification(
        user_id=owner_identifier,
        notification_type='client_identity_hard_lock',
        title='Client Portal Locked',
        message=msg,
        proposal_id=proposal_id,
        metadata={
            'proposal_id': proposal_id,
            'client_email': invited_email,
        },
    )


@bp.post('/client/device-session/start')
def start_client_device_session():
    try:
        payload = request.get_json(silent=True) or {}
        token = payload.get('token') or request.args.get('token')
        device_id = (payload.get('device_id') or payload.get('deviceId') or '').strip()
        if not token:
            return {'detail': 'Access token required'}, 400
        if not device_id:
            return {'detail': 'device_id is required'}, 400

        token = _normalize_access_token(token)
        if not token:
            return {'detail': 'Access token required'}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)
            invitation, err, code = _lookup_invitation_by_token(cursor, invitation_token)
            if err:
                return err, code

            proposal_id = int(invitation.get('proposal_id'))
            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
            if not allowed:
                return err_payload, status

            cursor.execute(
                """
                SELECT 1
                FROM client_trusted_devices
                WHERE invitation_token = %s AND device_id = %s
                """,
                (invitation_token, device_id),
            )
            trusted = cursor.fetchone() is not None
            if trusted:
                cursor.execute(
                    """
                    UPDATE client_trusted_devices
                    SET last_seen_at = NOW()
                    WHERE invitation_token = %s AND device_id = %s
                    """,
                    (invitation_token, device_id),
                )
                session = _create_client_session(cursor, invitation_token, device_id)
                conn.commit()
                return {
                    'otp_required': False,
                    'session_token': session['session_token'],
                    'session_id': session['session_id'],
                    'expires_at': session['expires_at'].isoformat(),
                }, 200

            otp_code = f"{secrets.randbelow(1_000_000):06d}"
            challenge_id = secrets.token_urlsafe(24)
            challenge_salt = secrets.token_urlsafe(16)
            otp_hash = _hash_client_otp(otp_code, challenge_salt)
            now = _now_utc()
            expires_at = now + timedelta(minutes=10)
            cursor.execute(
                """
                INSERT INTO client_device_otp_challenges (id, invitation_token, device_id, challenge_salt, otp_hash, attempts, created_at, expires_at)
                VALUES (%s, %s, %s, %s, %s, 0, %s, %s)
                """,
                (challenge_id, invitation_token, device_id, challenge_salt, otp_hash, now, expires_at),
            )
            conn.commit()

        invited_email = invitation.get('invited_email')
        subject = 'Your client portal verification code'
        html_content = f"""
        <h2>Verification Code</h2>
        <p>Use the code below to verify this new device for your client portal:</p>
        <div style=\"text-align:center;margin:20px 0;\">
          <div style=\"display:inline-block;background:#111;border:1px solid #333;border-radius:12px;padding:16px 24px;font-size:28px;letter-spacing:6px;color:#fff;font-weight:700;\">
            {otp_code}
          </div>
        </div>
        <p>This code expires in 10 minutes.</p>
        """
        try:
            if invited_email:
                send_email(invited_email, subject, html_content)
        except Exception:
            pass

        return {
            'otp_required': True,
            'challenge_id': challenge_id,
            'expires_at': expires_at.isoformat(),
        }, 200
    except Exception as e:
        print(f"[ERROR] start_client_device_session error: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post('/api/client/device-session/start')
def start_client_device_session_api():
    return start_client_device_session()


@bp.post('/api/client/device-session/verify-otp')
def verify_client_device_otp_api():
    return verify_client_device_otp()


@bp.post('/client/device-session/verify-otp')
def verify_client_device_otp():
    try:
        data = request.get_json(silent=True) or {}
        challenge_id = (data.get('challenge_id') or data.get('challengeId') or '').strip()
        otp = (data.get('otp') or data.get('code') or '').strip()
        if not challenge_id:
            return {'detail': 'challenge_id is required'}, 400
        if not otp:
            return {'detail': 'otp is required'}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            _ensure_client_device_session_schema(cursor)
            cursor.execute(
                """
                SELECT id, invitation_token, device_id, challenge_salt, otp_hash, attempts, expires_at, verified_at
                FROM client_device_otp_challenges
                WHERE id = %s
                """,
                (challenge_id,),
            )
            row = cursor.fetchone()
            if not row:
                return {'detail': 'Invalid challenge_id'}, 404
            if row.get('verified_at') is not None:
                return {'detail': 'Challenge already used'}, 400
            expires_at = row.get('expires_at')
            if expires_at is not None and _now_utc() > expires_at:
                return {'detail': 'OTP expired'}, 400
            attempts = int(row.get('attempts') or 0)
            if attempts >= 5:
                return {'detail': 'Too many attempts'}, 429
            expected = row.get('otp_hash')
            actual = _hash_client_otp(otp, row.get('challenge_salt'))
            if not hmac.compare_digest(str(expected or ''), str(actual or '')):
                cursor.execute(
                    """
                    UPDATE client_device_otp_challenges
                    SET attempts = attempts + 1
                    WHERE id = %s
                    """,
                    (challenge_id,),
                )
                conn.commit()
                return {
                    'detail': 'Invalid code',
                    'remaining_attempts': max(0, 5 - (attempts + 1)),
                }, 401

            invitation_token = row.get('invitation_token')
            device_id = row.get('device_id')
            cursor.execute(
                """
                UPDATE client_device_otp_challenges
                SET verified_at = NOW()
                WHERE id = %s
                """,
                (challenge_id,),
            )
            cursor.execute(
                """
                INSERT INTO client_trusted_devices (invitation_token, device_id, first_seen_at, last_seen_at)
                VALUES (%s, %s, NOW(), NOW())
                ON CONFLICT (invitation_token, device_id)
                DO UPDATE SET last_seen_at = NOW()
                """,
                (invitation_token, device_id),
            )
            session = _create_client_session(cursor, invitation_token, device_id)
            conn.commit()

            return {
                'session_token': session['session_token'],
                'session_id': session['session_id'],
                'expires_at': session['expires_at'].isoformat(),
            }, 200
    except Exception as e:
        print(f"[ERROR] verify_client_device_otp error: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post('/client/verify-identity')
def verify_client_identity():
    try:
        payload = request.get_json(silent=True) or {}
        token = payload.get('token') or request.args.get('token')
        last4 = payload.get('last4')

        if not token:
            return {'detail': 'Access token required'}, 400

        token = unquote(str(token)).strip().strip('"').strip("'")
        last4 = (str(last4) if last4 is not None else '').strip()
        if not last4 or len(last4) < 4:
            return {'detail': 'Last 4 digits required'}, 400
        last4 = last4[-4:]

        device_id, session_token = _extract_client_device_session()
        if not device_id:
            device_id = (payload.get('device_id') or payload.get('deviceId') or '').strip() or None
        if not device_id:
            return {'detail': 'device_id is required'}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)

            invitation, err, code = _lookup_invitation_by_token(cursor, invitation_token)
            if err:
                return err, code

            proposal_id = int(invitation.get('proposal_id'))
            invited_email = invitation.get('invited_email')

            expected_hash = _proposal_identity_hash(cursor, proposal_id)
            if not expected_hash:
                return {
                    'detail': 'Identity verification not configured for this proposal',
                    'identity_required': True,
                    'requires_identity_verification': True,
                }, 403

            access_row = _identity_access_row(cursor, invitation_token, proposal_id)
            if access_row.get('locked_at') is not None:
                return {
                    'detail': 'Access locked due to too many failed identity attempts',
                    'locked': True,
                    'identity_required': True,
                    'requires_identity_verification': True,
                }, 423

            ok = _verify_identity_hash(last4, expected_hash)
            if not ok:
                attempts = int(access_row.get('attempts') or 0) + 1
                locked_at = None
                if attempts >= 3:
                    locked_at = _now_utc()
                    cursor.execute(
                        """
                        UPDATE client_identity_access
                        SET attempts = %s, locked_at = %s, last_attempt_at = %s
                        WHERE invitation_token = %s
                        """,
                        (attempts, locked_at, _now_utc(), invitation_token),
                    )
                    conn.commit()
                    try:
                        _notify_hard_lock(cursor, proposal_id, invited_email, invitation_token=invitation_token)
                        conn.commit()
                    except Exception:
                        pass
                    return {
                        'detail': 'Access locked due to too many failed identity attempts',
                        'locked': True,
                        'identity_required': True,
                        'requires_identity_verification': True,
                    }, 423

                cursor.execute(
                    """
                    UPDATE client_identity_access
                    SET attempts = %s, last_attempt_at = %s
                    WHERE invitation_token = %s
                    """,
                    (attempts, _now_utc(), invitation_token),
                )
                conn.commit()
                return {
                    'detail': 'Invalid identity credential',
                    'identity_required': True,
                    'requires_identity_verification': True,
                    'attempts_remaining': max(0, 3 - attempts),
                }, 401

            cursor.execute(
                """
                INSERT INTO client_trusted_devices (invitation_token, device_id, first_seen_at, last_seen_at)
                VALUES (%s, %s, NOW(), NOW())
                ON CONFLICT (invitation_token, device_id)
                DO UPDATE SET last_seen_at = NOW()
                """,
                (invitation_token, device_id),
            )

            session = _create_client_session(cursor, invitation_token, device_id)

            unlocked_token = secrets.token_urlsafe(32)
            expires_at = _now_utc()  # now
            try:
                expires_at = _now_utc().replace(microsecond=0)
            except Exception:
                expires_at = _now_utc()
            try:
                from datetime import timedelta
                expires_at = _now_utc() + timedelta(days=7)
            except Exception:
                pass

            cursor.execute(
                """
                UPDATE client_identity_access
                SET verified_at = %s,
                    unlocked_token = %s,
                    unlocked_expires_at = %s,
                    last_attempt_at = %s
                WHERE invitation_token = %s
                """,
                (_now_utc(), unlocked_token, expires_at, _now_utc(), invitation_token),
            )
            conn.commit()

            return {
                'unlocked_token': unlocked_token,
                'unlocked_expires_at': expires_at.isoformat() if hasattr(expires_at, 'isoformat') else None,
                'session_token': session['session_token'],
                'session_expires_at': session['expires_at'].isoformat() if hasattr(session['expires_at'], 'isoformat') else None,
            }, 200

    except Exception as e:
        print(f"❌ Error verifying client identity: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


def _get_invitation_column_info(cursor):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'collaboration_invitations'
        """
    )
    cols = {r['column_name'] if isinstance(r, dict) else r[0] for r in cursor.fetchall()}

    token_col = 'access_token' if 'access_token' in cols else ('token' if 'token' in cols else None)
    email_col = (
        'invited_email'
        if 'invited_email' in cols
        else (
            'invitee_email'
            if 'invitee_email' in cols
            else ('email' if 'email' in cols else None)
        )
    )
    expires_col = 'expires_at' if 'expires_at' in cols else None
    return {
        'cols': cols,
        'token_col': token_col,
        'email_col': email_col,
        'expires_col': expires_col,
    }


def _get_proposal_column_info(cursor):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'proposals'
        """
    )
    rows = cursor.fetchall()
    column_names = set()
    for row in rows:
        if isinstance(row, dict):
            name = row.get('column_name')
        else:
            name = row[0] if row else None
        if name:
            column_names.add(name)
    if 'client_name' in column_names:
        client_name_expr = 'p.client_name'
    elif 'client' in column_names:
        client_name_expr = 'p.client'
    else:
        client_name_expr = "'Client'::text"
    if 'client_email' in column_names:
        client_email_expr = 'p.client_email'
    else:
        client_email_expr = 'ci.invited_email'
    return {
        'columns': column_names,
        'client_name_expr': client_name_expr,
        'client_email_expr': client_email_expr,
    }


# ============================================================================
# CLIENT DASHBOARD JWT TOKEN ROUTES
# ============================================================================


@bp.get("/client/validate-token")
def validate_client_dashboard_token():
    """
    Validate a JWT token for the client dashboard.
    """
    try:
        auth_header = request.headers.get('Authorization', '')
        token = None

        if auth_header.startswith('Bearer '):
            token = auth_header.split(' ', 1)[1].strip()
        else:
            token = request.args.get('token')

        if not token:
            return {'detail': 'Token is required'}, 400

        try:
            decoded = validate_jwt_token(token)
        except JWTValidationError as e:
            return {'detail': str(e)}, 401

        return decoded, 200
    except Exception as e:
        print(f"❌ Error validating client dashboard token: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/client-dashboard-mini/<token>")
def client_dashboard_mini(token):
    """
    Minimal HTML dashboard view for clients using a JWT token.
    """
    try:
        try:
            decoded = validate_jwt_token(token)
        except JWTValidationError as e:
            return f"<h1>Invalid or expired token</h1><p>{e}</p>", 401

        client_email = decoded.get('client_email', 'Client')
        proposal_data = decoded.get('proposal_data') or {}
        proposal_title = proposal_data.get('title', 'Business Proposal')
        proposal_status = proposal_data.get('status', 'For Review')

        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>Client Dashboard</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {{
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                    background: #0b1020;
                    color: #f9fafb;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                }}
                .card {{
                    background: radial-gradient(circle at top left, #111827, #020617);
                    border-radius: 16px;
                    border: 1px solid rgba(148, 163, 184, 0.3);
                    box-shadow: 0 24px 60px rgba(15, 23, 42, 0.6);
                    padding: 32px;
                    max-width: 640px;
                    width: 100%;
                }}
                h1 {{
                    margin: 0 0 4px;
                    font-size: 24px;
                }}
                h2 {{
                    margin: 24px 0 8px;
                    font-size: 18px;
                }}
                p {{
                    margin: 4px 0;
                    color: #cbd5f5;
                    font-size: 14px;
                }}
                .badge {{
                    display: inline-flex;
                    align-items: center;
                    padding: 4px 10px;
                    border-radius: 999px;
                    font-size: 11px;
                    text-transform: uppercase;
                    letter-spacing: 0.08em;
                    background: rgba(56, 189, 248, 0.1);
                    color: #38bdf8;
                    border: 1px solid rgba(56, 189, 248, 0.4);
                    margin-bottom: 16px;
                }}
                .section-title {{
                    font-weight: 600;
                    margin-top: 24px;
                    margin-bottom: 8px;
                    font-size: 13px;
                    text-transform: uppercase;
                    letter-spacing: 0.08em;
                    color: #9ca3af;
                }}
                .proposal-card {{
                    margin-top: 8px;
                    padding: 16px;
                    border-radius: 12px;
                    background: rgba(15, 23, 42, 0.8);
                    border: 1px solid rgba(148, 163, 184, 0.3);
                }}
                .status-pill {{
                    display: inline-flex;
                    align-items: center;
                    padding: 4px 12px;
                    border-radius: 999px;
                    font-size: 12px;
                    background: rgba(34, 197, 94, 0.12);
                    color: #4ade80;
                    border: 1px solid rgba(34, 197, 94, 0.5);
                }}
            </style>
        </head>
        <body>
            <div class="card">
                <div class="badge">Client Dashboard</div>
                <h1>Welcome to Your Client Portal</h1>
                <p>Hi {client_email}, here's a quick view of your proposal.</p>

                <div class="section-title">My Proposals</div>
                <div class="proposal-card">
                    <p style="font-weight: 600; font-size: 15px;">{proposal_title}</p>
                    <p style="margin-top: 8px;">
                        <span class="status-pill">{proposal_status}</span>
                    </p>
                </div>

                <div class="section-title">Sign Documents</div>
                <p>Open your full client portal to review, comment and sign.</p>

                <div class="section-title">Signed History</div>
                <p>Keep track of your completed agreements and engagements.</p>

                <div class="section-title">Feedback</div>
                <p>Share feedback directly in the portal for quicker alignment.</p>
            </div>
        </body>
        </html>
        """

        return html, 200
    except Exception as e:
        print(f"❌ Error rendering mini client dashboard: {e}")
        traceback.print_exc()
        return "<h1>Server Error</h1><p>Unable to render dashboard.</p>", 500


# ============================================================================
# CLIENT PROPOSAL ROUTES (using token-based access)
# ============================================================================


@bp.get("/client/proposals")
def get_client_proposals():
    """Get all proposals for a client using their access token"""
    try:
        token = request.args.get('token')
        token = _normalize_access_token(token)
        if not token:
            return {'detail': 'Access token required'}, 400

        device_id, session_token = _extract_client_device_session()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)

            inv_info = _get_invitation_column_info(cursor)
            token_col = inv_info['token_col']
            email_col = inv_info['email_col']
            expires_col = inv_info['expires_col']

            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500

            if not email_col:
                return {'detail': 'Client invitations not configured (missing invited email column)'}, 500
            
            # Get invitation details to find client email
            expires_select = (
                sql.Identifier(expires_col)
                if expires_col
                else sql.SQL('NULL::timestamp')
            )
            cursor.execute(
                sql.SQL(
                    """
                    SELECT proposal_id, {email_col} as invited_email, {expires_col} as expires_at
                    FROM collaboration_invitations
                    WHERE {token_col} = %s
                    """
                ).format(
                    email_col=sql.Identifier(email_col),
                    expires_col=expires_select,
                    token_col=sql.Identifier(token_col),
                ),
                (invitation_token,),
            )
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            # Check if expired
            if invitation.get('expires_at') and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403

            proposal_id = int(invitation.get('proposal_id'))
            configured, err_or_hash, status = _require_identity_configured(cursor, proposal_id)
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
            if not allowed:
                return err_payload, status

            ok, session_err, session_code = _require_client_device_session(cursor, invitation_token, device_id, session_token)
            if not ok:
                conn.commit()
                return session_err, session_code

            client_email = invitation['invited_email']
            token_proposal_id = invitation.get('proposal_id')
            
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']
            columns = column_info['columns']

            engagement_select_parts = []
            if 'opportunity_id' in columns:
                engagement_select_parts.append('p.opportunity_id')
            if 'engagement_stage' in columns:
                engagement_select_parts.append('p.engagement_stage')
            if 'engagement_opened_at' in columns:
                engagement_select_parts.append('p.engagement_opened_at')
            if 'engagement_target_close_at' in columns:
                engagement_select_parts.append('p.engagement_target_close_at')

            engagement_select_sql = ''
            if engagement_select_parts:
                engagement_select_sql = ', ' + ', '.join(engagement_select_parts)

            released_status_where = """
                (
                    LOWER(COALESCE(p.status, '')) LIKE '%%sent to client%%'
                    OR LOWER(COALESCE(p.status, '')) LIKE '%%released%%'
                    OR LOWER(COALESCE(p.status, '')) LIKE '%%sent for signature%%'
                    OR LOWER(COALESCE(p.status, '')) LIKE '%%signed%%'
                )
            """

            query = f"""
                SELECT DISTINCT
                    p.id,
                    p.title,
                    p.status,
                    p.created_at,
                    p.updated_at,
                    {client_name_expr} AS client_name,
                    {client_email_expr} AS client_email,
                    ps.signing_url,
                    ps.status AS signature_status,
                    ps.envelope_id
                    {engagement_select_sql}
                FROM proposals p
                LEFT JOIN LATERAL (
                    SELECT envelope_id, signing_url, status
                    FROM proposal_signatures
                    WHERE proposal_id = p.id
                    ORDER BY sent_at DESC
                    LIMIT 1
                ) ps ON TRUE
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id
                WHERE (
                    ci.invited_email = %s
                    OR ci.access_token = %s
                    OR (%s IS NOT NULL AND p.id = %s)
                )
                AND {released_status_where}
                ORDER BY p.updated_at DESC
            """

            cursor.execute(query, (client_email, invitation_token, token_proposal_id, token_proposal_id))
            
            proposals = cursor.fetchall()
            
            return {
                'client_email': client_email,
                'token_proposal_id': token_proposal_id,
                'proposals': [dict(p) for p in proposals]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/client/proposals/<int:proposal_id>")
def get_client_proposal_details(proposal_id):
    """Get detailed proposal information for client"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400

        token = unquote(str(token)).strip().strip('"').strip("'")
        if not token:
            return {'detail': 'Access token required'}, 400

        device_id, session_token = _extract_client_device_session()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)
            invitation, err, code = _lookup_invitation_by_token(cursor, invitation_token)
            if err:
                return err, code

            token_proposal_id = invitation.get('proposal_id')
            token_proposal_id = int(token_proposal_id) if token_proposal_id is not None else None
            configured, err_or_hash, status = _require_identity_configured(cursor, int(token_proposal_id or 0)) if token_proposal_id is not None else (False, {'detail': 'Invalid access token'}, 404)
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, token_proposal_id)
            if not allowed:
                return err_payload, status

            ok, session_err, session_code = _require_client_device_session(cursor, invitation_token, device_id, session_token)
            if not ok:
                conn.commit()
                return session_err, session_code
            
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']
            columns = column_info['columns']

            if 'user_id' in columns:
                owner_select_expr = 'p.user_id'
                user_join_clause = (
                    "LEFT JOIN users u ON ("
                    "u.username = p.user_id::text "
                    "OR u.id::text = p.user_id::text"
                    ")"
                )
            elif 'owner_id' in columns:
                owner_select_expr = 'p.owner_id'
                user_join_clause = 'LEFT JOIN users u ON u.id::text = p.owner_id::text'
            else:
                owner_select_expr = 'NULL'
                user_join_clause = 'LEFT JOIN users u ON 1 = 0'

            engagement_select_parts = []
            if 'opportunity_id' in columns:
                engagement_select_parts.append('p.opportunity_id')
            if 'engagement_stage' in columns:
                engagement_select_parts.append('p.engagement_stage')
            if 'engagement_opened_at' in columns:
                engagement_select_parts.append('p.engagement_opened_at')
            if 'engagement_target_close_at' in columns:
                engagement_select_parts.append('p.engagement_target_close_at')

            engagement_select_sql = ''
            if engagement_select_parts:
                engagement_select_sql = ', ' + ', '.join(engagement_select_parts)

            query = f"""
                SELECT 
                    p.id, p.title, p.content, p.status, p.created_at, p.updated_at,
                    {client_name_expr} AS client_name,
                    {client_email_expr} AS client_email,
                    {owner_select_expr} AS user_id,
                    u.full_name as owner_name, u.email as owner_email
                    {engagement_select_sql}
                FROM proposals p
                {user_join_clause}
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id AND ci.access_token = %s
                WHERE p.id = %s AND (ci.invited_email = %s OR ci.access_token = %s)
            """

            cursor.execute(query, (invitation_token, proposal_id, invitation['invited_email'], invitation_token))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404

            status_lower = str((proposal.get('status') if isinstance(proposal, dict) else '') or '').strip().lower()
            if not (
                'sent to client' in status_lower
                or 'released' in status_lower
                or 'sent for signature' in status_lower
                or 'signed' in status_lower
            ):
                return {'detail': 'Proposal not yet released to client', 'status': proposal.get('status')}, 403

            proposal_dict = dict(proposal)

            version_info = None
            try:
                cursor.execute(
                    '''SELECT version_number, created_at
                       FROM proposal_versions
                       WHERE proposal_id = %s
                       ORDER BY version_number DESC
                       LIMIT 1''',
                    (proposal_id,),
                )
                version_row = cursor.fetchone()
                if version_row:
                    version_info = {
                        'version_number': version_row.get('version_number'),
                        'created_at': version_row['created_at'].isoformat() if version_row.get('created_at') else None,
                    }
            except Exception as version_err:
                print(f"❌ Error fetching latest proposal version for client view: {version_err}")

            if version_info:
                proposal_dict['version_number'] = version_info['version_number']
                proposal_dict['version_created_at'] = version_info['created_at']
            
            cursor.execute("""
                SELECT envelope_id, signing_url, status, sent_at, signed_at
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            signature = cursor.fetchone()
            
            # Get comments
            cursor.execute("""
                SELECT dc.id, dc.comment_text, dc.created_at, dc.created_by,
                       u.full_name as created_by_name, u.email as created_by_email
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at DESC
            """, (proposal_id,))
            
            comments = cursor.fetchall()
            
            return {
                'proposal': proposal_dict,
                'signature': dict(signature) if signature else None,
                'comments': [dict(c) for c in comments]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposal details: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/proposals/<int:proposal_id>/comment")
def add_client_comment(proposal_id):
    """Add a comment from client"""
    try:
        data = request.get_json()
        token = _normalize_access_token(data.get('token'))
        comment_text = data.get('comment_text')
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text required'}, 400

        device_id, session_token = _extract_client_device_session()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)

            # Verify token
            cursor.execute(
                """
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
                """,
                (invitation_token,),
            )
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403

            configured, err_or_hash, status = _require_identity_configured(cursor, proposal_id)
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
            if not allowed:
                return err_payload, status

            ok, session_err, session_code = _require_client_device_session(
                cursor, invitation_token, device_id, session_token
            )
            if not ok:
                conn.commit()
                return session_err, session_code
            
            # Create or get guest user
            guest_email = invitation['invited_email']
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (guest_email, guest_email, '', f'Client ({guest_email})', 'client'))
            
            guest_user_id = cursor.fetchone()['id']
            conn.commit()
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
            """, (proposal_id, comment_text, guest_user_id, 
                  data.get('section_index'), data.get('highlighted_text'), 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'id': result['id'],
                'message': 'Comment added successfully',
                'created_at': result['created_at'].isoformat() if result['created_at'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error adding client comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/proposals/<int:proposal_id>/approve")
def client_approve_proposal(proposal_id):
    """Client approves proposal - creates DocuSign envelope for signing"""
    try:
        data = request.get_json()
        token = _normalize_access_token(data.get('token'))
        signer_name = data.get('signer_name')
        signer_title = data.get('signer_title', '')
        comments = data.get('comments', '')
        
        if not token or not signer_name:
            return {'detail': 'Token and signer name required'}, 400

        device_id, session_token = _extract_client_device_session()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (invitation_token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403

            configured, err_or_hash, status = _require_identity_configured(cursor, proposal_id)
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
            if not allowed:
                return err_payload, status

            ok, session_err, session_code = _require_client_device_session(
                cursor, invitation_token, device_id, session_token
            )
            if not ok:
                conn.commit()
                return session_err, session_code
            
            client_email = invitation['invited_email']
            
            # Get proposal details - match by client_email OR collaboration_invitation token
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']

            query = f"""
                SELECT p.id, p.title, p.content,
                       {client_name_expr} AS client_name,
                       {client_email_expr} AS client_email
                FROM proposals p
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id AND ci.access_token = %s
                WHERE p.id = %s AND (ci.invited_email = %s OR ci.access_token = %s)
            """

            cursor.execute(query, (invitation_token, proposal_id, client_email, invitation_token))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Check if DocuSign envelope already exists
            cursor.execute("""
                SELECT envelope_id, signing_url, status
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            
            existing_signature = cursor.fetchone()
            
            # If we have a valid signing URL, return it
            signing_url = None
            envelope_id = None
            
            if existing_signature and existing_signature.get('signing_url'):
                status = existing_signature.get('status', '').lower()
                if status not in ['completed', 'declined', 'voided']:
                    signing_url = existing_signature['signing_url']
                    envelope_id = existing_signature['envelope_id']
            
            # If no valid signing URL, create a new DocuSign envelope
            if not signing_url:
                try:
                    from api.utils.helpers import generate_proposal_pdf, create_docusign_envelope
                    import os
                    
                    # Generate PDF
                    pdf_content = generate_proposal_pdf(
                        proposal_id=proposal_id,
                        title=proposal['title'],
                        content=proposal.get('content', ''),
                        client_name=proposal.get('client_name') or signer_name,
                        client_email=client_email
                    )
                    
                    # Create DocuSign envelope
                    # Since we're on HTTP, DocuSign will open in a new tab (not embedded)
                    # Use a return URL that points back to the client proposals page
                    from api.utils.helpers import get_frontend_url
                    frontend_url = get_frontend_url()
                    # Use collaboration router to land in correct client viewer
                    return_url = f"{frontend_url}/#/collaborate?token={invitation_token}&signed=true"
                    
                    envelope_result = create_docusign_envelope(
                        proposal_id=proposal_id,
                        pdf_bytes=pdf_content,
                        signer_name=signer_name,
                        signer_email=client_email,
                        signer_title=signer_title,
                        return_url=return_url
                    )

                    if envelope_result.get('disabled'):
                        return {
                            'detail': envelope_result.get('detail') or 'DocuSign disabled',
                            'error': envelope_result.get('reason') or 'docusign_disabled',
                        }, 501
                    
                    signing_url = envelope_result['signing_url']
                    envelope_id = envelope_result['envelope_id']
                    
                    # Store signature record
                    cursor.execute("""
                        SELECT id FROM proposal_signatures WHERE proposal_id = %s
                    """, (proposal_id,))
                    existing = cursor.fetchone()
                    
                    if existing:
                        # Update existing record
                        cursor.execute("""
                            UPDATE proposal_signatures 
                            SET envelope_id = %s,
                                signer_name = %s,
                                signer_email = %s,
                                signer_title = %s,
                                signing_url = %s,
                                status = %s,
                                sent_at = NOW()
                            WHERE proposal_id = %s
                        """, (
                            envelope_id,
                            signer_name,
                            client_email,
                            signer_title,
                            signing_url,
                            'sent',
                            proposal_id
                        ))
                    else:
                        # Insert new record
                        cursor.execute("""
                            INSERT INTO proposal_signatures 
                            (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                             signing_url, status, created_by)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, NULL)
                        """, (
                            proposal_id,
                            envelope_id,
                            signer_name,
                            client_email,
                            signer_title,
                            signing_url,
                            'sent'
                        ))

                    configured, err_or_hash, status = _require_identity_configured(cursor, proposal_id)
                    if not configured:
                        return err_or_hash, status

                    allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
                    if not allowed:
                        return err_payload, status

                    cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
                    srow = cursor.fetchone()
                    old_status = srow.get('status') if isinstance(srow, dict) else (srow[0] if srow else None)

                    cursor.execute(
                        """
                        UPDATE proposals 
                        SET status = 'Sent for Signature', updated_at = NOW()
                        WHERE id = %s
                        """,
                        (proposal_id,),
                    )

                    conn.commit()

                    if old_status is not None and old_status != 'Sent for Signature':
                        log_status_change(proposal_id, None, old_status, 'Sent for Signature')

                    print(f"✅ Created DocuSign envelope for proposal {proposal_id} (client: {client_email})")
                    
                except ImportError:
                    return {'detail': 'DocuSign integration not available'}, 503
                except Exception as docusign_error:
                    print(f"❌ DocuSign error: {docusign_error}")
                    traceback.print_exc()
                    return {'detail': f'Failed to create signing URL: {str(docusign_error)}'}, 500
            
            return {
                'message': 'Proposal ready for signing',
                'proposal_id': proposal['id'],
                'signing_url': signing_url,
                'envelope_id': envelope_id,
                'status': 'Sent for Signature'
            }, 200
            
    except Exception as e:
        print(f"❌ Error approving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/proposals/<int:proposal_id>/reject")
def client_reject_proposal(proposal_id):
    """Client rejects proposal"""
    try:
        data = request.get_json()
        token = _normalize_access_token(data.get('token'))
        reason = data.get('reason')
        
        if not token or not reason:
            return {'detail': 'Token and reason required'}, 400

        device_id, session_token = _extract_client_device_session()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (invitation_token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403

            configured, err_or_hash, status = _require_identity_configured(cursor, proposal_id)
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
            if not allowed:
                return err_payload, status

            ok, session_err, session_code = _require_client_device_session(
                cursor, invitation_token, device_id, session_token
            )
            if not ok:
                conn.commit()
                return session_err, session_code

            cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
            srow = cursor.fetchone()
            old_status = (
                (srow.get('status') if hasattr(srow, 'get') else (srow[0] if srow else None))
            )
            
            # Update proposal status - match by collaboration_invitation token only
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Client Declined', updated_at = NOW()
                WHERE id = %s AND id IN (
                    SELECT proposal_id FROM collaboration_invitations 
                    WHERE access_token = %s AND proposal_id = %s
                )
                RETURNING id, title
            """, (proposal_id, invitation_token, proposal_id))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Add rejection reason as comment
            rejection_info = f"✗ REJECTED\nReason: {reason}"
            
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (invitation['invited_email'], invitation['invited_email'], '', f'Client ({invitation["invited_email"]})', 'client'))
            
            client_user_id = cursor.fetchone()['id']
            
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
            """, (proposal_id, rejection_info, client_user_id, 'resolved'))

            if old_status is not None and old_status != 'Client Declined':
                log_status_change(proposal_id, client_user_id, old_status, 'Client Declined')
            
            conn.commit()
            
            return {
                'message': 'Proposal rejected',
                'proposal_id': proposal['id'],
                'status': 'Client Declined'
            }, 200
            
    except Exception as e:
        print(f"❌ Error rejecting proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

def get_client_signing_url(proposal_id):
    """Get or create DocuSign signing URL for client"""
    try:
        data = request.get_json() or {}
        token = data.get('token') or request.args.get('token')
        token = _normalize_access_token(token)
        device_id, session_token = _extract_client_device_session()
        if not device_id:
            device_id = (data.get('device_id') or data.get('deviceId') or '').strip() or None
        if not session_token:
            session_token = (data.get('session_token') or data.get('sessionToken') or '').strip() or None
        
        if not token or not device_id or not session_token:
            return {'detail': 'Access token, device ID, and session token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)
            _ensure_client_device_session_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)
            
            # Verify token and get client email
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (invitation_token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403

            configured, err_or_hash, status = _require_identity_configured(cursor, proposal_id)
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, proposal_id)
            if not allowed:
                return err_payload, status

            ok, session_err, session_code = _require_client_device_session(
                cursor, invitation_token, device_id, session_token
            )
            if not ok:
                conn.commit()
                return session_err, session_code
            
            client_email = invitation['invited_email']
            
            # Get proposal details - match by collaboration_invitation token
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']

            query = f"""
                SELECT p.id, p.title, p.content,
                       {client_name_expr} AS client_name,
                       {client_email_expr} AS client_email
                FROM proposals p
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id AND ci.access_token = %s
                WHERE p.id = %s AND (ci.invited_email = %s OR ci.access_token = %s)
            """

            cursor.execute(query, (invitation_token, proposal_id, client_email, invitation_token))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Check if signing URL already exists and is still valid
            cursor.execute("""
                SELECT envelope_id, signing_url, status
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            
            existing_signature = cursor.fetchone()
            
            # If we have a valid signing URL, return it
            if existing_signature and existing_signature.get('signing_url'):
                # Check if envelope is still active (not completed/declined)
                status = existing_signature.get('status', '').lower()
                if status not in ['completed', 'declined', 'voided']:
                    return {
                        'signing_url': existing_signature['signing_url'],
                        'envelope_id': existing_signature['envelope_id'],
                        'status': existing_signature.get('status', 'sent')
                    }, 200
            
            # No valid signing URL exists, create a new DocuSign envelope
            try:
                from api.utils.helpers import generate_proposal_pdf, create_docusign_envelope
                import os
                
                # Generate PDF
                pdf_content = generate_proposal_pdf(
                    proposal_id=proposal_id,
                    title=proposal['title'],
                    content=proposal.get('content', ''),
                    client_name=proposal.get('client_name'),
                    client_email=client_email
                )
                
                # Create DocuSign envelope
                # Since we're on HTTP, DocuSign will open in a new tab (not embedded)
                # Use a return URL that points back to the client proposals page
                frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                # Use collaboration router to land in correct client viewer
                return_url = f"{frontend_url}/#/collaborate?token={invitation_token}&signed=true"
                
                envelope_result = create_docusign_envelope(
                    proposal_id=proposal_id,
                    pdf_bytes=pdf_content,
                    signer_name=proposal.get('client_name') or client_email,
                    signer_email=client_email,
                    signer_title='',
                    return_url=return_url
                )
                
                # Store signature record - check if one exists first
                cursor.execute("""
                    SELECT id FROM proposal_signatures WHERE proposal_id = %s
                """, (proposal_id,))
                existing = cursor.fetchone()
                
                if existing:
                    # Update existing record
                    cursor.execute("""
                        UPDATE proposal_signatures 
                        SET envelope_id = %s,
                            signer_name = %s,
                            signer_email = %s,
                            signer_title = %s,
                            signing_url = %s,
                            status = %s,
                            sent_at = NOW()
                        WHERE proposal_id = %s
                        RETURNING id, signing_url, envelope_id
                    """, (
                        envelope_result['envelope_id'],
                        proposal.get('client_name') or client_email,
                        client_email,
                        '',
                        envelope_result['signing_url'],
                        'sent',
                        proposal_id
                    ))
                else:
                    # Insert new record
                    cursor.execute("""
                        INSERT INTO proposal_signatures 
                        (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                         signing_url, status, created_by)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, NULL)
                        RETURNING id, signing_url, envelope_id
                    """, (
                        proposal_id,
                        envelope_result['envelope_id'],
                        proposal.get('client_name') or client_email,
                        client_email,
                        '',
                        envelope_result['signing_url'],
                        'sent'
                    ))
                
                signature_record = cursor.fetchone()
                conn.commit()
                
                print(f"✅ Created DocuSign envelope for proposal {proposal_id} (client: {client_email})")
                
                return {
                    'signing_url': signature_record['signing_url'],
                    'envelope_id': signature_record['envelope_id'],
                    'status': 'sent',
                    'message': 'Signing URL created successfully'
                }, 200
                
            except ImportError:
                return {'detail': 'DocuSign integration not available'}, 503
            except Exception as docusign_error:
                print(f"❌ DocuSign error: {docusign_error}")
                traceback.print_exc()
                return {'detail': f'Failed to create signing URL: {str(docusign_error)}'}, 500
            
    except Exception as e:
        print(f"❌ Error getting signing URL: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# LEGACY CLIENT ROUTES (for backward compatibility)
# ============================================================================

@bp.get("/client/proposals-legacy")
@token_required
def fetch_client_proposals(username=None):
    """Get client proposals (legacy route)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals WHERE client_can_edit = true ORDER BY created_at DESC'''
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row[0],
                    'title': row[1],
                    'client': row[2],
                    'owner_id': row[3],
                    'status': row[4],
                    'created_at': row[5].isoformat() if row[5] else None
                })
            return proposals, 200
    except Exception as e:
        print(f"❌ Error fetching client proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


def client_sign_proposal_token(proposal_id=None):
    """Sign a proposal as client using a share token (client portal)."""
    try:
        data = request.get_json(silent=True) or {}
        token = unquote(str(data.get('token') or request.args.get('token'))).strip().strip('"').strip("'")
        signer_name = (data.get('signer_name') or '').strip()
        if not token:
            return {'detail': 'Token is required'}, 400
        if not signer_name:
            return {'detail': 'Signer name is required'}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            _ensure_identity_schema(cursor)

            invitation_token = _resolve_invitation_token(cursor, token)

            inv_info = _get_invitation_column_info(cursor)
            token_col = inv_info['token_col']
            email_col = inv_info['email_col']
            expires_col = inv_info['expires_col']
            if not token_col or not email_col:
                return {'detail': 'Client invitations not configured'}, 500

            expires_select = (
                sql.Identifier(expires_col)
                if expires_col
                else sql.SQL('NULL::timestamp')
            )
            cursor.execute(
                sql.SQL(
                    """
                    SELECT proposal_id, {email_col} as invited_email, {expires_col} as expires_at
                    FROM collaboration_invitations
                    WHERE {token_col} = %s
                    """
                ).format(
                    email_col=sql.Identifier(email_col),
                    expires_col=expires_select,
                    token_col=sql.Identifier(token_col),
                ),
                (invitation_token,),
            )
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404

            if invitation.get('expires_at') and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403

            token_proposal_id = invitation.get('proposal_id')
            if token_proposal_id is not None and str(token_proposal_id) != str(proposal_id):
                return {'detail': 'Token is not valid for this proposal'}, 403

            configured, err_or_hash, status = _require_identity_configured(cursor, int(proposal_id))
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, int(proposal_id))
            if not allowed:
                return err_payload, status

            signer_email = (invitation.get('invited_email') or '').strip() or None

            cursor.execute("SELECT status FROM proposals WHERE id = %s", (proposal_id,))
            prow = cursor.fetchone()
            if not prow:
                return {'detail': 'Proposal not found'}, 404

            old_status = prow.get('status') if isinstance(prow, dict) else None

            cursor.execute(
                """UPDATE proposals
                   SET status = 'Client Signed', updated_at = NOW()
                   WHERE id = %s""",
                (proposal_id,),
            )

            # Optional: record signature details
            try:
                cursor.execute("SELECT to_regclass(%s)", ("public.proposal_signatures",))
                has_signatures = cursor.fetchone().get('to_regclass') is not None
            except Exception:
                has_signatures = False

            if has_signatures:
                try:
                    cursor.execute(
                        """UPDATE proposal_signatures
                           SET signer_name = %s,
                               signer_email = COALESCE(%s, signer_email),
                               status = 'signed',
                               signed_at = NOW()
                           WHERE proposal_id = %s""",
                        (signer_name, signer_email, proposal_id),
                    )
                except Exception:
                    pass

            # Log activity
            try:
                metadata = json.dumps({'signer_name': signer_name, 'signer_email': signer_email})
                cursor.execute(
                    """
                    INSERT INTO proposal_client_activity
                    (proposal_id, client_id, event_type, metadata, created_at)
                    VALUES (%s, NULL, %s, %s::jsonb, NOW())
                    """,
                    (proposal_id, 'sign', metadata),
                )
            except Exception:
                pass

            conn.commit()

            if old_status and old_status != 'Client Signed':
                try:
                    log_status_change(proposal_id, None, old_status, 'Client Signed')
                except Exception:
                    pass

            return {'success': True, 'detail': 'Proposal signed by client'}, 200

    except Exception as e:
        print(f"❌ Error signing proposal by token: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/client/proposals/<int:proposal_id>/sign_token")
def client_sign_proposal_token_api(proposal_id):
    return client_sign_proposal_token(proposal_id)


@bp.get("/api/client/proposals")
def get_client_proposals_api():
    return get_client_proposals()


@bp.get("/api/client/proposals/<int:proposal_id>")
def get_client_proposal_details_api(proposal_id):
    return get_client_proposal_details(proposal_id)

@bp.get("/client/proposals/<int:proposal_id>")
@token_required
def get_client_proposal(username=None, proposal_id=None):
    """Get a client proposal (legacy route)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at, content
                   FROM proposals WHERE id = %s AND client_can_edit = true''',
                (proposal_id,)
            )
            result = cursor.fetchone()
            
            if result:
                return {
                    'id': result[0],
                    'title': result[1],
                    'client': result[2],
                    'owner_id': result[3],
                    'status': result[4],
                    'created_at': result[5].isoformat() if result[5] else None,
                    'content': result[6]
                }, 200
            return {'detail': 'Proposal not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/client/proposals/<int:proposal_id>/sign")
@token_required
def client_sign_proposal(username=None, proposal_id=None):
    """Sign a proposal as client (legacy route)"""
    try:
        data = request.get_json()
        signer_name = data.get('signer_name')
        
        if not signer_name:
            return {'detail': 'Signer name is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
            srow = cursor.fetchone()
            old_status = srow[0] if srow else None

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            urow = cursor.fetchone()
            actor_id = urow[0] if urow else None

            cursor.execute(
                '''UPDATE proposals SET status = 'Client Signed' WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()

            if old_status is not None and old_status != 'Client Signed':
                log_status_change(proposal_id, actor_id, old_status, 'Client Signed')
            return {'detail': 'Proposal signed by client'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/client/dashboard_stats")
@token_required
def get_client_dashboard_stats(username=None):
    """Get client dashboard statistics"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT status, COUNT(*) FROM proposals WHERE client_can_edit = true
                   GROUP BY status'''
            )
            rows = cursor.fetchall()
            stats = {row[0]: row[1] for row in rows}
            return stats, 200
    except Exception as e:
        return {'detail': str(e)}, 500

# ============================================================================
# CLIENT ACTIVITY TRACKING ROUTES
# ============================================================================

@bp.post("/client/activity")
def log_client_activity():
    """Log client activity event (open, close, view_section, download, sign, comment)"""
    try:
        data = request.get_json()
        if not data:
            return {'detail': 'Request body required'}, 400
        
        token = data.get('token')
        proposal_id = data.get('proposal_id')
        event_type = data.get('event_type')
        metadata = data.get('metadata', {})
        
        if not token or not proposal_id or not event_type:
            return {'detail': 'Token, proposal_id, and event_type required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'collaboration_invitations'
                """
            )
            inv_cols = {r['column_name'] for r in cursor.fetchall()}

            token_col = 'access_token' if 'access_token' in inv_cols else ('token' if 'token' in inv_cols else None)
            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500

            token = _normalize_access_token(token)
            if not token:
                return {'detail': 'Token, proposal_id, and event_type required'}, 400

            invitation_token = _resolve_invitation_token(cursor, token)
            
            # Get client info from token
            cursor.execute("""
                SELECT ci.invited_email, ci.proposal_id, c.id as client_id
                FROM collaboration_invitations ci
                LEFT JOIN clients c ON c.email = ci.invited_email
                WHERE ci.""" + token_col + """ = %s
            """, (invitation_token,))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Invalid access token'}, 404

            inv_proposal_id = result.get('proposal_id')
            if inv_proposal_id is not None and str(inv_proposal_id) != str(proposal_id):
                return {'detail': 'Token is not valid for this proposal'}, 403

            configured, err_or_hash, status = _require_identity_configured(cursor, int(inv_proposal_id or proposal_id))
            if not configured:
                return err_or_hash, status

            allowed, err_payload, status = _require_unlocked_for_invitation(cursor, invitation_token, int(inv_proposal_id or proposal_id))
            if not allowed:
                return err_payload, status
            
            client_email = result['invited_email']
            client_id = result.get('client_id')
            
            # If client doesn't exist in clients table, try to find by email
            if not client_id:
                cursor.execute("""
                    SELECT id FROM clients WHERE email = %s
                """, (client_email,))
                client_row = cursor.fetchone()
                client_id = client_row['id'] if client_row else None
            
            # Convert proposal_id to appropriate type (handle both int and UUID)
            # First try to get proposal to verify it exists
            cursor.execute("""
                SELECT id FROM proposals WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            actual_proposal_id = proposal['id']
            
            # Insert activity log
            import json as json_module
            metadata_json = json_module.dumps(metadata) if metadata else '{}'
            
            cursor.execute("""
                INSERT INTO proposal_client_activity 
                (proposal_id, client_id, event_type, metadata, created_at)
                VALUES (%s, %s, %s, %s::jsonb, NOW())
                RETURNING id, created_at
            """, (actual_proposal_id, client_id, event_type, metadata_json))
            
            activity = cursor.fetchone()
            conn.commit()
            
            return {
                'success': True,
                'activity_id': str(activity['id']),
                'created_at': activity['created_at'].isoformat() if activity['created_at'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error logging client activity: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/session/start")
def start_client_session():
    """Start a new client session for time tracking"""
    try:
        data = request.get_json()
        if not data:
            return {'detail': 'Request body required'}, 400
        
        token = data.get('token')
        proposal_id = data.get('proposal_id')
        
        if not token or not proposal_id:
            return {'detail': 'Token and proposal_id required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'collaboration_invitations'
                """
            )
            inv_cols = {r['column_name'] for r in cursor.fetchall()}

            token_col = 'access_token' if 'access_token' in inv_cols else ('token' if 'token' in inv_cols else None)
            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500
            
            # Get client info from token
            cursor.execute("""
                SELECT ci.invited_email, c.id as client_id
                FROM collaboration_invitations ci
                LEFT JOIN clients c ON c.email = ci.invited_email
                WHERE ci.""" + token_col + """ = %s
            """, (token,))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Invalid access token'}, 404
            
            client_id = result.get('client_id')
            if not client_id:
                cursor.execute("SELECT id FROM clients WHERE email = %s", (result['invited_email'],))
                client_row = cursor.fetchone()
                client_id = client_row['id'] if client_row else None
            
            # Verify proposal exists
            cursor.execute("""
                SELECT id FROM proposals WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            actual_proposal_id = proposal['id']
            
            # Create session
            cursor.execute("""
                INSERT INTO proposal_client_session 
                (proposal_id, client_id, session_start)
                VALUES (%s, %s, NOW())
                RETURNING id, session_start
            """, (actual_proposal_id, client_id))
            
            session = cursor.fetchone()
            conn.commit()
            
            return {
                'success': True,
                'session_id': str(session['id']),
                'session_start': session['session_start'].isoformat() if session['session_start'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error starting client session: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/session/end")
def end_client_session():
    """End a client session and calculate time spent"""
    try:
        data = request.get_json()
        if not data:
            return {'detail': 'Request body required'}, 400
        
        session_id = data.get('session_id')
        
        if not session_id:
            return {'detail': 'session_id required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get session
            cursor.execute("""
                SELECT id, session_start, proposal_id, client_id
                FROM proposal_client_session
                WHERE id = %s OR id::text = %s
            """, (session_id, str(session_id)))
            
            session = cursor.fetchone()
            if not session:
                return {'detail': 'Session not found'}, 404
            
            # Calculate time spent
            session_end = datetime.now()
            session_start = session['session_start']
            if session_start:
                total_seconds = int((session_end - session_start).total_seconds())
            else:
                total_seconds = 0
            
            # Update session
            cursor.execute("""
                UPDATE proposal_client_session
                SET session_end = %s, total_seconds = %s
                WHERE id = %s
                RETURNING id, total_seconds
            """, (session_end, total_seconds, session['id']))
            
            updated = cursor.fetchone()
            conn.commit()
            
            return {
                'success': True,
                'session_id': str(updated['id']),
                'total_seconds': updated['total_seconds']
            }, 200
            
    except Exception as e:
        print(f"❌ Error ending client session: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500









