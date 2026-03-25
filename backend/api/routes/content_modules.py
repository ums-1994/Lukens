"""
Versioned Content Modules API.

This surfaces the `content_modules` + `module_versions` tables that were previously
only provided as SQL seeds, so the Content Library can be managed via routes.
"""

from flask import Blueprint, request, jsonify
import psycopg2.extras

from api.utils.database import get_db_connection
from api.utils.decorators import token_required


bp = Blueprint("content_modules", __name__)


def _as_int(value):
    if value is None:
        return None
    try:
        return int(value)
    except Exception:
        return None


@bp.get("/content-modules")
@token_required
def list_content_modules(username=None, user_id=None, email=None):
    """List versioned content modules (optionally filtered by category or q)."""
    try:
        category = (request.args.get("category") or "").strip()
        q = (request.args.get("q") or "").strip()
        include_body = (request.args.get("include_body") or "").lower() in ("1", "true", "yes")

        where = ["1=1"]
        params = []
        if category:
            where.append("m.category = %s")
            params.append(category)
        if q:
            where.append("(m.title ILIKE %s OR m.body ILIKE %s)")
            params.extend([f"%{q}%", f"%{q}%"])

        body_expr = "m.body" if include_body else "NULL::text AS body"
        where_sql = " AND ".join(where)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                f"""
                SELECT
                    m.id,
                    m.title,
                    m.category,
                    {body_expr},
                    m.version,
                    m.created_by,
                    m.created_at,
                    m.updated_at,
                    m.is_editable
                FROM content_modules m
                WHERE {where_sql}
                ORDER BY m.updated_at DESC, m.id DESC
                """,
                tuple(params),
            )
            rows = cursor.fetchall() or []
            return {"modules": [dict(r) for r in rows]}, 200
    except Exception as e:
        return {"detail": str(e)}, 500


@bp.get("/content-modules/<int:module_id>")
@token_required
def get_content_module(username=None, user_id=None, email=None, module_id=None):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT id, title, category, body, version, created_by, created_at, updated_at, is_editable
                FROM content_modules
                WHERE id = %s
                """,
                (module_id,),
            )
            row = cursor.fetchone()
            if not row:
                return {"detail": "Module not found"}, 404
            return dict(row), 200
    except Exception as e:
        return {"detail": str(e)}, 500


@bp.post("/content-modules")
@token_required
def create_content_module(username=None, user_id=None, email=None):
    """Create a new module. Also writes an initial module_versions snapshot."""
    try:
        data = request.get_json(force=True, silent=True) or {}
        title = (data.get("title") or "").strip()
        category = (data.get("category") or "Other").strip() or "Other"
        body = (data.get("body") or "").strip()
        is_editable = bool(data.get("is_editable", True))
        note = (data.get("note") or "").strip() or "Initial version"

        if not title:
            return {"detail": "title is required"}, 400
        if not body:
            return {"detail": "body is required"}, 400

        creator_id = _as_int(user_id)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                INSERT INTO content_modules (title, category, body, version, created_by, is_editable)
                VALUES (%s, %s, %s, 1, %s, %s)
                RETURNING id
                """,
                (title, category, body, creator_id, is_editable),
            )
            module_id = cursor.fetchone()["id"]
            cursor.execute(
                """
                INSERT INTO module_versions (module_id, version, snapshot, note, created_by)
                VALUES (%s, 1, %s, %s, %s)
                """,
                (module_id, body, note, creator_id),
            )
            conn.commit()
            return {"id": module_id}, 201
    except Exception as e:
        return {"detail": str(e)}, 500


@bp.put("/content-modules/<int:module_id>")
@token_required
def update_content_module(username=None, user_id=None, email=None, module_id=None):
    """Update module fields; automatically snapshots the previous body into module_versions."""
    try:
        data = request.get_json(force=True, silent=True) or {}
        title = data.get("title")
        category = data.get("category")
        body = data.get("body")
        is_editable = data.get("is_editable")
        note = (data.get("note") or "").strip() or None

        editor_id = _as_int(user_id)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                "SELECT id, body, version FROM content_modules WHERE id = %s",
                (module_id,),
            )
            existing = cursor.fetchone()
            if not existing:
                return {"detail": "Module not found"}, 404

            updates = []
            params = []
            if title is not None:
                updates.append("title = %s")
                params.append(str(title).strip())
            if category is not None:
                updates.append("category = %s")
                params.append(str(category).strip() or "Other")
            body_changed = False
            if body is not None:
                updates.append("body = %s")
                params.append(str(body))
                body_changed = True
            if is_editable is not None:
                updates.append("is_editable = %s")
                params.append(bool(is_editable))

            if not updates:
                return {"detail": "No updates provided"}, 400

            new_version = int(existing["version"] or 1)
            if body_changed:
                # Snapshot old body to module_versions (current version)
                cursor.execute(
                    """
                    INSERT INTO module_versions (module_id, version, snapshot, note, created_by)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (
                        module_id,
                        new_version,
                        existing["body"] or "",
                        note or f"Auto-snapshot before update to v{new_version + 1}",
                        editor_id,
                    ),
                )
                new_version += 1
                updates.append("version = %s")
                params.append(new_version)

            updates.append("updated_at = CURRENT_TIMESTAMP")
            params.append(module_id)

            cursor.execute(
                f"UPDATE content_modules SET {', '.join(updates)} WHERE id = %s",
                tuple(params),
            )
            conn.commit()
            return {"detail": "Module updated", "version": new_version}, 200
    except Exception as e:
        return {"detail": str(e)}, 500


@bp.delete("/content-modules/<int:module_id>")
@token_required
def delete_content_module(username=None, user_id=None, email=None, module_id=None):
    """Delete a module and its versions."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM content_modules WHERE id = %s", (module_id,))
            if cursor.rowcount == 0:
                return {"detail": "Module not found"}, 404
            conn.commit()
            return {"detail": "Module deleted"}, 200
    except Exception as e:
        return {"detail": str(e)}, 500


@bp.get("/content-modules/<int:module_id>/versions")
@token_required
def list_module_versions(username=None, user_id=None, email=None, module_id=None):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT id, module_id, version, note, created_by, created_at
                FROM module_versions
                WHERE module_id = %s
                ORDER BY version DESC, id DESC
                """,
                (module_id,),
            )
            rows = cursor.fetchall() or []
            return {"versions": [dict(r) for r in rows]}, 200
    except Exception as e:
        return {"detail": str(e)}, 500


@bp.get("/content-modules/<int:module_id>/versions/<int:version>")
@token_required
def get_module_version(username=None, user_id=None, email=None, module_id=None, version=None):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT id, module_id, version, snapshot, note, created_by, created_at
                FROM module_versions
                WHERE module_id = %s AND version = %s
                ORDER BY id DESC
                LIMIT 1
                """,
                (module_id, version),
            )
            row = cursor.fetchone()
            if not row:
                return {"detail": "Version not found"}, 404
            return dict(row), 200
    except Exception as e:
        return {"detail": str(e)}, 500

