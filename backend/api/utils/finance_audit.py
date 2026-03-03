import json
import os
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import psycopg2.extras

from api.utils.database import get_db_connection


_executor = ThreadPoolExecutor(max_workers=int(os.getenv('AUDIT_LOG_WORKERS', '2')))


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _safe_json_dumps(value: Any) -> str:
    try:
        return json.dumps(value, ensure_ascii=False, default=str)
    except Exception:
        try:
            return str(value)
        except Exception:
            return ''


def _normalize_numeric(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        s = str(value).strip()
    except Exception:
        return None
    if not s:
        return None
    cleaned = ''.join(ch for ch in s if (ch.isdigit() or ch in '.-'))
    try:
        return float(cleaned)
    except Exception:
        return None


def _iter_discount_values(content: Any) -> List[Tuple[str, float]]:
    results: List[Tuple[str, float]] = []

    def walk(node: Any, path: str) -> None:
        if isinstance(node, dict):
            for k, v in node.items():
                p = f"{path}.{k}" if path else str(k)
                if isinstance(k, str) and 'discount' in k.lower():
                    num = _normalize_numeric(v)
                    if num is not None:
                        results.append((p, num))
                walk(v, p)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, f"{path}[{i}]")

    walk(content, '')
    return results


def _load_proposal(cursor, proposal_id: int) -> Optional[Dict[str, Any]]:
    cursor.execute(
        """
        SELECT id, status, content, updated_at
        FROM proposals
        WHERE id = %s
        """,
        (proposal_id,),
    )
    row = cursor.fetchone()
    if not row:
        return None
    if isinstance(row, dict):
        return row
    # Fallback if cursor isn't RealDictCursor
    return {
        'id': row[0],
        'status': row[1],
        'content': row[2],
        'updated_at': row[3],
    }


def log_finance_audit_async(
    *,
    user_id: Optional[int],
    username: Optional[str],
    entity_type: str,
    entity_id: str,
    action_type: str,
    changes: List[Dict[str, Any]],
) -> None:
    """Best-effort audit insert that never raises to caller."""

    payload = {
        'user_id': user_id,
        'username': username,
        'entity_type': entity_type,
        'entity_id': entity_id,
        'action_type': action_type,
        'changes': changes,
    }

    def _insert() -> None:
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                for c in changes:
                    cursor.execute(
                        """
                        INSERT INTO finance_audit_logs (
                            user_id, username, entity_type, entity_id,
                            field_name, old_value, new_value, action_type, created_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
                        """,
                        (
                            user_id,
                            username,
                            entity_type,
                            entity_id,
                            str(c.get('field') or ''),
                            _safe_json_dumps(c.get('old')),
                            _safe_json_dumps(c.get('new')),
                            action_type,
                        ),
                    )
                conn.commit()
        except Exception as e:
            # Never fail the request due to audit logging
            try:
                print(f"[AUDIT] Failed to insert audit logs: {e} payload={payload}")
            except Exception:
                pass

    try:
        _executor.submit(_insert)
    except Exception:
        # Executor saturated or shutting down
        try:
            _insert()
        except Exception:
            pass


def evaluate_proposal_compliance(
    *,
    proposal_id: int,
) -> Dict[str, Any]:
    """Evaluate compliance and upsert proposal_compliance row.

    Rules implemented:
    - Discount threshold: any numeric field containing 'discount' in content JSON must be <= DISCOUNT_MAX_PERCENT.
    - Pricing changes after proposal sent: if proposal status is 'Sent to Client'/'Released'/similar, status becomes NON_COMPLIANT.
    - Pricing is finance-approved: if status is in a pending state, mark PENDING_REVIEW.

    Returns: {status, reasons}
    """

    discount_max = float(os.getenv('DISCOUNT_MAX_PERCENT', '20'))

    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        proposal = _load_proposal(cursor, proposal_id)
        if not proposal:
            raise RuntimeError('Proposal not found')

        status_raw = (proposal.get('status') or '').strip()
        status_lower = status_raw.lower()

        reasons: List[Dict[str, Any]] = []
        compliance_status = 'COMPLIANT'

        content = proposal.get('content')
        content_obj: Any = None
        if content:
            try:
                content_obj = json.loads(content) if isinstance(content, str) else content
            except Exception:
                content_obj = None

        # Rule: discount threshold
        if content_obj is not None:
            discount_values = _iter_discount_values(content_obj)
            for path, value in discount_values:
                if value > discount_max:
                    compliance_status = 'NON_COMPLIANT'
                    reasons.append(
                        {
                            'rule': 'DISCOUNT_THRESHOLD',
                            'path': path,
                            'value': value,
                            'max': discount_max,
                        }
                    )

        # Rule: pricing approval workflow
        if compliance_status != 'NON_COMPLIANT':
            if 'pending' in status_lower or 'review' in status_lower:
                compliance_status = 'PENDING_REVIEW'
                reasons.append(
                    {
                        'rule': 'PRICING_APPROVAL_PENDING',
                        'status': status_raw,
                    }
                )

        # Note: "no pricing changes allowed after proposal is sent" is enforced
        # at the write endpoints when attempting to change pricing fields.
        # Here we also treat sent states as compliant only if already approved.
        if compliance_status != 'NON_COMPLIANT':
            if 'sent to client' in status_lower or 'released' in status_lower:
                # Sent states should be finance-approved already; if not, flag.
                if 'approved' not in status_lower and 'signed' not in status_lower:
                    compliance_status = 'PENDING_REVIEW'
                    reasons.append(
                        {
                            'rule': 'SENT_BUT_NOT_APPROVED',
                            'status': status_raw,
                        }
                    )

        cursor.execute(
            """
            INSERT INTO proposal_compliance (proposal_id, status, reasons, evaluated_at)
            VALUES (%s, %s, %s::jsonb, CURRENT_TIMESTAMP)
            ON CONFLICT (proposal_id)
            DO UPDATE SET status = EXCLUDED.status, reasons = EXCLUDED.reasons, evaluated_at = CURRENT_TIMESTAMP
            """,
            (proposal_id, compliance_status, json.dumps(reasons)),
        )
        conn.commit()

        return {
            'proposal_id': proposal_id,
            'status': compliance_status,
            'reasons': reasons,
            'evaluated_at': _utc_now_iso(),
        }


def get_proposal_compliance(cursor, proposal_id: int) -> Optional[Dict[str, Any]]:
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
        return None
    if isinstance(row, dict):
        return row
    return {
        'proposal_id': row[0],
        'status': row[1],
        'reasons': row[2],
        'evaluated_at': row[3],
    }
