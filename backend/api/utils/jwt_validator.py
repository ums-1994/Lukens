"""
JWT token validation and decoding
"""
import logging
import os
import base64
from typing import Dict, Any

import jwt
from jwt.exceptions import (
    InvalidTokenError,
    ExpiredSignatureError,
    DecodeError,
    InvalidSignatureError,
)
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


logger = logging.getLogger(__name__)


class JWTValidationError(Exception):
    """Custom exception for JWT validation errors"""
    pass


def _get_jwt_secret() -> str:
    secret = (
        os.getenv("JWT_SECRET_KEY")
        or os.getenv("KHONOBUZZ_JWT_SECRET")
        or os.getenv("JWT_SECRET")
        or os.getenv("SECRET_KEY")
    )
    if not secret:
        raise JWTValidationError("JWT secret not configured")
    return secret


def _get_encryption_key_bytes() -> bytes:
    key = os.getenv("ENCRYPTION_KEY")
    if not key:
        return b""
    k = key.strip()
    try:
        return base64.urlsafe_b64decode(k)
    except Exception:
        try:
            return base64.urlsafe_b64decode(k + "=" * (-len(k) % 4))
        except Exception:
            pass
    if len(k) == 32:
        return k.encode()
    if len(k) > 32:
        return k[:32].encode()
    return k.ljust(32).encode()


def _try_decrypt_with_fernet(token: str) -> str:
    key_bytes = _get_encryption_key_bytes()
    if not key_bytes:
        raise JWTValidationError("Encryption key not configured")
    fkey = base64.urlsafe_b64encode(key_bytes)
    try:
        f = Fernet(fkey)
        pt = f.decrypt(token.encode(), ttl=None)
        return pt.decode()
    except Exception as e:
        raise JWTValidationError(f"Fernet decryption failed: {e}")


def _try_decrypt_with_aesgcm(token: str) -> str:
    key_bytes = _get_encryption_key_bytes()
    if not key_bytes:
        raise JWTValidationError("Encryption key not configured")
    t = token.strip()
    parts = []
    if ":" in t:
        parts = t.split(":")
    elif "." in t and t.count(".") != 2:
        parts = t.split(".")
    if len(parts) == 3:
        try:
            iv = base64.urlsafe_b64decode(parts[0] + "=" * (-len(parts[0]) % 4))
            ct = base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4))
            tag = base64.urlsafe_b64decode(parts[2] + "=" * (-len(parts[2]) % 4))
            aes = AESGCM(key_bytes[:32])
            pt = aes.decrypt(iv, ct + tag, None)
            return pt.decode()
        except Exception as e:
            raise JWTValidationError(f"AES-GCM decryption failed: {e}")
    try:
        raw = base64.urlsafe_b64decode(t + "=" * (-len(t) % 4))
        if len(raw) >= 12 + 16:
            iv = raw[:12]
            tag = raw[-16:]
            ct = raw[12:-16]
            aes = AESGCM(key_bytes[:32])
            pt = aes.decrypt(iv, ct + tag, None)
            return pt.decode()
    except Exception as e:
        raise JWTValidationError(f"AES-GCM raw decryption failed: {e}")
    raise JWTValidationError("Unsupported encrypted token format")


def _maybe_decrypt_token(token: str) -> str:
    if token.count(".") == 2:
        return token
    last_error = None
    for fn in (_try_decrypt_with_fernet, _try_decrypt_with_aesgcm):
        try:
            dec = fn(token)
            if dec.count(".") == 2:
                return dec
        except JWTValidationError as e:
            last_error = e
            continue
    if last_error:
        raise last_error
    raise JWTValidationError("Token decryption failed or invalid format")


def validate_jwt_token(token: str) -> Dict[str, Any]:
    """
    Validate and decode JWT token from Khonobuzz

    This function:
    1. Validates the token structure (3 parts separated by dots)
    2. Verifies the token signature using configured secret
    3. Checks token expiration
    4. Returns decoded payload for further processing
    """
    if not token or not isinstance(token, str):
        raise JWTValidationError("Token is required and must be a string")

    if token.count(".") != 2:
        token = _maybe_decrypt_token(token)

    try:
        secret = _get_jwt_secret()

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


def extract_user_info(decoded_token: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract user information from decoded JWT token

    Handles multiple field name variations:
    - user_id, uid, sub, userId (for user ID)
    - email, user_email, email_address (for email)
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

    if not user_id:
        raise JWTValidationError(
            "Token missing required field: user_id (or uid/sub). "
            "Available fields: " + ", ".join(decoded_token.keys())
        )

    email_str = str(email) if email else ""

    return {
        "user_id": str(user_id),
        "email": email_str,
    }

