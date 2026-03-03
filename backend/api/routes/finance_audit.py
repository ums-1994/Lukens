from datetime import datetime
import csv
import io
import json

from flask import Blueprint, jsonify, request, send_file
import psycopg2.extras

from api.utils.database import get_db_connection
from api.utils.decorators import token_required, finance_audit_required


bp = Blueprint('finance_audit', __name__)


def _parse_dt(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    except Exception:
        return None


def _build_filters(args):
    date_from = _parse_dt(args.get('date_from') or args.get('from'))
    date_to = _parse_dt(args.get('date_to') or args.get('to'))
    username = (args.get('user') or args.get('username') or '').strip()
    entity_type = (args.get('entity_type') or '').strip()
    action_type = (args.get('action_type') or '').strip()
    entity_id = (args.get('entity_id') or '').strip()

    where = []
    params = []

    if date_from:
        where.append('created_at >= %s')
        params.append(date_from)
    if date_to:
        where.append('created_at <= %s')
        params.append(date_to)
    if username:
        where.append('LOWER(COALESCE(username, \'\')) = %s')
        params.append(username.lower())
    if entity_type:
        where.append('LOWER(entity_type) = %s')
        params.append(entity_type.lower())
    if action_type:
        where.append('LOWER(action_type) = %s')
        params.append(action_type.lower())
    if entity_id:
        where.append('entity_id = %s')
        params.append(entity_id)

    where_sql = (' WHERE ' + ' AND '.join(where)) if where else ''
    return where_sql, params


@bp.get('/finance/audit-logs')
@token_required
@finance_audit_required
def list_audit_logs(username=None, user_id=None, email=None):
    try:
        limit = int(request.args.get('limit', '250'))
        limit = max(1, min(limit, 1000))
        offset = int(request.args.get('offset', '0'))
        offset = max(0, offset)

        where_sql, params = _build_filters(request.args)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                f"""
                SELECT id, user_id, username, entity_type, entity_id,
                       field_name, old_value, new_value, action_type, created_at
                FROM finance_audit_logs
                {where_sql}
                ORDER BY created_at DESC, id DESC
                LIMIT %s OFFSET %s
                """,
                params + [limit, offset],
            )
            rows = cursor.fetchall() or []

        for r in rows:
            if r.get('created_at') and hasattr(r['created_at'], 'isoformat'):
                r['created_at'] = r['created_at'].isoformat()

        return jsonify({'items': rows, 'limit': limit, 'offset': offset}), 200
    except Exception as e:
        return jsonify({'detail': str(e)}), 500


def _rows_to_csv(rows):
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow([
        'id', 'created_at', 'username', 'user_id',
        'entity_type', 'entity_id', 'action_type',
        'field_name', 'old_value', 'new_value',
    ])
    for r in rows:
        writer.writerow([
            r.get('id'),
            r.get('created_at'),
            r.get('username'),
            r.get('user_id'),
            r.get('entity_type'),
            r.get('entity_id'),
            r.get('action_type'),
            r.get('field_name'),
            r.get('old_value'),
            r.get('new_value'),
        ])
    return out.getvalue()


def _rows_to_pdf_bytes(rows):
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.pdfgen import canvas
    except Exception:
        raise RuntimeError('PDF export not available (reportlab missing)')

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=letter)
    width, height = letter

    y = height - 40
    c.setFont('Helvetica-Bold', 12)
    c.drawString(40, y, 'Finance Audit Logs')
    y -= 20

    c.setFont('Helvetica', 8)
    for r in rows:
        line = (
            f"{r.get('created_at')} | {r.get('username')} | {r.get('entity_type')}"
            f"#{r.get('entity_id')} | {r.get('action_type')} | {r.get('field_name')}"
        )
        c.drawString(40, y, line[:140])
        y -= 12
        if y < 60:
            c.showPage()
            y = height - 40
            c.setFont('Helvetica', 8)

    c.showPage()
    c.save()
    buf.seek(0)
    return buf.getvalue()


@bp.get('/finance/audit-logs/export')
@token_required
@finance_audit_required
def export_audit_logs(username=None, user_id=None, email=None):
    try:
        format_type = (request.args.get('format') or 'csv').lower().strip()
        where_sql, params = _build_filters(request.args)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                f"""
                SELECT id, user_id, username, entity_type, entity_id,
                       field_name, old_value, new_value, action_type, created_at
                FROM finance_audit_logs
                {where_sql}
                ORDER BY created_at DESC, id DESC
                LIMIT 5000
                """,
                params,
            )
            rows = cursor.fetchall() or []

        for r in rows:
            if r.get('created_at') and hasattr(r['created_at'], 'isoformat'):
                r['created_at'] = r['created_at'].isoformat()

        ts = datetime.utcnow().strftime('%Y%m%d_%H%M%S')

        if format_type == 'csv':
            csv_data = _rows_to_csv(rows)
            output = io.BytesIO(csv_data.encode('utf-8'))
            output.seek(0)
            return send_file(
                output,
                as_attachment=True,
                download_name=f"finance_audit_{ts}.csv",
                mimetype='text/csv',
            )

        if format_type == 'pdf':
            pdf_bytes = _rows_to_pdf_bytes(rows)
            output = io.BytesIO(pdf_bytes)
            output.seek(0)
            return send_file(
                output,
                as_attachment=True,
                download_name=f"finance_audit_{ts}.pdf",
                mimetype='application/pdf',
            )

        return jsonify({'detail': 'Unsupported format'}), 400
    except Exception as e:
        return jsonify({'detail': str(e)}), 500


@bp.get('/finance/compliance/<int:proposal_id>')
@token_required
@finance_audit_required
def get_compliance(username=None, proposal_id=None, user_id=None, email=None):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT proposal_id, status, reasons, evaluated_at
                FROM proposal_compliance
                WHERE proposal_id = %s
                """,
                (proposal_id,),
            )
            row = cursor.fetchone()

        if not row:
            return jsonify({'detail': 'Compliance not evaluated yet'}), 404

        if row.get('evaluated_at') and hasattr(row['evaluated_at'], 'isoformat'):
            row['evaluated_at'] = row['evaluated_at'].isoformat()

        return jsonify(row), 200
    except Exception as e:
        return jsonify({'detail': str(e)}), 500
