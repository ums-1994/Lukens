"""
Creator role routes - Content management, proposal CRUD, AI features, uploads
"""
from flask import Blueprint, request, jsonify
import io
import json
import os
import re
import traceback
import cloudinary
import cloudinary.api
import cloudinary.uploader
import psycopg2.extras
from datetime import datetime
import requests

try:
    from PyPDF2 import PdfReader
except ImportError:
    PdfReader = None

try:
    import docx
except ImportError:
    docx = None

from api.utils.database import get_db_connection
from api.utils.decorators import token_required
from api.utils.ai_safety import AISafetyError

bp = Blueprint('creator', __name__, url_prefix='')


def _normalize_kb_filter(value):
    if value is None:
        return None
    value = str(value).strip()
    return value or None


def _kb_clause_keys_for_issue(issue: dict):
    category = str(issue.get("category") or "").lower()
    description = str(issue.get("description") or "").lower()
    recommendation = str(issue.get("recommendation") or "").lower()
    combined = " ".join([category, description, recommendation])

    clause_keys = set()

    if any(t in combined for t in ["credential", "api key", "apikey", "secret", "token", "password"]):
        clause_keys.add("no_credentials_minimum")

    if any(
        t in combined
        for t in [
            "pii",
            "personal data",
            "personal information",
            "id number",
            "passport",
            "email",
            "phone",
        ]
    ):
        clause_keys.add("pii_handling_minimum")

    if any(t in combined for t in ["confidential", "confidentiality", "nda", "non-disclosure"]):
        clause_keys.add("confidentiality_minimum")

    return sorted(clause_keys)


def _kb_recommendations_for_issues(conn, issues):
    if not issues:
        return {
            "clause_keys": [],
            "clauses": [],
        }

    clause_keys = set()
    for issue in issues:
        if not isinstance(issue, dict):
            continue
        for key in _kb_clause_keys_for_issue(issue):
            clause_keys.add(key)

    clause_keys = sorted(clause_keys)
    if not clause_keys:
        return {
            "clause_keys": [],
            "clauses": [],
        }

    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute(
        """
        SELECT
            c.id,
            d.key AS document_key,
            c.clause_key,
            c.title,
            c.category,
            c.severity,
            c.clause_text,
            c.recommended_text,
            c.tags,
            c.is_active,
            c.created_at,
            c.updated_at
        FROM kb_clauses c
        JOIN kb_documents d ON d.id = c.document_id
        WHERE c.is_active = TRUE
          AND c.clause_key = ANY(%s)
        ORDER BY c.id
        """,
        (clause_keys,),
    )
    clauses = cursor.fetchall() or []
    return {
        "clause_keys": clause_keys,
        "clauses": [dict(r) for r in clauses],
    }


@bp.get("/kb/documents")
@token_required
def kb_list_documents(username=None):
    try:
        keys = request.args.getlist("key") or None
        include_inactive = (request.args.get("include_inactive") or "").lower() in ("1", "true", "yes")

        where = ["1=1"]
        params = []
        if not include_inactive:
            where.append("is_active = TRUE")
        if keys:
            where.append("key = ANY(%s)")
            params.append(keys)

        where_sql = " AND ".join(where)
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                f"""
                SELECT id, key, title, doc_type, tags, body, version, is_active, created_at, updated_at
                FROM kb_documents
                WHERE {where_sql}
                ORDER BY id
                """,
                tuple(params),
            )
            docs = cursor.fetchall() or []
            return {"documents": [dict(r) for r in docs]}, 200
    except Exception as e:
        print(f"❌ Error listing kb documents: {e}")
        traceback.print_exc()
        return {"detail": str(e)}, 500


@bp.get("/kb/clauses")
@token_required
def kb_list_clauses(username=None):
    try:
        document_key = _normalize_kb_filter(request.args.get("document_key"))
        category = _normalize_kb_filter(request.args.get("category"))
        severity = _normalize_kb_filter(request.args.get("severity"))
        clause_keys = request.args.getlist("clause_key") or None
        include_inactive = (request.args.get("include_inactive") or "").lower() in ("1", "true", "yes")

        where = ["1=1"]
        params = []
        if not include_inactive:
            where.append("c.is_active = TRUE")
        if document_key:
            where.append("d.key = %s")
            params.append(document_key)
        if clause_keys:
            where.append("c.clause_key = ANY(%s)")
            params.append(clause_keys)
        if category:
            where.append("LOWER(c.category) = LOWER(%s)")
            params.append(category)
        if severity:
            where.append("LOWER(c.severity) = LOWER(%s)")
            params.append(severity)

        where_sql = " AND ".join(where)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                f"""
                SELECT
                    c.id,
                    d.key AS document_key,
                    c.clause_key,
                    c.title,
                    c.category,
                    c.severity,
                    c.clause_text,
                    c.recommended_text,
                    c.tags,
                    c.is_active,
                    c.created_at,
                    c.updated_at
                FROM kb_clauses c
                JOIN kb_documents d ON d.id = c.document_id
                WHERE {where_sql}
                ORDER BY c.id
                """,
                tuple(params),
            )
            clauses = cursor.fetchall() or []
            return {"clauses": [dict(r) for r in clauses]}, 200
    except Exception as e:
        print(f"❌ Error listing kb clauses: {e}")
        traceback.print_exc()
        return {"detail": str(e)}, 500


def _slugify(value: str) -> str:
    value = (value or "").strip().lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value or "kb_doc"


def _download_asset_bytes(*, url: str) -> tuple[bytes, str | None]:
    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    content_type = resp.headers.get("content-type")
    return resp.content, content_type


def _extract_text_from_file_bytes(file_bytes: bytes, content_type: str | None, filename: str | None) -> str:
    lowered_name = (filename or "").lower()
    lowered_ct = (content_type or "").lower()

    if lowered_name.endswith(".pdf") or "application/pdf" in lowered_ct:
        if PdfReader is None:
            raise ValueError("PDF extraction requires PyPDF2 to be installed")
        reader = PdfReader(io.BytesIO(file_bytes))
        parts = []
        for page in reader.pages:
            try:
                parts.append(page.extract_text() or "")
            except Exception:
                parts.append("")
        return "\n".join(parts).strip()

    if lowered_name.endswith(".docx") or "application/vnd.openxmlformats-officedocument.wordprocessingml.document" in lowered_ct:
        if docx is None:
            raise ValueError("DOCX extraction requires python-docx to be installed")
        doc = docx.Document(io.BytesIO(file_bytes))
        return "\n".join([p.text for p in doc.paragraphs if p.text]).strip()

    if lowered_name.endswith(".txt") or lowered_ct.startswith("text/"):
        return file_bytes.decode("utf-8", errors="ignore").strip()

    return file_bytes.decode("utf-8", errors="ignore").strip()


