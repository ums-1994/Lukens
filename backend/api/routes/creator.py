"""
Creator role routes - Content management, proposal CRUD, AI features, uploads
"""
from flask import Blueprint, request, jsonify
import json
import os
import re
import traceback
import cloudinary
import cloudinary.uploader
import psycopg2.extras
from psycopg2.extras import Json, RealDictCursor
from datetime import datetime

from api.utils.database import get_db_connection
from api.utils.decorators import token_required, admin_required
from api.data.default_templates import DEFAULT_TEMPLATES

bp = Blueprint('creator', __name__)

# ============================================================================
# HELPERS
# ============================================================================

def _seed_default_templates(conn):
    """Populate proposal_templates with default records if empty."""
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM proposal_templates')
        count = cursor.fetchone()
        total = count[0] if count else 0
        if total and total > 0:
            return
        for template in DEFAULT_TEMPLATES:
            cursor.execute(
                '''
                INSERT INTO proposal_templates
                (template_key, name, description, template_type, category, status,
                 is_public, is_approved, version, sections, dynamic_fields)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (template_key) DO NOTHING
                ''',
                (
                    template.get('template_key'),
                    template.get('name'),
                    template.get('description'),
                    template.get('template_type', 'proposal'),
                    template.get('category', 'Standard'),
                    template.get('status', 'draft'),
                    template.get('is_public', True),
                    template.get('is_approved', False),
                    template.get('version', 1),
                    Json(template.get('sections', [])),
                    Json(template.get('dynamic_fields', [])),
                ),
            )
        conn.commit()
        print(f"✅ Seeded {len(DEFAULT_TEMPLATES)} default proposal templates")
    except Exception as seed_error:
        print(f"⚠️ Failed to seed default templates: {seed_error}")


def _slugify(value):
    if not value:
        return ''
    value = re.sub(r'[^a-zA-Z0-9]+', '-', value.strip().lower())
    return value.strip('-')


def _parse_sections(value):
    if not value:
        return []
    if isinstance(value, (list, dict)):
        return value
    try:
        return json.loads(value)
    except (ValueError, TypeError):
        return []


def _serialize_template_row(row):
    sections = _parse_sections(row.get('sections'))
    dynamic_fields = _parse_sections(row.get('dynamic_fields'))
    return {
        'id': row.get('id'),
        'template_key': row.get('template_key'),
        'name': row.get('name'),
        'description': row.get('description'),
        'template_type': row.get('template_type', 'proposal'),
        'category': row.get('category'),
        'status': row.get('status'),
        'is_public': row.get('is_public', True),
        'is_approved': row.get('is_approved', False),
        'version': row.get('version', 1),
        'sections': sections,
        'dynamic_fields': dynamic_fields,
        'usage_count': row.get('usage_count', 0),
        'created_by': row.get('created_by'),
        'created_by_username': row.get('created_by_username'),
        'created_at': row.get('created_at').isoformat() if row.get('created_at') else None,
        'updated_at': row.get('updated_at').isoformat() if row.get('updated_at') else None,
    }


def _normalize_selected_modules(selected):
    if not selected:
        return []
    if isinstance(selected, list):
        return [str(item) for item in selected]
    return [str(selected)]


def _normalize_module_contents(contents):
    if not contents:
        return {}
    if isinstance(contents, dict):
        return {str(k): (v or '') for k, v in contents.items()}
    return {}


def _build_sections_payload(template_sections, selected_modules, module_contents):
    payload = []
    selected = set(_normalize_selected_modules(selected_modules))

    for section in template_sections or []:
        key = section.get('key') or section.get('title')
        if not key:
            continue
        include = section.get('required', False) or not selected or key in selected
        if not include:
            continue
        content = module_contents.get(key) or section.get('body') or ''
        payload.append({
            'key': key,
            'title': section.get('title', key.replace('_', ' ').title()),
            'required': section.get('required', False),
            'content': content,
        })

    # Append any ad-hoc sections provided by the user that were not part of the template
    for module_key, module_value in module_contents.items():
        if any(item.get('key') == module_key for item in payload):
            continue
        payload.append({
            'key': module_key,
            'title': module_key.replace('_', ' ').title(),
            'required': False,
            'content': module_value,
        })

    return payload


def _fetch_template_by_id(conn, template_id):
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute(
        '''
        SELECT pt.id, pt.template_key, pt.name, pt.description, pt.template_type, pt.category,
               pt.status, pt.is_public, pt.is_approved, pt.version, pt.sections,
               pt.dynamic_fields, pt.usage_count, pt.created_by, pt.created_at, pt.updated_at,
               u.username AS created_by_username
        FROM proposal_templates pt
        LEFT JOIN users u ON pt.created_by = u.id
        WHERE pt.id = %s
        ''',
        (template_id,)
    )
    return cursor.fetchone()


def _load_proposal_payload(cursor, proposal_id):
    cursor.execute(
        '''SELECT id, owner_id, title, content, sections, status, client_name, client_email,
                  budget, timeline_days, template_key
           FROM proposals WHERE id = %s''',
        (proposal_id,)
    )
    row = cursor.fetchone()
    if not row:
        return None
    return {
        'id': row[0],
        'owner_id': row[1],
        'title': row[2],
        'content': row[3],
        'sections': _parse_sections(row[4]),
        'status': row[5],
        'client_name': row[6],
        'client_email': row[7],
        'budget': row[8],
        'timeline_days': row[9],
        'template_key': row[10],
    }


def _basic_governance_check(proposal_payload):
    issues = []
    risk_score = 0
    sections = proposal_payload.get('sections') or []
    section_lookup = {}
    for section in sections:
        key = section.get('key') or section.get('title')
        section_lookup[key] = section.get('content', '')

    required_sections = ['executive_summary', 'scope_deliverables', 'company_profile', 'terms_conditions']
    for required in required_sections:
        if not section_lookup.get(required):
            issues.append({
                'category': 'missing_section',
                'section': required,
                'severity': 'high',
                'description': f'{required.replace("_", " ").title()} is required',
                'recommendation': 'Add content using the template library'
            })
            risk_score += 10

    if not proposal_payload.get('client_name'):
        issues.append({
            'category': 'metadata',
            'section': 'client_name',
            'severity': 'medium',
            'description': 'Client name is missing',
            'recommendation': 'Provide client information in Compose step'
        })
        risk_score += 5

    readiness_score = max(0, 100 - risk_score)
    return {
        'status': 'PASSED' if risk_score == 0 else 'FAILED',
        'score': readiness_score,
        'issues': issues,
        'risk_score': risk_score,
        'can_release': risk_score == 0,
        'required_actions': [issue['description'] for issue in issues]
    }


