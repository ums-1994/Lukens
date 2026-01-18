"""
JWT token validation and decoding
"""
import logging
import os
from typing import Dict, Any, List

import jwt
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
        or os.getenv("SECRET_KEY")
    )
    if not secret:
        raise JWTValidationError("JWT secret not configured")
    return secret


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

    parts = token.split(".")
    if len(parts) != 3:
        raise JWTValidationError(
            f"Invalid token format: expected 3 parts, got {len(parts)}"
        )

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
    Priority: Admin > Manager > Creator > User
    """
    if not roles or not isinstance(roles, list):
        return "user"
    
    # Check for admin role first (highest priority)
    if "Proposal & SOW Builder - Admin" in roles:
        logger.info("Admin role detected: Proposal & SOW Builder - Admin")
        return "admin"
    
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

