"""
JWT token validation and decoding
"""
import logging
import os
import base64
import json
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

import jwt
from cryptography.fernet import Fernet
from jwt.exceptions import (
    InvalidTokenError,
    ExpiredSignatureError,
    DecodeError,
    InvalidSignatureError,
)


logger = logging.getLogger(__name__)


class JWTValidationError(Exception):
    """Custom exception for JWT validation errors"""
    pass


def _get_jwt_secret() -> str:
    secret = (
        os.getenv("KHONOBUZZ_JWT_SECRET")
        or os.getenv("JWT_SECRET")
        or os.getenv("JWT_SECRET_KEY")
        or os.getenv("SECRET_KEY")
    )
    if not secret:
        raise JWTValidationError("JWT secret not configured")
    return secret


def validate_jwt_token(token: str) -> Dict[str, Any]:
    """
    Validate and decode JWT token from Khonobuzz

    This function:
    1. Normalizes the token string (Bearer/quotes/URL-encoded)
    2. If not a 3-part JWT, attempts Fernet decryption using ENCRYPTION_KEY
    3. If decrypted to JSON, returns claims (verifies exp if present)
    4. Otherwise verifies HS256 JWT signature and exp
    5. Returns decoded payload for further processing
    """
    if not token or not isinstance(token, str):
        raise JWTValidationError("Token is required and must be a string")
    # Normalize token first
    token = _normalize_token(token)
    
    logger.info(f"Processing token: {token[:50]}... (length: {len(token)})")
    logger.info(f"Token contains dots: {token.count('.')}")

    # If not a standard JWT (3 parts), try Fernet decryption
    if token.count('.') != 2:
        logger.info("Token is not a standard JWT, attempting Fernet decryption")
        maybe_plain = _try_decrypt_fernet(token)
        if maybe_plain:
            token = maybe_plain.strip()
            logger.info(f"Fernet decryption successful, new token: {token[:50]}... (length: {len(token)})")
        else:
            logger.warning("Fernet decryption failed, no key available or invalid token")

    # If now a JWT, validate as HS256
    if token.count('.') == 2:
        logger.info("Token is now a JWT, attempting validation")
        try:
            secret = _get_jwt_secret()
            logger.info(f"JWT secret available: {secret is not None}")

            decoded = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
                options={
                    "verify_signature": True,
                    "verify_exp": True,
                },
            )

            logger.info(
                "JWT token validated successfully for user_id: %s",
                decoded.get("user_id") or decoded.get("uid") or decoded.get("sub"),
            )
            return decoded

        except ExpiredSignatureError:
            logger.warning("JWT token has expired")
            raise JWTValidationError("Token has expired")
        except InvalidSignatureError:
            logger.warning("JWT token signature is invalid")
            raise JWTValidationError("Invalid token signature")
        except DecodeError as e:
            logger.warning("Failed to decode JWT token: %s", e)
            raise JWTValidationError(f"Invalid token format: {e}")
        except jwt.MissingRequiredClaimError as e:
            logger.warning("Missing required claim in JWT token: %s", e)
            raise JWTValidationError(f"Token missing required field: {e}")
        except InvalidTokenError as e:
            logger.warning("Invalid JWT token: %s", e)
            raise JWTValidationError(f"Invalid token: {e}")
        except Exception as e:
            logger.error("Unexpected error validating JWT token: %s", e)
            raise JWTValidationError(f"Token validation failed: {e}")

    # Try interpret as JSON claims (for encrypted tokens that decrypt to JSON)
    try:
        claims = json.loads(token)
        # Optional exp validation if present
        exp = claims.get('exp')
        if exp is not None:
            now_ts = int(datetime.now(timezone.utc).timestamp())
            try:
                exp_ts = int(exp)
            except Exception:
                exp_ts = int(float(exp))
            if now_ts >= exp_ts:
                raise JWTValidationError("Token has expired")
        logger.info("JSON claims token validated (no JWT signature)")
        return claims  # type: ignore[return-value]
    except JWTValidationError:
        raise
    except Exception:
        pass

    raise JWTValidationError(
        "Invalid token format: expected JWT or encrypted JWT/JSON"
    )

def _normalize_token(token: str) -> str:
    t = token.strip()
    # Extract from URL if full link passed
    try:
        from urllib.parse import urlparse, parse_qs
        parsed = urlparse(t)
        if parsed.query:
            qs = parse_qs(parsed.query)
            if 'token' in qs and qs['token']:
                t = qs['token'][0]
    except Exception:
        pass
    # Strip Bearer prefix
    if t.lower().startswith('bearer '):
        t = t[7:].strip()
    # Strip wrapping quotes
    if (t.startswith('"') and t.endswith('"')) or (t.startswith("'") and t.endswith("'")):
        t = t[1:-1].strip()
    # Decode percent-encoding
    try:
        from urllib.parse import unquote
        t = unquote(t)
    except Exception:
        pass
    return t