def _governance_from_analysis(analysis):
    issues = analysis.get('issues', [])
    risk_score = int(analysis.get('risk_score', 0) or 0)
    readiness_score = max(0, 100 - risk_score)
    return {
        'status': 'PASSED' if analysis.get('can_release') else 'FAILED',
        'score': readiness_score,
        'issues': issues,
        'risk_score': risk_score,
        'can_release': analysis.get('can_release', False),
        'required_actions': analysis.get('required_actions') or [],
        'summary': analysis.get('summary')
    }


def _persist_governance(conn, proposal_id, governance_payload):
    cursor = conn.cursor()
    cursor.execute(
        '''
        INSERT INTO proposal_governance
        (proposal_id, readiness_score, status, issues, risk_score, can_release, analysis, last_checked)
        VALUES (%s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
        ON CONFLICT (proposal_id) DO UPDATE SET
            readiness_score = EXCLUDED.readiness_score,
            status = EXCLUDED.status,
            issues = EXCLUDED.issues,
            risk_score = EXCLUDED.risk_score,
            can_release = EXCLUDED.can_release,
            analysis = EXCLUDED.analysis,
            last_checked = CURRENT_TIMESTAMP
        ''',
        (
            proposal_id,
            governance_payload.get('score', 0),
            governance_payload.get('status', 'pending'),
            Json(governance_payload.get('issues', [])),
            governance_payload.get('risk_score'),
            governance_payload.get('can_release', False),
            Json(governance_payload),
        )
    )
    conn.commit()


def _persist_readiness_checks(conn, proposal_id, governance_payload):
    """Persist detailed readiness checks for a proposal based on governance issues."""
    cursor = conn.cursor()

    # Clear existing checks for this proposal to avoid stale rows
    cursor.execute('DELETE FROM readiness_checks WHERE proposal_id = %s', (proposal_id,))

    issues = governance_payload.get('issues') or []

    if not issues:
        # Optionally record a single overall check so UI still has something to show
        overall_status = 'passed' if governance_payload.get('can_release') else 'failed'
        overall_message = (
            'All mandatory checks passed'
            if governance_payload.get('can_release')
            else 'Manual review or additional work is required before release'
        )
        cursor.execute(
            '''INSERT INTO readiness_checks
               (proposal_id, check_key, check_name, category, status, severity, message)
               VALUES (%s, %s, %s, %s, %s, %s, %s)''',
            (
                proposal_id,
                'overall',
                'Overall readiness',
                'overall',
                overall_status,
                'low',
                overall_message,
            ),
        )
    else:
        for idx, issue in enumerate(issues):
            section_key = issue.get('section') or issue.get('category') or f'issue_{idx + 1}'
            check_key = _slugify(str(section_key)) or f'issue_{idx + 1}'
            check_name = issue.get('description') or 'Readiness issue'
            category = issue.get('category') or 'general'
            status = 'failed'
            severity = issue.get('severity') or 'medium'
            message = issue.get('recommendation') or issue.get('description') or ''

            cursor.execute(
                '''INSERT INTO readiness_checks
                   (proposal_id, check_key, check_name, category, status, severity, message)
                   VALUES (%s, %s, %s, %s, %s, %s, %s)''',
                (
                    proposal_id,
                    check_key,
                    check_name,
                    category,
                    status,
                    severity,
                    message,
                ),
            )

    conn.commit()


# ============================================================================
# CONTENT LIBRARY ROUTES
# ============================================================================

@bp.get("/content")
@token_required
def get_content(username=None):
    """Get all content items"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                           FROM content WHERE is_deleted = false ORDER BY created_at DESC''')
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
            return {'content': content}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/content")
@token_required
def create_content(username=None):
    """Create a new content item"""
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
# TEMPLATE LIBRARY ROUTES
# ============================================================================

@bp.get("/templates")
@token_required
def list_templates(username=None):
    """Return all proposal templates."""
    try:
        with get_db_connection() as conn:
            _seed_default_templates(conn)
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT pt.id, pt.template_key, pt.name, pt.description, pt.template_type, pt.category,
                       pt.status, pt.is_public, pt.is_approved, pt.version, pt.sections,
                       pt.dynamic_fields, pt.usage_count, pt.created_by, pt.created_at, pt.updated_at,
                       u.username AS created_by_username
                FROM proposal_templates pt
                LEFT JOIN users u ON pt.created_by = u.id
                ORDER BY pt.name
            ''')
            rows = cursor.fetchall()
            templates = [_serialize_template_row(row) for row in rows]
            return {'templates': templates}, 200
    except Exception as e:
        print(f"❌ Error fetching templates: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/templates/<int:template_id>")
@token_required
def get_template(username=None, template_id=None):
    """Return a single template."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute(
                '''
                SELECT pt.id, pt.template_key, pt.name, pt.description, pt.template_type, pt.category,
                       pt.status, pt.is_public, pt.is_approved, pt.version, pt.sections,
                       pt.dynamic_fields, pt.usage_count, pt.created_by, pt.created_at, pt.updated_at,
                       u.username AS created_by_username
                FROM proposal_templates pt
                LEFT JOIN users u ON pt.created_by = u.id
                WHERE pt.id = %s OR pt.template_key = %s
                ''',
                (template_id, str(template_id)),
            )
            row = cursor.fetchone()
            if not row:
                return {'detail': 'Template not found'}, 404
            return _serialize_template_row(row), 200
    except Exception as e:
        print(f"❌ Error fetching template {template_id}: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/templates")
