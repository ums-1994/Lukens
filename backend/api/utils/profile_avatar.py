"""
User profile avatar stored as Cloudinary URL + public_id on users row.
"""
import traceback

import cloudinary.uploader

from api.utils.database import get_db_connection


def user_profile_row_to_dict(row):
    """Map a 9-column users SELECT to API JSON."""
    if not row:
        return None
    return {
        "id": row[0],
        "username": row[1],
        "email": row[2],
        "full_name": row[3],
        "role": row[4],
        "department": row[5],
        "is_active": row[6],
        "profile_image_url": row[7],
        "profile_image_public_id": row[8],
    }


def fetch_user_profile_dict_by_username(username: str):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """SELECT id, username, email, full_name, role, department, is_active,
                          profile_image_url, profile_image_public_id
                   FROM users WHERE username = %s""",
                (username,),
            )
            row = cursor.fetchone()
            return user_profile_row_to_dict(row)
    except Exception:
        traceback.print_exc()
        return None


def patch_user_profile_avatar(username: str, data: dict):
    """
    Update or clear profile photo metadata.
    - Set: { "profile_image_url": "<https...>", "profile_image_public_id": "<id>" }
    - Clear: { "clear_profile_image": true }
    """
    if not data:
        return {"detail": "JSON body required"}, 400

    clear = data.get("clear_profile_image") is True
    new_url = data.get("profile_image_url")
    new_pid = data.get("profile_image_public_id")

    if clear:
        new_url, new_pid = None, None
    else:
        if not isinstance(new_url, str) or not new_url.strip():
            return {"detail": "profile_image_url must be a non-empty string"}, 400
        if not isinstance(new_pid, str) or not new_pid.strip():
            return {"detail": "profile_image_public_id must be a non-empty string"}, 400
        new_url = new_url.strip()
        new_pid = new_pid.strip()

    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """SELECT profile_image_public_id FROM users WHERE username = %s""",
                (username,),
            )
            prev = cursor.fetchone()
            if not prev:
                return {"detail": "User not found"}, 404

            old_pid = prev[0]
            if old_pid and (clear or old_pid != new_pid):
                try:
                    cloudinary.uploader.destroy(old_pid, resource_type="image")
                except Exception as ex:
                    print(f"[WARN] Could not destroy old Cloudinary asset {old_pid}: {ex}")

            cursor.execute(
                """UPDATE users SET profile_image_url = %s, profile_image_public_id = %s,
                   updated_at = CURRENT_TIMESTAMP WHERE username = %s""",
                (new_url, new_pid, username),
            )
            conn.commit()

            cursor.execute(
                """SELECT id, username, email, full_name, role, department, is_active,
                          profile_image_url, profile_image_public_id
                   FROM users WHERE username = %s""",
                (username,),
            )
            row = cursor.fetchone()
            return user_profile_row_to_dict(row), 200
    except Exception as e:
        traceback.print_exc()
        return {"detail": str(e)}, 500