def _get_fernet() -> Optional[Fernet]:
    key = (
        os.getenv('JWT_ENCRYPTION_KEY')
        or os.getenv('ENCRYPTION_KEY')
        or os.getenv('FERNET_KEY')
    )
    
    # Debug logging to check what keys are available
    logger.info("Checking encryption keys:")
    logger.info(f"  JWT_ENCRYPTION_KEY: {'SET' if os.getenv('JWT_ENCRYPTION_KEY') else 'NOT SET'}")
    logger.info(f"  ENCRYPTION_KEY: {'SET' if os.getenv('ENCRYPTION_KEY') else 'NOT SET'}")
    logger.info(f"  FERNET_KEY: {'SET' if os.getenv('FERNET_KEY') else 'NOT SET'}")
    logger.info(f"  Selected key: {'SET' if key else 'NONE'}")
    
    if not key:
        return None
    # First, try using the provided key as-is (already urlsafe base64?)
    try:
        candidate = key.encode() if isinstance(key, str) else key
        return Fernet(candidate)
    except Exception:
        pass
    # Fallback: pad/trim to 32 bytes then urlsafe-base64 encode
    try:
        padded = key.ljust(32)[:32].encode()
        fkey = base64.urlsafe_b64encode(padded)
        return Fernet(fkey)
    except Exception as e:
        logger.warning("Failed to initialize Fernet with provided key: %s", e)
        return None


def _try_decrypt_fernet(token: str) -> Optional[str]:
    f = _get_fernet()
    if not f:
        return None
    try:
        plain = f.decrypt(token.encode(), ttl=None)
        try:
            return plain.decode()
        except Exception:
            return plain.decode('utf-8', errors='ignore')
    except Exception:
        return None


def extract_user_info(decoded_token: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract user information from decoded JWT token from KHONOBUZZ

    Handles multiple field name variations:
    - user_id, uid, sub, userId (for user ID)
    - email, user_email, email_address (for email)
    - full_name, name (for user's full name)
    - roles (array of role strings from KHONOBUZZ)
    """
    user_id = (
        decoded_token.get("user_id")
        or decoded_token.get("uid")
        or decoded_token.get("sub")
        or decoded_token.get("userId")
    )

    email = (
        decoded_token.get("email")
        or decoded_token.get("user_email")
        or decoded_token.get("email_address")
    )

    full_name = (
        decoded_token.get("full_name")
        or decoded_token.get("name")
    )

    # Extract roles array and determine primary role
    roles = decoded_token.get("roles", [])
    role = _determine_primary_role(roles)

    if not user_id:
        raise JWTValidationError(
            "Token missing required field: user_id (or uid/sub). "
            "Available fields: " + ", ".join(decoded_token.keys())
        )

    email_str = str(email) if email else ""

    return {
        "user_id": str(user_id),
        "email": email_str,
        "full_name": str(full_name) if full_name else email_str.split('@')[0],
        "role": role,
        "roles": roles,  # Keep original roles array
    }


def _determine_primary_role(roles: List[str]) -> str:
    """
    Determine the primary role from KHONOBUZZ roles array.
    Priority: Admin > Finance > Manager > Creator > User
    """
    if not roles or not isinstance(roles, list):
        return "user"
    
    # Check for admin role first (highest priority)
    if "Proposal & SOW Builder - Admin" in roles:
        logger.info("Admin role detected: Proposal & SOW Builder - Admin")
        return "admin"
    
    # Check for finance role (second highest priority)
    if any(role in roles for role in [
        "Proposal & SOW Builder - Finance",
        "Finance Manager",
        "Financial Manager"
    ]):
        logger.info("Finance role detected")
        return "finance"
    
    # Check for manager roles
    if any(role in roles for role in [
        "Proposal & SOW Builder - Manager",
        "Skills Heatmap - Manager"
    ]):
        logger.info("Manager role detected")
        return "manager"
    
    # Check for creator roles
    if any(role in roles for role in [
        "Proposal & SOW Builder - Creator",
        "PDH - Employee"
    ]):
        logger.info("Creator role detected")
        return "creator"
    
    # Default to user role
    logger.info("Default user role assigned")
    return "user"