@bp.post("/kb/import/cloudinary")
@token_required
def kb_import_from_cloudinary(username=None):
    try:
        data = request.get_json() or {}

        public_id = (data.get("public_id") or "").strip() or None
        url = (data.get("url") or "").strip() or None

        document_key = (data.get("document_key") or "").strip() or None
        title = (data.get("title") or "").strip() or None
        doc_type = (data.get("doc_type") or "policy").strip() or "policy"
        tags = data.get("tags")
        version = (data.get("version") or "").strip() or None

        if not public_id and not url:
            return {"detail": "public_id or url is required"}, 400

        if public_id and not url:
            resource = cloudinary.api.resource(public_id, resource_type="raw")
            url = resource.get("secure_url") or resource.get("url")
            if not title:
                title = resource.get("original_filename")
            filename = resource.get("original_filename")
            ext = resource.get("format")
            if filename and ext and not filename.lower().endswith(f".{ext}"):
                filename = f"{filename}.{ext}"
        else:
            filename = None

        if not url:
            return {"detail": "Could not resolve asset url"}, 400

        file_bytes, content_type = _download_asset_bytes(url=url)
        extracted_text = _extract_text_from_file_bytes(file_bytes, content_type, filename)
        if not extracted_text:
            return {"detail": "Could not extract text from document"}, 400

        from ai_service import ai_service
        from api.utils.ai_safety import sanitize_for_external_ai, AISafetyError

        safety_result = sanitize_for_external_ai({"kb_source_text": extracted_text[:200000]})
        if safety_result.blocked:
            raise AISafetyError(
                "Blocked outbound AI KB import due to sensitive data detected.",
                reasons=safety_result.block_reasons,
            )

        kb_title = title or "KB Document"
        kb_key = document_key or _slugify(kb_title)

        prompt = f"""You are a compliance and governance assistant. Extract reusable knowledge base clauses from the provided document.

Document Title: {kb_title}

Document Text:
{safety_result.sanitized.get('kb_source_text')}

Return ONLY valid JSON in this exact shape:
{{
  "document": {{
    "key": "string",
    "title": "string",
    "doc_type": "policy|template|legal|security|process|other",
    "version": "string|null",
    "tags": ["tag1", "tag2"],
    "source_url": "string|null"
  }},
  "clauses": [
    {{
      "clause_key": "string",
      "title": "string",
      "category": "security|legal|privacy|governance|quality|delivery|other",
      "severity": "low|medium|high|critical",
      "clause_text": "string",
      "recommended_text": "string",
      "tags": ["tag1", "tag2"]
    }}
  ]
}}

Rules:
- Produce 5-20 clauses max.
- clause_key must be unique, snake_case, and stable.
- Keep clause_text concise.
"""

        messages = [
            {"role": "system", "content": "You extract structured KB clauses. Always return valid JSON only."},
            {"role": "user", "content": prompt},
        ]

        response_text = ai_service._make_request(messages, temperature=0.2, max_tokens=2000)
        start_idx = response_text.find("{")
        end_idx = response_text.rfind("}") + 1
        payload = response_text[start_idx:end_idx]
        parsed = json.loads(payload)

        parsed_doc = parsed.get("document") or {}
        clauses = parsed.get("clauses") or []

        doc_tags = parsed_doc.get("tags")
        if not isinstance(doc_tags, list):
            doc_tags = []
        if isinstance(tags, list):
            doc_tags = list(dict.fromkeys([*doc_tags, *tags]))

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                INSERT INTO kb_documents (key, title, doc_type, tags, body, version)
                VALUES (%s, %s, %s, %s::jsonb, %s, %s)
                ON CONFLICT (key)
                DO UPDATE SET
                  title = EXCLUDED.title,
                  doc_type = EXCLUDED.doc_type,
                  tags = EXCLUDED.tags,
                  body = EXCLUDED.body,
                  version = EXCLUDED.version,
                  updated_at = CURRENT_TIMESTAMP
                RETURNING id
                """,
                (
                    kb_key,
                    parsed_doc.get("title") or kb_title,
                    parsed_doc.get("doc_type") or doc_type,
                    json.dumps(doc_tags),
                    (parsed_doc.get("source_url") or url),
                    parsed_doc.get("version") or version,
                ),
            )
            document_id = (cursor.fetchone() or {}).get("id")

            inserted = 0
            for idx, clause in enumerate(clauses):
                if not isinstance(clause, dict):
                    continue
                clause_key = (clause.get("clause_key") or "").strip()
                clause_title = (clause.get("title") or "").strip() or f"Clause {idx + 1}"
                category = (clause.get("category") or "other").strip() or "other"
                severity = (clause.get("severity") or "medium").strip() or "medium"
                clause_text = (clause.get("clause_text") or "").strip()
                recommended_text = (clause.get("recommended_text") or "").strip() or None
                clause_tags = clause.get("tags")
                if not isinstance(clause_tags, list):
                    clause_tags = []

                if not clause_text:
                    continue

                if not clause_key:
                    clause_key = f"{kb_key}_{_slugify(clause_title)}"

                cursor.execute(
                    """
                    INSERT INTO kb_clauses (document_id, clause_key, title, category, severity, clause_text, recommended_text, tags)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb)
                    ON CONFLICT (clause_key)
                    DO UPDATE SET
                      title = EXCLUDED.title,
                      category = EXCLUDED.category,
                      severity = EXCLUDED.severity,
                      clause_text = EXCLUDED.clause_text,
                      recommended_text = EXCLUDED.recommended_text,
                      tags = EXCLUDED.tags,
                      updated_at = CURRENT_TIMESTAMP
                    """,
                    (
                        document_id,
                        clause_key,
                        clause_title,
                        category,
                        severity,
                        clause_text,
                        recommended_text,
                        json.dumps(clause_tags),
                    ),
                )
                inserted += 1

            conn.commit()

        return {
            "document_key": kb_key,
            "title": kb_title,
            "source_url": url,
            "clauses_upserted": inserted,
        }, 200

    except Exception as e:
        print(f"❌ KB import error: {e}")
        traceback.print_exc()
        return {"detail": "Internal error"}, 500

# ============================================================================
# CONTENT LIBRARY ROUTES
# ============================================================================

@bp.get("/content")
def get_content():
    """Get all content items (no auth for content library)"""
    try:
        category = request.args.get('category', None)
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Build query with optional category filter
            query = '''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                       FROM content WHERE is_deleted = false'''
            params = []
            
            if category:
                query += ' AND category = %s'
                params.append(category)
            
            query += ' ORDER BY created_at DESC'
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            content = []
            for row in rows:
                content.append({
                    'id': row[0],
                    'key': row[1],
                    'label': row[2],
                    'content': row[3],
                    'category': row[4],
                    'is_folder': row[5],
                    'parent_id': row[6],
                    'public_id': row[7]
                })
            
            print(f"📚 Content library: Found {len(content)} items" + (f" (category: {category})" if category else ""))
            return {'content': content}, 200
    except Exception as e:
        print(f"❌ Error fetching content: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/content")
def create_content():
    """Create a new content item (no auth for content library)"""
    try:
        data = request.get_json()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''INSERT INTO content (key, label, content, category, is_folder, parent_id, public_id)
                   VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id''',
                (data['key'], data['label'], data.get('content', ''), 
                 data.get('category', 'Templates'), data.get('is_folder', False),
                 data.get('parent_id'), data.get('public_id'))
            )
            content_id = cursor.fetchone()[0]
            conn.commit()
            return {'id': content_id, 'detail': 'Content created'}, 201
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.put("/content/<int:content_id>")
@token_required
def update_content(username=None, content_id=None):
    """Update a content item"""
    try:
        data = request.get_json()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            updates = []
            params = []
            if 'label' in data:
                updates.append('label = %s')
                params.append(data['label'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            if 'category' in data:
                updates.append('category = %s')
                params.append(data['category'])
            if 'public_id' in data:
                updates.append('public_id = %s')
                params.append(data['public_id'])
            
            if not updates:
                return {'detail': 'No updates provided'}, 400
            
            params.append(content_id)
            cursor.execute(f'''UPDATE content SET {', '.join(updates)} WHERE id = %s''', params)
            conn.commit()
            return {'detail': 'Content updated'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.delete("/content/<int:content_id>")
@token_required
def delete_content(username=None, content_id=None):
    """Delete a content item (soft delete)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('UPDATE content SET is_deleted = true WHERE id = %s', (content_id,))
            conn.commit()
            return {'detail': 'Content deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/content/<int:content_id>/restore")
@token_required
def restore_content(username=None, content_id=None):
    """Restore a deleted content item"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('UPDATE content SET is_deleted = false WHERE id = %s', (content_id,))
            conn.commit()
            return {'detail': 'Content restored'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.delete("/content/<int:content_id>/permanent")
@token_required
def permanently_delete_content(username=None, content_id=None):
    """Permanently delete a content item"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM content WHERE id = %s', (content_id,))
            conn.commit()
            return {'detail': 'Content permanently deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/content/trash")
@token_required
def get_trash(username=None):
    """Get all deleted content items"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                           FROM content WHERE is_deleted = true ORDER BY created_at DESC''')
            rows = cursor.fetchall()
            trash = []
            for row in rows:
                trash.append({
                    'id': row[0],
                    'key': row[1],
                    'label': row[2],
                    'content': row[3],
                    'category': row[4],
                    'is_folder': row[5],
                    'parent_id': row[6],
                    'public_id': row[7]
                })
            return trash, 200
    except Exception as e:
        return {'detail': str(e)}, 500

# ============================================================================
# PROPOSAL ROUTES (CREATOR)
# ============================================================================

# Proposal CRUD routes moved to api/routes/proposals.py

@bp.get("/proposals/my_proposals")
@token_required
def get_my_proposals(username=None):
    """Get all proposals created by the user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals WHERE owner_id = (SELECT id FROM users WHERE username = %s)
                   ORDER BY created_at DESC''',
                (username,)
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
            return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/submit")
@token_required
def submit_for_review(username=None, proposal_id=None):
    """Submit proposal for review"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]

            cursor.execute('SELECT id FROM proposals WHERE id = %s AND owner_id = %s', (proposal_id, user_id))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            cursor.execute(
                '''UPDATE proposals SET status = 'Submitted', updated_at = CURRENT_TIMESTAMP WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            return {'detail': 'Proposal submitted for review'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/send-for-approval")
@bp.post("/api/proposals/<int:proposal_id>/send-for-approval")
@token_required
def send_for_approval(username=None, proposal_id=None, user_id=None, email=None):
    """Send proposal for approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Prefer user_id supplied by the Firebase token_required decorator.
            # This avoids re-querying the users table, which can fail under
            # the Render visibility issues you're seeing.
            effective_user_id = None
            if user_id:
                effective_user_id = user_id
                print(f"🔍 Using user_id from decorator for send_for_approval: {effective_user_id}")
            else:
                # Fallback: Get user ID from username (try multiple times in case user was just created)
                user_row = None
                for attempt in range(3):
                    cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                    user_row = cursor.fetchone()
                    if user_row:
                        break
                    # If user not found and this is the first attempt, wait a bit (user might have just been created)
                    if attempt == 0:
                        import time
                        time.sleep(0.1)  # Small delay to allow transaction to commit
                
                if not user_row:
                    print(f"❌ User lookup failed after 3 attempts for username: {username}")
                    return {'detail': 'User not found'}, 404
                effective_user_id = user_row[0]

            user_id = effective_user_id
            
            # Determine ownership column based on actual schema (owner_id vs user_id)
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                """
            )
            existing_columns = [row[0] for row in cursor.fetchall()]

            owner_col = None
            if 'owner_id' in existing_columns:
                owner_col = 'owner_id'
            elif 'user_id' in existing_columns:
                owner_col = 'user_id'

            if not owner_col:
                print("⚠️ No owner_id or user_id column found in proposals table when sending for approval")
                return {
                    'detail': 'Proposals table is missing owner column; cannot verify ownership'
                }, 500

            # Check if proposal exists and belongs to user (cast owner column to text for type safety)
            cursor.execute(
                f"SELECT id FROM proposals WHERE id = %s AND {owner_col}::text = %s",
                (proposal_id, str(user_id)),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Update status to "Pending CEO Approval" (more descriptive than "In Review")
            cursor.execute(
                '''UPDATE proposals SET status = 'Pending CEO Approval', updated_at = CURRENT_TIMESTAMP WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            return {'detail': 'Proposal sent for approval', 'status': 'Pending CEO Approval'}, 200
    except Exception as e:
        print(f"❌ Error sending proposal for approval: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/send_to_client")
@token_required
def send_to_client(username=None, proposal_id=None):
    """Send proposal to client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            def _get_table_columns(table_name: str):
                cursor.execute(
                    """
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = %s
                    """,
                    (table_name,),
                )
                cols = cursor.fetchall() or []
                return {
                    (c['column_name'] if isinstance(c, dict) else c[0])
                    for c in cols
                }

            def _pick_first(existing, candidates):
                for c in candidates:
                    if c in existing:
                        return c
                return None

            proposal_cols = _get_table_columns('proposals')

            client_expr = 'client'
            if 'client' not in proposal_cols and 'client_name' in proposal_cols:
                client_expr = 'client_name'

            client_email_expr = 'client_email' if 'client_email' in proposal_cols else "NULL::text"

            owner_expr = 'owner_id'
            if 'owner_id' not in proposal_cols and 'user_id' in proposal_cols:
                owner_expr = 'user_id'
            
            cursor.execute(
                f"""
                SELECT id,
                       title,
                       {client_expr} as client_name,
                       {client_email_expr} as client_email,
                       {owner_expr} as user_id
                FROM proposals
                WHERE id = %s
                """,
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            # Run compound risk gate check
            risk_result = evaluate_compound_risk(dict(proposal))
            if risk_result.get('blocked'):
                return {
                    'detail': 'Proposal blocked by risk gate',
                    'risk_score': risk_result.get('score'),
                    'flags': risk_result.get('flags', []),
                    'message': 'This proposal has too many risk factors. Please address the issues before sending to client.'
                }, 400                
            
            cursor.execute(
                "SELECT id, full_name, username, email FROM users WHERE username = %s",
                (username,),
            )
            sender = cursor.fetchone()
            
            if not sender:
                return {'detail': 'User not found'}, 404
            
            # Update status
            new_status = 'Sent to Client'
            cursor.execute(
                """UPDATE proposals SET status = %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s""",
                (new_status, proposal_id)
            )
            conn.commit()
            
            # Send email to client
            email_sent = False
            client_email = proposal.get('client_email')
            client_name = proposal.get('client_name', 'Client')
            proposal_title = proposal.get('title', 'Proposal')
            
            if client_email and client_email.strip():
                try:
                    from api.utils.email import send_email, get_logo_html
                    import secrets
                    
                    from api.utils.helpers import get_frontend_url
                    frontend_url = get_frontend_url()
                    access_token = secrets.token_urlsafe(32)

                    # Store token in collaboration_invitations for client access
                    try:
                        inv_cols = _get_table_columns('collaboration_invitations')
                        inv_email_col = _pick_first(
                            inv_cols,
                            ['invited_email', 'invitee_email', 'email', 'client_email', 'collaborator_email'],
                        )
                        invited_by_col = _pick_first(
                            inv_cols,
                            ['invited_by', 'inviter_id', 'created_by', 'user_id'],
                        )
                        permission_col = _pick_first(inv_cols, ['permission_level', 'permission', 'role'])
                        token_col = _pick_first(inv_cols, ['access_token', 'token'])
                        status_col = _pick_first(inv_cols, ['status'])
                        proposal_id_col = 'proposal_id' if 'proposal_id' in inv_cols else None

                        insert_cols = []
                        insert_vals = []
                        if proposal_id_col:
                            insert_cols.append(proposal_id_col)
                            insert_vals.append(proposal_id)
                        if inv_email_col:
                            insert_cols.append(inv_email_col)
                            insert_vals.append(client_email.strip())
                        if invited_by_col:
                            sender_id = sender.get('id')
                            if not sender_id:
                                raise RuntimeError('missing_sender_id_for_invitation')
                            insert_cols.append(invited_by_col)
                            insert_vals.append(sender_id)
                        if permission_col:
                            insert_cols.append(permission_col)
                            insert_vals.append('view')
                        if token_col:
                            insert_cols.append(token_col)
                            insert_vals.append(access_token)
                        if status_col:
                            insert_cols.append(status_col)
                            insert_vals.append('pending')

                        if proposal_id_col and inv_email_col and insert_cols:
                            placeholders = ', '.join(['%s'] * len(insert_cols))
                            cols_sql = ', '.join(insert_cols)
                            cursor.execute(
                                f"""INSERT INTO collaboration_invitations ({cols_sql})
                                   VALUES ({placeholders})
                                   ON CONFLICT DO NOTHING""",
                                tuple(insert_vals),
                            )
                            conn.commit()
                        else:
                            print(
                                "⚠️ collaboration_invitations schema missing required columns; skipping invitation insert"
                            )
                    except Exception as inv_err:
                        print(f"⚠️ Failed to insert collaboration invitation: {inv_err}")
                        traceback.print_exc()

                    client_link = f"{frontend_url}/#/collaborate?token={access_token}"
                    
                    sender_name = sender.get('full_name') or sender.get('username') or 'Your Team'
                    
                    email_subject = f"Proposal: {proposal_title}"
                    email_body = f"""
                    {get_logo_html()}
                    <h2>Your Proposal is Ready</h2>
                    <p>Dear {client_name},</p>
                    <p>We're pleased to share your proposal: <strong>{proposal_title}</strong></p>
                    <p>Click the link below to view and review your proposal:</p>
                    <p style="text-align: center; margin: 30px 0;">
                        <a href="{client_link}" style="background-color: #27AE60; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; display: inline-block; font-size: 16px; font-weight: 600;">View Proposal</a>
                    </p>
                    <p>Or copy and paste this link into your browser:</p>
                    <p style="word-break: break-all; color: #666;"><a href="{client_link}" style="color: #0066cc; text-decoration: underline;">{client_link}</a></p>
                    <p>If you have any questions, please don't hesitate to reach out.</p>
                    <p>Best regards,<br>{sender_name}</p>
                    """
                    
                    email_sent = send_email(client_email, email_subject, email_body)
                    if email_sent:
                        print(f"[EMAIL] Proposal email sent to {client_email}")
                    else:
                        print(f"[EMAIL] Failed to send proposal email to {client_email}")
                except Exception as email_error:
                    print(f"[EMAIL] Error sending proposal email: {email_error}")
                    traceback.print_exc()
            else:
                if client_email is None:
                    print(f"[EMAIL] No client_email column available on proposals table for proposal {proposal_id}")
                else:
                    print(f"[EMAIL] No valid client email found for proposal {proposal_id}: '{client_email}'")
            
            return {
                'detail': 'Proposal sent to client',
                'status': new_status,
                'email_sent': email_sent
            }, 200
    except Exception as e:
        print(f"❌ Error sending proposal to client: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# UPLOAD ROUTES
# ============================================================================

@bp.post("/upload/image")
def upload_image():
    """Upload an image to Cloudinary"""
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        url = result.get('secure_url') or result.get('url')
        public_id = result.get('public_id')
        return {
            'success': True,
            'url': url,
            'public_id': public_id,
            'resource_type': result.get('resource_type'),
            'width': result.get('width'),
            'height': result.get('height'),
            'bytes': result.get('bytes'),
            'result': result,
        }, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/upload/template")
def upload_template():
    """Upload a template to Cloudinary"""
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file, resource_type='raw')
        url = result.get('secure_url') or result.get('url')
        public_id = result.get('public_id')
        return {
            'success': True,
            'url': url,
            'public_id': public_id,
            'resource_type': result.get('resource_type'),
            'bytes': result.get('bytes'),
            'result': result,
        }, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.delete("/upload/<public_id>")
@token_required
def delete_from_cloudinary(username=None, public_id=None):
    """Delete a file from Cloudinary"""
    try:
        cloudinary.uploader.destroy(public_id)
        return {'detail': 'File deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/upload/signature")
@token_required
def get_upload_signature(username=None):
    """Get upload signature for Cloudinary"""
    try:
        data = request.get_json()
        public_id = data.get('public_id')
        
        # This would normally generate a real Cloudinary signature
        signature = "dummy_signature"
        return {'signature': signature, 'public_id': public_id}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

# ============================================================================
# VERSION MANAGEMENT ROUTES
# ============================================================================

@bp.post("/proposals/<int:proposal_id>/versions")
@token_required
def create_version(username=None, proposal_id=None, user_id=None, email=None):
    """Create a new version of a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating version {data.get('version_number')} for proposal {proposal_id}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Determine user ID: prefer the value supplied by token_required,
            # fall back to a lookup by username if needed.
            if user_id:
                effective_user_id = user_id
                print(f"🔍 Using user_id from decorator for create_version: {effective_user_id}")
            else:
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                effective_user_id = user_row[0] if user_row else None

            user_id = effective_user_id
            
            # Get next version number if not provided
            if 'version_number' not in data:
                cursor.execute(
                    'SELECT COALESCE(MAX(version_number), 0) + 1 FROM proposal_versions WHERE proposal_id = %s',
                    (proposal_id,)
                )
                version_number = cursor.fetchone()[0] or 1
            else:
                version_number = data.get('version_number', 1)
            
            try:
                cursor.execute(
                    '''INSERT INTO proposal_versions 
                       (proposal_id, version_number, content, created_by)
                       VALUES (%s, %s, %s, %s)
                       RETURNING id, proposal_id, version_number, content, created_by, created_at''',
                    (
                        proposal_id,
                        version_number,
                        data.get('content', ''),
                        user_id
                    )
                )
                result = cursor.fetchone()
                conn.commit()
            except Exception as seq_error:
                # Rollback the failed transaction
                conn.rollback()
                
                # If sequence issue, reset it and try again in a new transaction
                if 'duplicate key' in str(seq_error).lower() or 'pkey' in str(seq_error).lower():
                    print(f"⚠️ Sequence issue detected, resetting sequence for proposal_versions")
                    try:
                        cursor.execute("""
                            SELECT setval(pg_get_serial_sequence('proposal_versions', 'id'), 
                                         COALESCE((SELECT MAX(id) FROM proposal_versions), 1), true)
                        """)
                        conn.commit()
                        
                        # Retry the insert in a fresh transaction
                        cursor.execute(
                            '''INSERT INTO proposal_versions 
                               (proposal_id, version_number, content, created_by)
                               VALUES (%s, %s, %s, %s)
                               RETURNING id, proposal_id, version_number, content, created_by, created_at''',
                            (
                                proposal_id,
                                version_number,
                                data.get('content', ''),
                                user_id
                            )
                        )
                        result = cursor.fetchone()
                        conn.commit()
                    except Exception as retry_error:
                        conn.rollback()
                        raise Exception(f"Failed to create version after sequence reset: {retry_error}")
                else:
                    # For other errors, re-raise
                    raise
            
            version = {
                'id': result[0],
                'proposal_id': result[1],
                'version_number': result[2],
                'content': result[3],
                'created_by': result[4],
                'created_at': result[5].isoformat() if result[5] else None
            }
            
            print(f"✅ Version {result[2]} created for proposal {proposal_id}")
            return version, 201
    except Exception as e:
        print(f"❌ Error creating version: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/proposals/<int:proposal_id>/versions")
@token_required
def get_versions(username=None, proposal_id=None):
    """Get all versions of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at
                   FROM proposal_versions
                   WHERE proposal_id = %s
                   ORDER BY version_number DESC''',
                (proposal_id,)
            )
            rows = cursor.fetchall()
            
            versions = []
            for row in rows:
                versions.append({
                    'id': row[0],
                    'proposal_id': row[1],
                    'version_number': row[2],
                    'content': row[3],
                    'created_by': row[4],
                    'created_at': row[5].isoformat() if row[5] else None
                })
            
            print(f"✅ Found {len(versions)} versions for proposal {proposal_id}")
            return versions, 200
    except Exception as e:
        print(f"❌ Error getting versions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/proposals/<int:proposal_id>/versions/<int:version_number>")
@token_required
def get_version(username=None, proposal_id=None, version_number=None):
    """Get a specific version of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at, change_description
                   FROM proposal_versions
                   WHERE proposal_id = %s AND version_number = %s''',
                (proposal_id, version_number)
            )
            row = cursor.fetchone()
            
            if not row:
                return {'detail': 'Version not found'}, 404
            
            version = {
                'id': row[0],
                'proposal_id': row[1],
                'version_number': row[2],
                'content': row[3],
                'created_by': row[4],
                'created_at': row[5].isoformat() if row[5] else None,
                'change_description': row[6]
            }
            
            return version, 200
    except Exception as e:
        print(f"❌ Error getting version: {e}")
        return {'detail': str(e)}, 500

# ============================================================================
# AI ROUTES
# ============================================================================


@bp.get("/ai/status")
@token_required
def ai_status(username=None):
    try:
        from ai_service import ai_service

        provider = getattr(ai_service, "provider", None)
        model = getattr(ai_service, "model", None)
        ai_enabled = True

        if provider != "gemini":
            api_key = getattr(ai_service, "api_key", None)
            ai_enabled = bool(api_key)

        return {
            "ai_enabled": ai_enabled,
            "provider": provider,
            "model": model,
        }, 200
    except Exception as e:
        print(f"❌ Error checking AI status: {e}")
        traceback.print_exc()
        return {"ai_enabled": False, "detail": str(e)}, 200


@bp.post("/ai/check-compliance")
@token_required
def ai_check_compliance(username=None):
    try:
        data = request.get_json() or {}
        proposal_id = data.get("proposal_id")
        if not proposal_id:
            return {"detail": "proposal_id is required"}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("SELECT * FROM proposals WHERE id = %s", (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {"detail": "Proposal not found"}, 404

        from ai_service import ai_service

        result = ai_service.check_compliance(dict(proposal))
        return {"compliance": result}, 200
    except AISafetyError as e:
        return {"detail": str(e), "blocked": True, "reasons": e.reasons}, 400
    except Exception as e:
        print(f"❌ Error checking compliance: {e}")
        traceback.print_exc()
        return {"detail": str(e)}, 500

@bp.post("/ai/generate")
@token_required
def ai_generate_content(username=None):
    """Generate proposal content using AI"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        context = data.get('context', {})
        section_type = data.get('section_type', 'general')
        
        if not prompt:
            return {'detail': 'Prompt is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Create enhanced prompt with context
        full_context = {
            'user_request': prompt,
            'section_type': section_type,
            **context
        }
        
        # Generate content
        generated_content = ai_service.generate_proposal_section(section_type, full_context)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'generate', prompt[:500], section_type, 
                      len(generated_content.split()), response_time_ms))
                conn.commit()
                print(f"📊 AI usage tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return {
            'content': generated_content,
            'section_type': section_type
        }, 200
        
    except AISafetyError as e:
        return {"detail": str(e), "blocked": True, "reasons": e.reasons}, 400
    except Exception as e:
        print(f"❌ Error generating AI content: {e}")
        return {'detail': str(e)}, 500

@bp.post("/ai/improve")
@token_required
def ai_improve_content(username=None):
    """Improve existing content using AI"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        content = data.get('content', '')
        section_type = data.get('section_type', 'general')
        
        if not content:
            return {'detail': 'Content is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Get improvement suggestions
        result = ai_service.improve_content(content, section_type)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'improve', section_type, 
                      len(result.get('improved_version', '').split()), response_time_ms))
                conn.commit()
                print(f"📊 AI improve tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return result, 200
        
    except AISafetyError as e:
        return {"detail": str(e), "blocked": True, "reasons": e.reasons}, 400
    except Exception as e:
        print(f"❌ Error improving content: {e}")
        return {
            "detail": "Upstream AI provider error",
            "blocked": False,
        }, 502

@bp.post("/ai/generate-full-proposal")
@token_required
def ai_generate_full_proposal(username=None):
    """Generate a complete multi-section proposal"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        context = data.get('context', {})
        
        if not prompt:
            return {'detail': 'Prompt is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Create enhanced context
        full_context = {
            'user_request': prompt,
            'company': 'Khonology',
            **context
        }
        
        # Generate full proposal
        sections = ai_service.generate_full_proposal(full_context)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        total_tokens = sum(len(str(content).split()) for content in sections.values())
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'full_proposal', prompt[:500], 'full_proposal', 
                      total_tokens, response_time_ms))
                conn.commit()
                print(f"📊 AI full proposal tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return {
            'sections': sections,
            'section_count': len(sections)
        }, 200
        
    except AISafetyError as e:
        return {"detail": str(e), "blocked": True, "reasons": e.reasons}, 400
    except Exception as e:
        print(f"❌ Error generating full proposal: {e}")
        return {'detail': str(e)}, 500

@bp.post("/ai/analyze-risks")
@token_required
def ai_analyze_risks(username=None):
    """Analyze proposal for risks"""
    try:
        data = request.get_json()
        proposal_id = data.get('proposal_id')
        
        if not proposal_id:
            return {'detail': 'Proposal ID is required'}, 400
        
        # Get proposal data
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "SELECT * FROM proposals WHERE id = %s",
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Import AI service
            from ai_service import ai_service
            
            # Analyze risks
            risk_analysis = ai_service.analyze_proposal_risks(dict(proposal))

            kb_recommendations = _kb_recommendations_for_issues(conn, risk_analysis.get("issues") or [])
            risk_analysis["kb_recommendations"] = kb_recommendations
            
            return risk_analysis, 200
        
    except AISafetyError as e:
        return {"detail": str(e), "blocked": True, "reasons": e.reasons}, 400
    except Exception as e:
        print(f"❌ Error analyzing risks: {e}")
        return {'detail': str(e)}, 500

@bp.get("/ai/analytics/summary")
@token_required
def get_ai_analytics_summary(username=None):
    """Get AI usage analytics summary"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Overall stats
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_requests,
                    COUNT(DISTINCT username) as unique_users,
                    AVG(response_time_ms) as avg_response_time,
                    SUM(response_tokens) as total_tokens,
                    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as accepted_count,
                    COUNT(CASE WHEN was_accepted = FALSE THEN 1 END) as rejected_count
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
            """)
            overall_stats = cursor.fetchone()
            
            # By endpoint
            cursor.execute("""
                SELECT 
                    endpoint,
                    COUNT(*) as count,
                    AVG(response_time_ms) as avg_response_time
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY endpoint
                ORDER BY count DESC
            """)
            by_endpoint = cursor.fetchall()
            
            # Daily usage trend
            cursor.execute("""
                SELECT 
                    DATE(created_at) as date,
                    COUNT(*) as requests
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 30
            """)
            daily_trend = cursor.fetchall()
            
            return {
                'overall': dict(overall_stats) if overall_stats else {},
                'by_endpoint': [dict(row) for row in by_endpoint],
                'daily_trend': [dict(row) for row in daily_trend]
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching AI analytics: {e}")
        return {'detail': str(e)}, 500

@bp.get("/ai/analytics/user-stats")
@token_required
def get_user_ai_stats(username=None):
    """Get current user's AI usage statistics"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_requests,
                    COUNT(DISTINCT endpoint) as endpoints_used,
                    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as content_accepted,
                    COUNT(CASE WHEN endpoint = 'full_proposal' THEN 1 END) as full_proposals_generated,
                    AVG(response_time_ms) as avg_response_time,
                    MAX(created_at) as last_used
                FROM ai_usage
                WHERE username = %s
            """, (username,))
            
            stats = cursor.fetchone()
            
            # Recent activity
            cursor.execute("""
                SELECT 
                    endpoint,
                    section_type,
                    response_time_ms,
                    created_at
                FROM ai_usage
                WHERE username = %s
                ORDER BY created_at DESC
                LIMIT 10
            """, (username,))
            
            recent_activity = cursor.fetchall()
            
            return {
                'stats': dict(stats) if stats else {},
                'recent_activity': [dict(row) for row in recent_activity]
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching user AI stats: {e}")
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/<int:proposal_id>/analytics")
@bp.get("/proposals/<int:proposal_id>/analytics")
@token_required
def get_proposal_analytics(username=None, proposal_id=None):
    """Get client activity analytics for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify proposal exists and user has access
            cursor.execute("""
                SELECT id, title, status, client, '' as client_email
                FROM proposals 
                WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            actual_proposal_id = proposal['id']
            
            # Get all activity events
            cursor.execute("""
                SELECT 
                    pca.id, pca.event_type, pca.metadata, pca.created_at,
                    COALESCE(c.contact_person, c.company_name, 'Unknown Client') as client_name, 
                    COALESCE(c.email, '') as client_email
                FROM proposal_client_activity pca
                LEFT JOIN clients c ON pca.client_id = c.id
                WHERE pca.proposal_id = %s
                ORDER BY pca.created_at DESC
            """, (actual_proposal_id,))
            
            events = cursor.fetchall()
            
            # Get all sessions
            cursor.execute("""
                SELECT 
                    pcs.id, pcs.session_start, pcs.session_end, pcs.total_seconds,
                    COALESCE(c.contact_person, c.company_name, 'Unknown Client') as client_name, 
                    COALESCE(c.email, '') as client_email
                FROM proposal_client_session pcs
                LEFT JOIN clients c ON pcs.client_id = c.id
                WHERE pcs.proposal_id = %s
                ORDER BY pcs.session_start DESC
            """, (actual_proposal_id,))
            
            sessions = cursor.fetchall()
            
            # Calculate analytics
            total_time_seconds = sum(s['total_seconds'] or 0 for s in sessions)
            views = len([e for e in events if e['event_type'] == 'open'])
            downloads = len([e for e in events if e['event_type'] == 'download'])
            signs = len([e for e in events if e['event_type'] == 'sign'])
            comments = len([e for e in events if e['event_type'] == 'comment'])
            
            # Get first and last open times
            open_events = [e for e in events if e['event_type'] == 'open']
            first_open = min([e['created_at'] for e in open_events]) if open_events else None
            last_open = max([e['created_at'] for e in open_events]) if open_events else None
            
            # Get section view times from metadata
            section_times = {}
            for event in events:
                if event['event_type'] == 'view_section' and event['metadata']:
                    metadata = event['metadata']
                    if isinstance(metadata, dict):
                        section = metadata.get('section', 'Unknown')
                        duration = metadata.get('duration', 0)
                        if section not in section_times:
                            section_times[section] = 0
                        section_times[section] += duration
            
            # Format events for response
            formatted_events = []
            for event in events:
                formatted_events.append({
                    'id': str(event['id']),
                    'event_type': event['event_type'],
                    'metadata': event['metadata'] if event['metadata'] else {},
                    'created_at': event['created_at'].isoformat() if event['created_at'] else None,
                    'client_name': event.get('client_name'),
                    'client_email': event.get('client_email')
                })
            
            # Format sessions for response
            formatted_sessions = []
            for session in sessions:
                formatted_sessions.append({
                    'id': str(session['id']),
                    'session_start': session['session_start'].isoformat() if session['session_start'] else None,
                    'session_end': session['session_end'].isoformat() if session['session_end'] else None,
                    'total_seconds': session['total_seconds'],
                    'client_name': session.get('client_name'),
                    'client_email': session.get('client_email')
                })
            
            return {
                'proposal_id': str(actual_proposal_id),
                'proposal_title': proposal['title'],
                'analytics': {
                    'total_time_seconds': total_time_seconds,
                    'total_time_formatted': _format_duration(total_time_seconds),
                    'views': views,
                    'downloads': downloads,
                    'signs': signs,
                    'comments': comments,
                    'first_open': first_open.isoformat() if first_open else None,
                    'last_open': last_open.isoformat() if last_open else None,
                    'section_times': section_times,
                    'sessions_count': len(sessions)
                },
                'events': formatted_events,
                'sessions': formatted_sessions
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching proposal analytics: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

def _format_duration(seconds):
    """Helper function to format seconds into human-readable duration"""
    if not seconds:
        return "0s"
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    elif minutes > 0:
        return f"{minutes}m {secs}s"
    else:
        return f"{secs}s"

@bp.post("/ai/feedback")
@token_required
def submit_ai_feedback(username=None):
    """Submit feedback for AI-generated content"""
    try:
        data = request.get_json()
        ai_usage_id = data.get('ai_usage_id')
        rating = data.get('rating')  # 1-5
        feedback_text = data.get('feedback_text', '')
        was_edited = data.get('was_edited', False)
        
        if not ai_usage_id:
            return {'detail': 'AI usage ID is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Update ai_usage was_accepted status
            cursor.execute("""
                UPDATE ai_usage 
                SET was_accepted = TRUE 
                WHERE id = %s
            """, (ai_usage_id,))
            
            # Insert feedback
            cursor.execute("""
                INSERT INTO ai_content_feedback 
                (ai_usage_id, rating, feedback_text, was_edited)
                VALUES (%s, %s, %s, %s)
            """, (ai_usage_id, rating, feedback_text, was_edited))
            
            conn.commit()
            
            return {'message': 'Feedback submitted successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error submitting feedback: {e}")
        return {'detail': str(e)}, 500

# ============================================================================
# COLLABORATION ROUTES
# ============================================================================

@bp.get("/api/proposals/<int:proposal_id>/collaborators")
@bp.get("/proposals/<int:proposal_id>/collaborators")
@token_required
def get_proposal_collaborators(username=None, proposal_id=None):
    """Get all collaborators for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            
            # Handle both tuple and dict results (RealDictCursor returns dict)
            user_id = user_row['id'] if isinstance(user_row, dict) else (user_row[0] if isinstance(user_row, (tuple, list)) else None)
            if not user_id:
                print(f"❌ Could not extract user_id from user_row: {user_row}")
                return {'detail': 'User not found'}, 404
            
            # Verify ownership
            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Handle both dict and tuple results
            owner_id = proposal['owner_id'] if isinstance(proposal, dict) else proposal[0]
            if owner_id != user_id:
                return {'detail': 'Access denied'}, 403
            
            # Get active collaborators from collaborators table
            cursor.execute("""
                SELECT c.id, c.proposal_id, c.email, c.email as invited_email, 
                       c.permission_level, c.status, c.joined_at, c.joined_at as invited_at,
                       c.last_accessed_at, c.last_accessed_at as accessed_at,
                       c.invited_by, u.username as invited_by_username
                FROM collaborators c
                LEFT JOIN users u ON c.invited_by = u.id
                WHERE c.proposal_id = %s
                ORDER BY c.joined_at DESC
            """, (proposal_id,))
            
            collaborators = cursor.fetchall()
            
            # Also get pending invitations
            cursor.execute("""
                SELECT id, proposal_id, invited_email, invited_email as email, 
                       permission_level, status, invited_at, invited_at as joined_at, 
                       accessed_at, accessed_at as last_accessed_at,
                       invited_by, access_token
                FROM collaboration_invitations
                WHERE proposal_id = %s AND status = 'pending'
                ORDER BY invited_at DESC
            """, (proposal_id,))
            
            pending_invitations = cursor.fetchall()
            
            # Combine active collaborators and pending invitations
            # Return both 'email' and 'invited_email' for backward compatibility
            result = [dict(collab) for collab in collaborators]
            result.extend([dict(inv) for inv in pending_invitations])
            
            return result, 200
            
    except Exception as e:
        print(f"❌ Error getting collaborators: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/proposals/<int:proposal_id>/invite")
@bp.post("/proposals/<int:proposal_id>/invite")
@token_required
def invite_collaborator(username=None, proposal_id=None):
    """Invite a collaborator to a proposal"""
    try:
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return {'detail': 'Email is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            # Handle both tuple and dict results
            user_id = user_row[0] if isinstance(user_row, (tuple, list)) else user_row.get('id') if isinstance(user_row, dict) else None
            if not user_id:
                print(f"❌ Could not extract user_id from user_row: {user_row}")
                return {'detail': 'User not found'}, 404
            
            # Verify ownership
            cursor.execute('SELECT owner_id, title FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal['owner_id'] != user_id:
                return {'detail': 'Access denied'}, 403
            
            # Check if invitation already exists
            cursor.execute("""
                SELECT id FROM collaboration_invitations
                WHERE proposal_id = %s AND invited_email = %s
            """, (proposal_id, email))
            existing = cursor.fetchone()
            if existing:
                return {'detail': 'Invitation already sent to this email'}, 400
            
            # Generate access token
            import secrets
            access_token = secrets.token_urlsafe(32)
            
            # Get the user ID from the users table (invited_by is required)
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            invited_by_user_id = user_row['id']
            
            # All collaborators get 'edit' permission (full access: edit, comment, suggest)
            permission_level = 'edit'
            
            # Create invitation
            cursor.execute("""
                INSERT INTO collaboration_invitations 
                (proposal_id, invited_email, invited_by, permission_level, access_token, status)
                VALUES (%s, %s, %s, %s, %s, 'pending')
                RETURNING id, proposal_id, invited_email, permission_level, 
                          status, invited_at, access_token
            """, (proposal_id, email, invited_by_user_id, permission_level, access_token))
            
            invitation = cursor.fetchone()
            conn.commit()
            
            # Send invitation email
            email_sent = False
            email_error = None
            try:
                from api.utils.email import send_email, get_logo_html
                from api.utils.helpers import get_frontend_url
                base_url = get_frontend_url()
                invite_url = f"{base_url}/#/collaborate?token={access_token}"
                print(f"🔗 Collaboration invitation URL: {invite_url}")
                
                email_body = f"""
                {get_logo_html()}
                <h2>You've been invited to collaborate</h2>
                <p>You've been invited to collaborate on the proposal: <strong>{proposal['title']}</strong></p>
                <p>Click the link below to access the proposal:</p>
                <p><a href="{invite_url}" style="background-color: #27AE60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold;">Open Proposal</a></p>
                <p>Or copy and paste this link:</p>
                <p style="word-break: break-all; color: #666;"><a href="{invite_url}" style="color: #0066cc; text-decoration: underline;">{invite_url}</a></p>
                <p>This link will give you full access to edit, comment, and suggest changes.</p>
                """
                
                send_email(
                    to_email=email,
                    subject=f"Collaboration Invitation: {proposal['title']}",
                    html_content=email_body
                )
                email_sent = True
                print(f"✅ Invitation email sent successfully to {email}")
            except Exception as e:
                email_error = str(e)
                print(f"❌ Error sending invitation email to {email}: {email_error}")
                print(f"⚠️ Email service may not be configured. Check SMTP settings.")
                traceback.print_exc()
            
            result = {
                'id': invitation['id'],
                'proposal_id': invitation['proposal_id'],
                'invited_email': invitation['invited_email'],
                'permission_level': invitation['permission_level'],
                'status': invitation['status'],
                'invited_at': invitation['invited_at'].isoformat() if invitation['invited_at'] else None,
                'access_token': invitation['access_token'],
                'email_sent': email_sent
            }
            
            # Include email error message if email failed to send
            if not email_sent and email_error:
                result['email_error'] = email_error
            
            return result, 201
            
    except Exception as e:
        print(f"❌ Error inviting collaborator: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.delete("/api/collaborations/<int:invitation_id>")
@bp.delete("/collaborations/<int:invitation_id>")
@token_required
def remove_collaborator(username=None, invitation_id=None):
    """Remove a collaborator invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation and verify ownership
            cursor.execute("""
                SELECT ci.*, p.owner_id as proposal_owner
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.id = %s
            """, (invitation_id,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invitation not found'}, 404
            
            if invitation['proposal_owner'] != username:
                return {'detail': 'Access denied'}, 403
            
            # Delete invitation
            cursor.execute("""
                DELETE FROM collaboration_invitations WHERE id = %s
            """, (invitation_id,))
            
            conn.commit()
            
            return {'message': 'Collaborator removed successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error removing collaborator: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# PROPOSAL ARCHIVAL ROUTES
# ============================================================================

@bp.patch("/api/proposals/<int:proposal_id>/archive")
@bp.patch("/proposals/<int:proposal_id>/archive")
@token_required
def archive_proposal(username=None, proposal_id=None):
    """Archive a proposal (set status to 'Archived')"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get proposal and verify ownership
            cursor.execute("""
                SELECT id, owner_id, title, status
                FROM proposals
                WHERE id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Get user ID from username for comparison
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            if proposal['owner_id'] != user_id:
                return {'detail': 'Access denied'}, 403
            
            if proposal['status'] == 'Archived':
                return {'detail': 'Proposal is already archived'}, 400
            
            # Get user ID for activity log
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            user_id = user['id'] if user else None
            
            # Archive proposal
            cursor.execute("""
                UPDATE proposals
                SET status = 'Archived', updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id, title, status, updated_at
            """, (proposal_id,))
            
            result = cursor.fetchone()
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user_id,
                    'proposal_archived',
                    f'Archived proposal "{proposal["title"]}"',
                    {'old_status': proposal['status'], 'new_status': 'Archived'}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {
                'message': 'Proposal archived successfully',
                'proposal': dict(result)
            }, 200
            
    except Exception as e:
        print(f"❌ Error archiving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.patch("/api/proposals/<int:proposal_id>/restore")
@bp.patch("/proposals/<int:proposal_id>/restore")
@token_required
def restore_proposal(username=None, proposal_id=None):
    """Restore a proposal from archive (admin only)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user role to check if admin
            cursor.execute('SELECT id, role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            is_admin = user['role'] == 'admin'
            
            # Get proposal
            cursor.execute("""
                SELECT id, owner_id, title, status
                FROM proposals
                WHERE id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Get user ID from username for comparison
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Check permissions (owner or admin)
            if proposal['owner_id'] != user_id and not is_admin:
                return {'detail': 'Access denied. Only owner or admin can restore proposals.'}, 403
            
            if proposal['status'] != 'Archived':
                return {'detail': 'Proposal is not archived'}, 400
            
            # Restore proposal (set to Draft)
            cursor.execute("""
                UPDATE proposals
                SET status = 'Draft', updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id, title, status, updated_at
            """, (proposal_id,))
            
            result = cursor.fetchone()
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user['id'],
                    'proposal_restored',
                    f'Restored proposal "{proposal["title"]}" from archive',
                    {'old_status': 'Archived', 'new_status': 'Draft'}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {
                'message': 'Proposal restored successfully',
                'proposal': dict(result)
            }, 200
            
    except Exception as e:
        print(f"❌ Error restoring proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/archived")
@bp.get("/proposals/archived")
@token_required
def get_archived_proposals(username=None):
    """Get all archived proposals for the user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Check if user is admin (admins can see all archived proposals)
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            is_admin = user and user['role'] == 'admin'
            
            if is_admin:
                # Admin can see all archived proposals
                cursor.execute("""
                    SELECT id, owner_id, title, content, status, client, '' as client_email, 
                           NULL as budget, NULL as timeline_days, created_at, updated_at
                    FROM proposals
                    WHERE status = 'Archived'
                    ORDER BY updated_at DESC
                """)
            else:
                # Get user ID from username
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if not user_row:
                    return {'detail': 'User not found'}, 404
                user_id = user_row[0]
                
                # Regular users see only their archived proposals
                cursor.execute("""
                    SELECT id, owner_id, title, content, status, client, '' as client_email, 
                           NULL as budget, NULL as timeline_days, created_at, updated_at
                    FROM proposals
                    WHERE owner_id = %s AND status = 'Archived'
                    ORDER BY updated_at DESC
                """, (user_id,))
            
            rows = cursor.fetchall()
            proposals = []
            
            for row in rows:
                proposals.append({
                    'id': row['id'],
                    'user_id': row['owner_id'],  # Keep for backward compatibility
                    'owner_id': row['owner_id'],
                    'title': row['title'],
                    'content': row['content'],
                    'status': row['status'] or 'Archived',
                    'client_name': row['client_name'],
                    'client': row['client_name'],
                    'client_email': row['client_email'],
                    'budget': float(row['budget']) if row['budget'] else None,
                    'timeline_days': row['timeline_days'],
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                    'updated_at': row['updated_at'].isoformat() if row['updated_at'] else None,
                    'updatedAt': row['updated_at'].isoformat() if row['updated_at'] else None,
                })
            
            return proposals, 200
            
    except Exception as e:
        print(f"❌ Error getting archived proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