@token_required
@admin_required
def create_template(username=None):
    """Create a new proposal template (admin only)."""
    try:
        data = request.get_json() or {}
        name = (data.get('name') or '').strip()
        if not name:
            return {'detail': 'Template name is required'}, 400
        sections = data.get('sections') or []
        if not isinstance(sections, list) or not sections:
            return {'detail': 'At least one section is required'}, 400

        template_type = data.get('template_type') or data.get('templateType') or 'proposal'
        template_key = data.get('template_key') or data.get('templateKey') or _slugify(name)
        if not template_key:
            return {'detail': 'Template key could not be generated'}, 400

        dynamic_fields = data.get('dynamic_fields') or data.get('dynamicFields') or []
        category = data.get('category') or 'Standard'
        status = data.get('status') or 'draft'
        is_public = bool(data.get('is_public', False))
        is_approved = bool(data.get('is_approved', status.lower() == 'approved'))
        version = data.get('version') or 1

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            creator_id = user_row['id']

            cursor.execute(
                '''SELECT 1 FROM proposal_templates WHERE template_key = %s''',
                (template_key,)
            )
            if cursor.fetchone():
                return {'detail': 'Template key already exists'}, 400

            cursor.execute(
                '''
                INSERT INTO proposal_templates
                (template_key, name, description, template_type, category, status,
                 is_public, is_approved, version, sections, dynamic_fields, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, template_key, name, description, template_type, category,
                          status, is_public, is_approved, version, sections,
                          dynamic_fields, usage_count, created_by, created_at, updated_at
                ''',
                (
                    template_key,
                    name,
                    data.get('description'),
                    template_type,
                    category,
                    status,
                    is_public,
                    is_approved,
                    version,
                    Json(sections),
                    Json(dynamic_fields),
                    creator_id
                )
            )
            result = cursor.fetchone()
            conn.commit()
            result['created_by_username'] = username
            return _serialize_template_row(result), 201
    except Exception as e:
        print(f"❌ Error creating template: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.put("/templates/<int:template_id>")
@token_required
@admin_required
def update_template(username=None, template_id=None):
    """Update an existing template."""
    try:
        data = request.get_json() or {}
        if not data:
            return {'detail': 'No updates provided'}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            updates = []
            params = []

            if 'name' in data:
                updates.append('name = %s')
                params.append(data['name'])
            if 'description' in data:
                updates.append('description = %s')
                params.append(data['description'])
            if 'template_type' in data or 'templateType' in data:
                updates.append('template_type = %s')
                params.append(data.get('template_type') or data.get('templateType'))
            if 'category' in data:
                updates.append('category = %s')
                params.append(data['category'])
            if 'status' in data:
                updates.append('status = %s')
                params.append(data['status'])
            if 'is_public' in data:
                updates.append('is_public = %s')
                params.append(data['is_public'])
            if 'is_approved' in data:
                updates.append('is_approved = %s')
                params.append(data['is_approved'])
            if 'version' in data:
                updates.append('version = %s')
                params.append(data['version'])
            if 'sections' in data:
                updates.append('sections = %s')
                params.append(Json(data['sections']))
            if 'dynamic_fields' in data or 'dynamicFields' in data:
                updates.append('dynamic_fields = %s')
                params.append(Json(data.get('dynamic_fields') or data.get('dynamicFields')))
            if 'template_key' in data or 'templateKey' in data:
                updates.append('template_key = %s')
                params.append(data.get('template_key') or data.get('templateKey'))

            if not updates:
                return {'detail': 'No updates provided'}, 400

            updates.append('updated_at = CURRENT_TIMESTAMP')
            params.append(template_id)

            cursor.execute(
                f'''UPDATE proposal_templates SET {', '.join(updates)} WHERE id = %s''',
                params
            )
            conn.commit()

            template_row = _fetch_template_by_id(conn, template_id)
            if not template_row:
                return {'detail': 'Template not found'}, 404
            return _serialize_template_row(template_row), 200
    except Exception as e:
        print(f"❌ Error updating template {template_id}: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.delete("/templates/<int:template_id>")
@token_required
@admin_required
def delete_template(username=None, template_id=None):
    """Delete a template."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM proposal_templates WHERE id = %s', (template_id,))
            if cursor.rowcount == 0:
                return {'detail': 'Template not found'}, 404
            conn.commit()
            return {'detail': 'Template deleted'}, 200
    except Exception as e:
        print(f"❌ Error deleting template {template_id}: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/templates/<int:template_id>/approve")
@token_required
@admin_required
def approve_template(username=None, template_id=None):
    """Approve and publish a template."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''
                UPDATE proposal_templates
                SET status = 'approved', is_approved = TRUE, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                ''',
                (template_id,)
            )
            if cursor.rowcount == 0:
                return {'detail': 'Template not found'}, 404
            conn.commit()

            template_row = _fetch_template_by_id(conn, template_id)
            return _serialize_template_row(template_row), 200
    except Exception as e:
        print(f"❌ Error approving template {template_id}: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500



# ============================================================================
# PROPOSAL ROUTES (CREATOR)
# ============================================================================

@bp.get("/proposals")
@token_required
def get_proposals(username=None):
    """Get all proposals for the creator"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            print(f"🔍 Looking for proposals for user {username}")

            # Resolve numeric owner_id from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]
            
            list_cursor = conn.cursor(cursor_factory=RealDictCursor)
            list_cursor.execute(
                '''SELECT p.id, p.owner_id, p.title, p.content, p.sections, p.status,
                          p.client_name, p.client_email, p.budget, p.timeline_days,
                          p.created_at, p.updated_at, p.template_key,
                          g.status AS governance_status, g.readiness_score, g.risk_score, g.can_release
                   FROM proposals p
                   LEFT JOIN proposal_governance g ON g.proposal_id = p.id
                   WHERE p.owner_id = %s
                   ORDER BY p.created_at DESC''',
                (owner_id,)
            )
            rows = list_cursor.fetchall()
            proposals = []
            for row in rows:
                # Handle NULL status - default to 'draft' (lowercase to match constraint)
                status = row.get('status') if row.get('status') is not None else 'draft'
                proposals.append({
                    'id': row.get('id'),
                    'user_id': row.get('owner_id'),
                    'owner_id': row.get('owner_id'),  # For compatibility
                    'title': row.get('title'),
                    'content': row.get('content'),
                    'sections': _parse_sections(row.get('sections')),
                    'status': status,
                    'client_name': row.get('client_name'),
                    'client': row.get('client_name'),  # For compatibility
                    'client_email': row.get('client_email'),
                    'budget': float(row.get('budget')) if row.get('budget') else None,
                    'timeline_days': row.get('timeline_days'),
                    'created_at': row.get('created_at').isoformat() if row.get('created_at') else None,
                    'updated_at': row.get('updated_at').isoformat() if row.get('updated_at') else None,
                    'updatedAt': row.get('updated_at').isoformat() if row.get('updated_at') else None,
                    'template_key': row.get('template_key'),
                    'governance_status': row.get('governance_status') or 'pending',
                    'readiness_score': row.get('readiness_score'),
                    'risk_score': row.get('risk_score'),
                    'can_release': row.get('can_release'),
                })
            print(f"✅ Found {len(proposals)} proposals for user {username}")
            return proposals, 200
    except Exception as e:
        print(f"❌ Error getting proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/proposals/wizard")
@bp.post("/proposals/wizard")
@token_required
def build_proposal_wizard(username=None):
    try:
        data = request.get_json() or {}
        with get_db_connection() as conn:
            cursor = conn.cursor()

            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
            client_email = data.get('client_email') or ''

            template_id = data.get('template_id') or data.get('templateId')
            template_key_value = data.get('template_key') or data.get('templateKey')
            selected_modules = data.get('selected_modules') or data.get('selectedModules') or []
            module_contents = _normalize_module_contents(
                data.get('module_contents') or data.get('moduleContents')
            )

            template_sections = []
            if template_id:
                cursor.execute(
                    '''SELECT sections, template_key FROM proposal_templates WHERE id = %s''',
                    (template_id,)
                )
                template_row = cursor.fetchone()
                if template_row:
                    tpl_sections = template_row[0]
                    tpl_key = template_row[1]
                    template_sections = tpl_sections if isinstance(tpl_sections, list) else _parse_sections(tpl_sections)
                    if tpl_key and not template_key_value:
                        template_key_value = tpl_key
            elif template_key_value:
                cursor.execute(
                    '''SELECT sections FROM proposal_templates WHERE template_key = %s''',
                    (template_key_value,)
                )
                template_row = cursor.fetchone()
                if template_row:
                    tpl_sections = template_row[0]
                    template_sections = tpl_sections if isinstance(tpl_sections, list) else _parse_sections(tpl_sections)

            sections_payload = _build_sections_payload(template_sections, selected_modules, module_contents)

            basic_info_lines = []
            if client_name:
                basic_info_lines.append(f"Client: {client_name}")
            opportunity_name = data.get('opportunity_name') or data.get('opportunityName')
            if opportunity_name:
                basic_info_lines.append(f"Opportunity: {opportunity_name}")
            project_type = data.get('project_type') or data.get('projectType')
            if project_type:
                basic_info_lines.append(f"Project Type: {project_type}")
            timeline_label = data.get('timeline') or data.get('timelineLabel')
            if timeline_label:
                basic_info_lines.append(f"Timeline: {timeline_label}")
            estimated_value_input = data.get('estimated_value') or data.get('estimatedValue')
            if estimated_value_input:
                basic_info_lines.append(f"Estimated Value: {estimated_value_input}")
            if basic_info_lines:
                sections_payload.insert(0, {
                    'key': 'basic_information',
                    'title': 'Basic Information',
                    'required': True,
                    'content': '\n'.join(basic_info_lines),
                })

            budget_value = data.get('budget')
            if not budget_value and estimated_value_input:
                cleaned = re.sub(r'[^0-9.\-]', '', str(estimated_value_input))
                try:
                    budget_value = float(cleaned)
                except ValueError:
                    budget_value = None

            timeline_days = data.get('timeline_days') or data.get('timelineDays')
            if not timeline_days and timeline_label:
                numbers = re.findall(r'\d+', str(timeline_label))
                if numbers:
                    try:
                        timeline_days = int(numbers[0])
                    except ValueError:
                        timeline_days = None

            response = {
                'title': data.get('title', 'Untitled Document'),
                'client_name': client_name,
                'client_email': client_email,
                'sections': sections_payload,
                'budget': budget_value,
                'timeline_days': timeline_days,
                'template_key': template_key_value,
            }
            return response, 200
    except Exception as e:
        print(f"❌ Error building wizard proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals")
@token_required
def create_proposal(username=None):
    """Create a new proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating proposal for user {username}: {data.get('title', 'Untitled')}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Resolve numeric owner_id from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]

            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
            client_email = data.get('client_email') or ''
            # Legacy "client" column is still NOT NULL in many databases, so keep it in sync
            client_value = client_name
            template_id = data.get('template_id') or data.get('templateId')
            template_key_value = data.get('template_key') or data.get('templateKey')
            selected_modules = data.get('selected_modules') or data.get('selectedModules') or []
            module_contents = _normalize_module_contents(
                data.get('module_contents') or data.get('moduleContents')
            )
            template_sections = []
            if template_id:
                cursor.execute(
                    '''SELECT sections, template_key FROM proposal_templates WHERE id = %s''',
                    (template_id,)
                )
                template_row = cursor.fetchone()
                if template_row:
                    tpl_sections = template_row[0]
                    tpl_key = template_row[1]
                    template_sections = tpl_sections if isinstance(tpl_sections, list) else _parse_sections(tpl_sections)
                    if tpl_key and not template_key_value:
                        template_key_value = tpl_key
            elif template_key_value:
                cursor.execute(
                    '''SELECT sections FROM proposal_templates WHERE template_key = %s''',
                    (template_key_value,)
                )
                template_row = cursor.fetchone()
                if template_row:
                    tpl_sections = template_row[0]
                    template_sections = tpl_sections if isinstance(tpl_sections, list) else _parse_sections(tpl_sections)
            sections_payload = _build_sections_payload(template_sections, selected_modules, module_contents)

            basic_info_lines = []
            if client_name:
                basic_info_lines.append(f"Client: {client_name}")
            opportunity_name = data.get('opportunity_name') or data.get('opportunityName')
            if opportunity_name:
                basic_info_lines.append(f"Opportunity: {opportunity_name}")
            project_type = data.get('project_type') or data.get('projectType')
            if project_type:
                basic_info_lines.append(f"Project Type: {project_type}")
            timeline_label = data.get('timeline') or data.get('timelineLabel')
            if timeline_label:
                basic_info_lines.append(f"Timeline: {timeline_label}")
            estimated_value_input = data.get('estimated_value') or data.get('estimatedValue')
            if estimated_value_input:
                basic_info_lines.append(f"Estimated Value: {estimated_value_input}")
            if basic_info_lines:
                sections_payload.insert(0, {
                    'key': 'basic_information',
                    'title': 'Basic Information',
                    'required': True,
                    'content': '\n'.join(basic_info_lines)
                })
            sections_json = json.dumps(sections_payload) if sections_payload else None

            budget_value = data.get('budget')
            if not budget_value and estimated_value_input:
                cleaned = re.sub(r'[^0-9.\-]', '', str(estimated_value_input))
                try:
                    budget_value = float(cleaned)
                except ValueError:
                    budget_value = None

            timeline_days = data.get('timeline_days') or data.get('timelineDays')
            if not timeline_days and timeline_label:
                numbers = re.findall(r'\d+', str(timeline_label))
                if numbers:
                    try:
                        timeline_days = int(numbers[0])
                    except ValueError:
                        timeline_days = None
            
            # Normalize status - use lowercase to match database constraint
            raw_status = data.get('status', 'draft')
            normalized_status = 'draft'  # Default - lowercase to match constraint
            if raw_status:
                status_lower = str(raw_status).lower().strip()
                if status_lower == 'draft':
                    normalized_status = 'draft'
                elif 'pending' in status_lower and 'ceo' in status_lower:
                    normalized_status = 'Pending CEO Approval'
                elif 'sent' in status_lower and 'client' in status_lower:
                    normalized_status = 'Sent to Client'
                elif status_lower in ['signed', 'approved']:
                    normalized_status = 'signed'
                elif 'review' in status_lower:
                    normalized_status = 'In Review'
                else:
                    # Keep as lowercase for basic statuses, or use exact value if it's a special status
                    normalized_status = status_lower

            cursor.execute(
                '''INSERT INTO proposals (owner_id, title, client, content, sections, status, client_name, client_email, budget, timeline_days, template_key)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) 
                   RETURNING id, owner_id, title, content, sections, status, client_name, client_email, budget, timeline_days, created_at, updated_at''',
                (
                    owner_id,
                    data.get('title', 'Untitled Document'),
                    client_value,
                    data.get('content'),
                    sections_json,
                    normalized_status,
                    client_name,
                    client_email,
                    budget_value,
                    timeline_days,
                    template_key_value,
                ),
            )
            result = cursor.fetchone()
            conn.commit()
            
            sections_response = _parse_sections(result[4]) if len(result) > 4 else []
            proposal = {
                'id': result[0],
                'user_id': result[1],
                'owner_id': result[1],
                'title': result[2],
                'content': result[3],
                'sections': sections_response,
                'status': result[5],
                'client_name': result[6],
                'client': result[6],
                'client_email': result[7],
                'budget': float(result[8]) if result[8] else None,
                'timeline_days': result[9],
                'created_at': result[10].isoformat() if result[10] else None,
                'updated_at': result[11].isoformat() if result[11] else None,
                'template_key': template_key_value,
            }
            
            print(f"✅ Proposal created: {proposal['id']}")
            return proposal, 201
    except Exception as e:
        print(f"❌ Error creating proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.put("/proposals/<proposal_id>")
@token_required
def update_proposal(username=None, proposal_id=None):
    """Update a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Updating proposal {proposal_id} for user {username}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verify ownership
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]

            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            if proposal[0] != owner_id:
                return {'detail': 'Access denied'}, 403
            
            # Build update query
            updates = []
            params = []
            
            if 'title' in data:
                updates.append('title = %s')
                params.append(data['title'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            if 'sections' in data:
                sections_value = data.get('sections')
                if isinstance(sections_value, (list, dict)):
                    updates.append('sections = %s')
                    params.append(json.dumps(sections_value))
                elif sections_value is None:
                    updates.append('sections = %s')
                    params.append(None)
                else:
                    updates.append('sections = %s')
                    params.append(sections_value)
            if 'status' in data:
                updates.append('status = %s')
                params.append(data['status'])
            if 'client_name' in data or 'client' in data:
                client_name = data.get('client_name')
                legacy_client = data.get('client')
                unified_client = client_name or legacy_client
                if unified_client is not None and str(unified_client).strip() != '':
                    updates.append('client_name = %s')
                    params.append(unified_client)
                    # Keep legacy client column in sync
                    updates.append('client = %s')
                    params.append(unified_client)
            if 'client_email' in data:
                updates.append('client_email = %s')
                params.append(data['client_email'])
            if 'budget' in data:
                updates.append('budget = %s')
                params.append(data['budget'])
            if 'timeline_days' in data:
                updates.append('timeline_days = %s')
                params.append(data['timeline_days'])
            if 'template_key' in data:
                updates.append('template_key = %s')
                params.append(data['template_key'])
            
            if not updates:
                return {'detail': 'No updates provided'}, 400
            
            updates.append('updated_at = CURRENT_TIMESTAMP')
            params.append(proposal_id)
            
            cursor.execute(
                f'''UPDATE proposals SET {', '.join(updates)} WHERE id = %s
                   RETURNING id, owner_id, title, content, sections, status, client_name, client_email, budget, timeline_days, created_at, updated_at''',
                params
            )
            result = cursor.fetchone()
            conn.commit()
            
            proposal = {
                'id': result[0],
                'user_id': result[1],
                'owner_id': result[1],
                'title': result[2],
                'content': result[3],
                'sections': _parse_sections(result[4]),
                'status': result[5],
                'client_name': result[6],
                'client': result[6],
                'client_email': result[7],
                'budget': float(result[8]) if result[8] else None,
                'timeline_days': result[9],
                'created_at': result[10].isoformat() if result[10] else None,
                'updated_at': result[11].isoformat() if result[11] else None,
            }
            
            print(f"✅ Proposal updated: {proposal_id}")
            return proposal, 200
    except Exception as e:
        print(f"❌ Error updating proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.delete("/proposals/<proposal_id>")
@token_required
def delete_proposal(username=None, proposal_id=None):
    """Delete a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verify ownership
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]

            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            if proposal[0] != owner_id:
                return {'detail': 'Access denied'}, 403
            
            cursor.execute('DELETE FROM proposals WHERE id = %s', (proposal_id,))
            conn.commit()
            return {'detail': 'Proposal deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/proposals/<proposal_id>")
@token_required
def get_proposal(username=None, proposal_id=None):
    """Get a single proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, owner_id, title, content, sections, status, client_name, client_email, 
                          budget, timeline_days, created_at, updated_at, template_key
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            result = cursor.fetchone()
            if result:
                cursor.execute(
                    '''SELECT status, readiness_score, risk_score, can_release, issues, last_checked
                       FROM proposal_governance WHERE proposal_id = %s''',
                    (proposal_id,)
                )
                governance_row = cursor.fetchone()
                return {
                    'id': result[0],
                    'user_id': result[1],
                    'owner_id': result[1],
                    'title': result[2],
                    'content': result[3],
                    'sections': _parse_sections(result[4]),
                    'status': result[5],
                    'client_name': result[6],
                    'client': result[6],
                    'client_email': result[7],
                    'budget': float(result[8]) if result[8] else None,
                    'timeline_days': result[9],
                    'created_at': result[10].isoformat() if result[10] else None,
                    'updated_at': result[11].isoformat() if result[11] else None,
                    'template_key': result[12],
                    'governance': {
                        'status': governance_row[0] if governance_row else None,
                        'readiness_score': governance_row[1] if governance_row else None,
                        'risk_score': governance_row[2] if governance_row else None,
                        'can_release': governance_row[3] if governance_row else None,
                        'issues': _parse_sections(governance_row[4]) if governance_row and len(governance_row) > 4 else [],
                        'last_checked': governance_row[5].isoformat() if governance_row and governance_row[5] else None,
                    } if governance_row else None,
                }, 200
            return {'detail': 'Proposal not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

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

@bp.post("/proposals/<proposal_id>/submit")
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

@bp.post("/proposals/<proposal_id>/send-for-approval")
@bp.post("/api/proposals/<proposal_id>/send-for-approval")
@token_required
def send_for_approval(username=None, proposal_id=None):
    """Send proposal for approval"""
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

@bp.post("/proposals/<proposal_id>/send_to_client")
@token_required
def send_to_client(username=None, proposal_id=None):
    """Send proposal to client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute(
                """
                SELECT id, title, client_name, client_email, owner_id
                FROM proposals
                WHERE id = %s
                """,
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            cursor.execute(
                "SELECT id, full_name, username, email FROM users WHERE username = %s",
                (username,),
            )
            sender = cursor.fetchone()
            
            if not sender:
                return {'detail': 'User not found'}, 404

            # Compound risk gate: block sending to client if governance says cannot release
            gov_cursor = conn.cursor()
            gov_cursor.execute(
                '''SELECT status, readiness_score, risk_score, can_release, issues, last_checked
                   FROM proposal_governance WHERE proposal_id = %s''',
                (proposal_id,),
            )
            gov_row = gov_cursor.fetchone()
            governance = None
            if gov_row:
                governance = {
                    'status': gov_row[0],
                    'readiness_score': gov_row[1],
                    'risk_score': gov_row[2],
                    'can_release': gov_row[3],
                    'issues': _parse_sections(gov_row[4]) if len(gov_row) > 4 else [],
                    'last_checked': gov_row[5].isoformat() if len(gov_row) > 5 and gov_row[5] else None,
                }
            else:
                payload_cursor = conn.cursor()
                payload = _load_proposal_payload(payload_cursor, proposal_id)
                if payload:
                    governance = _basic_governance_check(payload)
                    _persist_governance(conn, proposal_id, governance)
                    _persist_readiness_checks(conn, proposal_id, governance)

            if governance and not governance.get('can_release', False):
                return {
                    'detail': 'Compound risk gate blocked sending proposal to client',
                    'risk_score': governance.get('risk_score'),
                    'issues': governance.get('issues', []),
                    'required_actions': governance.get('required_actions', []),
                }, 400

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
                    
                    frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                    access_token = secrets.token_urlsafe(32)
                    
                    # Store token in collaboration_invitations for client access
                    sender_id = sender.get('id')
                    cursor.execute("""
                        INSERT INTO collaboration_invitations 
                        (proposal_id, invited_email, invited_by, permission_level, access_token, status)
                        VALUES (%s, %s, %s, %s, %s, 'pending')
                        ON CONFLICT DO NOTHING
                    """, (proposal_id, client_email, sender_id, 'view', access_token))
                    conn.commit()
                    
                    client_link = f"{frontend_url}/client/proposals?token={access_token}"
                    
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
                    <p style="word-break: break-all; color: #666;">{client_link}</p>
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
@token_required
def upload_image(username=None):
    """Upload an image to Cloudinary"""
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        return result, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/upload/template")
@token_required
def upload_template(username=None):
    """Upload a template to Cloudinary"""
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        return result, 200
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

@bp.post("/api/proposals/<proposal_id>/versions")
@token_required
def create_version(username=None, proposal_id=None):
    """Create a new version of a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating version {data.get('version_number')} for proposal {proposal_id}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            user_id = user_row[0] if user_row else None
            
            cursor.execute(
                '''INSERT INTO proposal_versions 
                   (proposal_id, version_number, content, created_by, change_description)
                   VALUES (%s, %s, %s, %s, %s)
                   RETURNING id, proposal_id, version_number, content, created_by, created_at, change_description''',
                (
                    proposal_id,
                    data.get('version_number', 1),
                    data.get('content', ''),
                    user_id,
                    data.get('change_description', 'Version created')
                )
            )
            result = cursor.fetchone()
            conn.commit()
            
            version = {
                'id': result[0],
                'proposal_id': result[1],
                'version_number': result[2],
                'content': result[3],
                'created_by': result[4],
                'created_at': result[5].isoformat() if result[5] else None,
                'change_description': result[6]
            }
            
            print(f"✅ Version {result[2]} created for proposal {proposal_id}")
            return version, 201
    except Exception as e:
        print(f"❌ Error creating version: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/<proposal_id>/versions")
@token_required
def get_versions(username=None, proposal_id=None):
    """Get all versions of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at, change_description
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
                    'created_at': row[5].isoformat() if row[5] else None,
                    'change_description': row[6]
                })
            
            print(f"✅ Found {len(versions)} versions for proposal {proposal_id}")
            return versions, 200
    except Exception as e:
        print(f"❌ Error getting versions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/<proposal_id>/versions/<int:version_number>")
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
    """Report whether AI features are configured."""
    ai_enabled = bool(os.getenv("OPENROUTER_API_KEY"))
    model = os.getenv("OPENROUTER_MODEL", "anthropic/claude-3.5-sonnet")
    return {
        'ai_enabled': ai_enabled,
        'model': model,
        'provider': 'OpenRouter' if ai_enabled else None
    }, 200


@bp.post("/ai/generate-section")
@token_required
def ai_generate_section(username=None):
    """Alias for AI section generation to match frontend service."""
    data = request.get_json() or {}
    section_type = data.get('section_type', 'general')
    context = data.get('context', {})
    from ai_service import ai_service
    generated_content = ai_service.generate_proposal_section(section_type, context)
    return {'generated_content': generated_content, 'section_type': section_type}, 200


@bp.post("/ai/improve-content")
@token_required
def ai_improve_section(username=None):
    """Alias for AI improve endpoint with consistent response."""
    data = request.get_json() or {}
    content = data.get('content', '')
    section_type = data.get('section_type', 'general')
    if not content:
        return {'detail': 'Content is required'}, 400
    from ai_service import ai_service
    improvements = ai_service.improve_content(content, section_type)
    return {'improvements': improvements}, 200


@bp.post("/ai/check-compliance")
@token_required
def ai_check_compliance(username=None):
    """Run compliance check for a proposal."""
    data = request.get_json() or {}
    proposal_id = data.get('proposal_id')
    proposal_payload = data.get('proposal')
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            if proposal_id and not proposal_payload:
                payload = _load_proposal_payload(cursor, proposal_id)
                if not payload:
                    return {'detail': 'Proposal not found'}, 404
                proposal_payload = payload
        if not proposal_payload:
            return {'detail': 'Proposal payload is required'}, 400
        from ai_service import ai_service
        compliance = ai_service.check_compliance(proposal_payload)
        return {'compliance': compliance}, 200
    except Exception as e:
        print(f"❌ Error running compliance check: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/proposals/ai-analysis")
@token_required
def ai_analyze_proposal(username=None):
    """Run full AI readiness + risk analysis for a proposal or ad-hoc payload."""
    data = request.get_json() or {}
    proposal_id = data.get('proposal_id')
    proposal_payload = data.get('proposal') or data.get('payload')
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            if proposal_id and not proposal_payload:
                payload = _load_proposal_payload(cursor, proposal_id)
                if not payload:
                    return {'detail': 'Proposal not found'}, 404
                proposal_payload = payload

            if not proposal_payload:
                return {'detail': 'Proposal data is required'}, 400

            try:
                from ai_service import ai_service
                analysis = ai_service.analyze_proposal_risks(proposal_payload)
                governance = _governance_from_analysis(analysis)
            except Exception as ai_error:
                print(f"⚠️ AI analysis failed, using fallback: {ai_error}")
                governance = _basic_governance_check(proposal_payload)
                analysis = {
                    'overall_risk_level': 'medium',
                    'can_release': governance.get('can_release'),
                    'risk_score': governance.get('risk_score', 50),
                    'issues': governance.get('issues', []),
                    'summary': 'AI service unavailable, fallback applied',
                    'required_actions': governance.get('required_actions', []),
                }

            if proposal_id:
                _persist_governance(conn, proposal_id, governance)
                _persist_readiness_checks(conn, proposal_id, governance)

            response = {
                'analysis': {
                    'risk_score': analysis.get('risk_score'),
                    'risk_level': analysis.get('overall_risk_level'),
                    'issues': analysis.get('issues', []),
                    'recommendations': analysis.get('required_actions', []),
                    'can_release': analysis.get('can_release'),
                    'summary': analysis.get('summary'),
                },
                'governance': governance
            }
            return response, 200
    except Exception as e:
        print(f"❌ Error analyzing proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


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
        
    except Exception as e:
        print(f"❌ Error improving content: {e}")
        return {'detail': str(e)}, 500

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
            
            return risk_analysis, 200
        
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

@bp.get("/api/proposals/<proposal_id>/readiness")
@bp.get("/proposals/<proposal_id>/readiness")
@token_required
def get_proposal_readiness(username=None, proposal_id=None):
    """Get readiness status and checks for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Verify proposal exists and get basic info
            cursor.execute(
                """
                SELECT id, title, status, client_name, client_email, content, sections
                FROM proposals
                WHERE id = %s OR id::text = %s
                """,
                (proposal_id, str(proposal_id)),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            actual_proposal_id = proposal['id']

            # Try to load existing governance row
            gov_cursor = conn.cursor()
            gov_cursor.execute(
                '''SELECT status, readiness_score, risk_score, can_release, issues, last_checked
                   FROM proposal_governance WHERE proposal_id = %s''',
                (actual_proposal_id,),
            )
            gov_row = gov_cursor.fetchone()

            governance = None
            if gov_row:
                governance = {
                    'status': gov_row[0],
                    'readiness_score': gov_row[1],
                    'risk_score': gov_row[2],
                    'can_release': gov_row[3],
                    'issues': _parse_sections(gov_row[4]) if len(gov_row) > 4 else [],
                    'last_checked': gov_row[5].isoformat() if len(gov_row) > 5 and gov_row[5] else None,
                }
            else:
                # Fallback: compute basic governance from current proposal payload
                payload = {
                    'id': actual_proposal_id,
                    'title': proposal.get('title'),
                    'client_name': proposal.get('client_name'),
                    'sections': _parse_sections(proposal.get('sections')),
                }
                basic = _basic_governance_check(payload)
                governance = {
                    'status': basic.get('status'),
                    'readiness_score': basic.get('score'),
                    'risk_score': basic.get('risk_score'),
                    'can_release': basic.get('can_release'),
                    'issues': basic.get('issues', []),
                    'last_checked': None,
                }

            # Load detailed readiness checks if any exist in the dedicated table
            checks_cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            checks_cursor.execute(
                """
                SELECT id, check_key, check_name, category, status, severity, message, created_at
                FROM readiness_checks
                WHERE proposal_id = %s
                ORDER BY created_at DESC, severity DESC
                """,
                (actual_proposal_id,),
            )
            checks_rows = checks_cursor.fetchall()
            checks = []
            for row in checks_rows:
                checks.append({
                    'id': row['id'],
                    'check_key': row['check_key'],
                    'check_name': row['check_name'],
                    'category': row['category'],
                    'status': row['status'],
                    'severity': row['severity'],
                    'message': row['message'],
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                })

            # If there are no explicit DB checks, surface governance issues as virtual checks
            if not checks and governance and governance.get('issues'):
                for idx, issue in enumerate(governance['issues']):
                    checks.append({
                        'id': idx + 1,
                        'check_key': issue.get('section') or issue.get('category') or 'general',
                        'check_name': issue.get('description') or 'Readiness issue',
                        'category': issue.get('category'),
                        'status': 'failed',
                        'severity': issue.get('severity', 'medium'),
                        'message': issue.get('recommendation') or issue.get('description'),
                        'created_at': governance.get('last_checked'),
                    })

            response = {
                'proposal_id': str(actual_proposal_id),
                'title': proposal.get('title'),
                'status': proposal.get('status'),
                'client_name': proposal.get('client_name'),
                'client_email': proposal.get('client_email'),
                'readiness_score': governance.get('readiness_score') if governance else None,
                'risk_score': governance.get('risk_score') if governance else None,
                'can_release': governance.get('can_release') if governance else None,
                'last_checked': governance.get('last_checked') if governance else None,
                'checks': checks,
            }
            return response, 200
    except Exception as e:
        print(f"❌ Error getting proposal readiness: {e}")
        import traceback
        traceback.print_exc()
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
                SELECT id, title, status, client_name, client_email
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
                    c.name as client_name, c.email as client_email
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
                    c.name as client_name, c.email as client_email
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
            
            # Verify ownership
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row['id']

            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal['owner_id'] != owner_id:
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
            
            # Verify ownership
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row['id']

            cursor.execute('SELECT owner_id, title FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal['owner_id'] != owner_id:
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
                base_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                invite_url = f"{base_url}/collaborate?token={access_token}"
                
                email_body = f"""
                {get_logo_html()}
                <h2>You've been invited to collaborate</h2>
                <p>You've been invited to collaborate on the proposal: <strong>{proposal['title']}</strong></p>
                <p>Click the link below to access the proposal:</p>
                <p><a href="{invite_url}" style="background-color: #27AE60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">Open Proposal</a></p>
                <p>Or copy and paste this link:</p>
                <p style="word-break: break-all; color: #666;">{invite_url}</p>
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
                SELECT ci.*, p.owner_id AS proposal_owner_id
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.id = %s
            """, (invitation_id,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invitation not found'}, 404

            # Ensure current user is the proposal owner
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row['id']

            if invitation['proposal_owner_id'] != owner_id:
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


@bp.get("/api/dashboard/summary")
@bp.get("/dashboard/summary")
@token_required
def get_creator_dashboard_summary(username=None):
    """Get high-level proposal pipeline metrics for the creator (or all, if admin)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Resolve user and role
            cursor.execute('SELECT id, role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404

            user_id = user['id']
            is_admin = user['role'] == 'admin'

            base_query = '''
                SELECT 
                    COUNT(*) AS total,
                    COUNT(CASE WHEN status = 'draft' THEN 1 END) AS draft,
                    COUNT(CASE WHEN status = 'In Review' THEN 1 END) AS in_review,
                    COUNT(CASE WHEN status = 'Pending CEO Approval' THEN 1 END) AS pending_ceo,
                    COUNT(CASE WHEN status = 'Sent to Client' THEN 1 END) AS sent_to_client,
                    COUNT(CASE WHEN status = 'signed' THEN 1 END) AS signed,
                    COUNT(CASE WHEN status = 'Archived' THEN 1 END) AS archived
                FROM proposals
            '''

            if is_admin:
                cursor.execute(base_query)
            else:
                cursor.execute(base_query + ' WHERE owner_id = %s', (user_id,))

            row = cursor.fetchone() or {}

            # Optional: proposals created in last 30 days
            if is_admin:
                cursor.execute(
                    '''SELECT COUNT(*) AS recent FROM proposals WHERE created_at >= NOW() - INTERVAL '30 days' ''')
            else:
                cursor.execute(
                    '''SELECT COUNT(*) AS recent FROM proposals 
                       WHERE owner_id = %s AND created_at >= NOW() - INTERVAL '30 days' ''',
                    (user_id,),
                )
            recent_row = cursor.fetchone() or {}

            return {
                'total': row.get('total', 0),
                'by_status': {
                    'draft': row.get('draft', 0),
                    'in_review': row.get('in_review', 0),
                    'pending_ceo_approval': row.get('pending_ceo', 0),
                    'sent_to_client': row.get('sent_to_client', 0),
                    'signed': row.get('signed', 0),
                    'archived': row.get('archived', 0),
                },
                'last_30_days': recent_row.get('recent', 0),
                'scope': 'all' if is_admin else 'mine',
            }, 200
    except Exception as e:
        print(f"❌ Error getting creator dashboard summary: {e}")
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
                SELECT p.id, p.owner_id, u.username, p.title, p.status
                FROM proposals p
                JOIN users u ON p.owner_id = u.id
                WHERE p.id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal['username'] != username:
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
                SELECT p.id, p.owner_id, u.username, p.title, p.status
                FROM proposals p
                JOIN users u ON p.owner_id = u.id
                WHERE p.id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Check permissions (owner or admin)
            if proposal['username'] != username and not is_admin:
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
            cursor.execute('SELECT id, role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            is_admin = user['role'] == 'admin'
            
            if is_admin:
                # Admin can see all archived proposals
                cursor.execute("""
                    SELECT id, owner_id AS user_id, title, content, status, client_name, client_email, 
                           budget, timeline_days, created_at, updated_at
                    FROM proposals
                    WHERE status = 'Archived'
                    ORDER BY updated_at DESC
                """)
            else:
                # Regular users see only their archived proposals
                cursor.execute("""
                    SELECT id, owner_id AS user_id, title, content, status, client_name, client_email, 
                           budget, timeline_days, created_at, updated_at
                    FROM proposals
                    WHERE owner_id = %s AND status = 'Archived'
                    ORDER BY updated_at DESC
                """, (user['id'],))
            
            rows = cursor.fetchall()
            proposals = []
            
            for row in rows:
                proposals.append({
                    'id': row['id'],
                    'user_id': row['user_id'],
                    'owner_id': row['user_id'],
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

