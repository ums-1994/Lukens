import os
import json
import glob
import argparse
from datetime import datetime, timedelta

import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash

# One-off migration script to import legacy JSON files into PostgreSQL
# Files handled (if present):
# - backend/users.json -> users table
# - backend/proposal_feedback.json -> proposal_feedback table
# - backend/storage.json, storage_stage2.json, storage_stage3.json,
#   tmp_stage2_storage.json, tmp_stage3_storage.json -> content/proposals best-effort
# - backend/verification_tokens.json and verification_tokens.json -> email_verification_tokens
#
# Usage examples:
#   python migrate_json_to_postgres.py --apply
#   python migrate_json_to_postgres.py --apply --delete
#
# By default, runs in dry-run mode (no DB writes). Use --apply to import.
# Use --delete to delete imported files after successful import.


def connect_db():
    load_dotenv()
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=int(os.getenv('DB_PORT', '5432')),
        dbname=os.getenv('DB_NAME', 'proposal_sow_builder'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', '')
    )
    return conn


def ensure_aux_tables(cur):
    # Needed by imports for tokens
    cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS email_verification_tokens (
            token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) NOT NULL,
            issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL,
            used_at TIMESTAMP
        )
        """
    )


def import_users(cur, path, apply):
    if not os.path.exists(path):
        return 0
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    # Accept formats:
    # - { "users": [ ... ] }
    # - [ ... ]
    # - { username/email: { ... } }
    if isinstance(data, dict) and 'users' in data and isinstance(data['users'], list):
        users = data['users']
    elif isinstance(data, list):
        users = data
    elif isinstance(data, dict):
        users = list(data.values())
    else:
        print(f"[users] Unsupported JSON structure in {path}")
        return 0

    inserted = 0
    for u in users:
        if not isinstance(u, dict):
            print(f"[users] Skipping non-dict entry: {u}")
            continue
        username = u.get('username') or (u.get('email') or '').split('@')[0]
        email = u.get('email') or f"{username}@example.com"
        full_name = u.get('full_name') or u.get('name') or username
        role = u.get('role') or 'user'
        # Use existing hashed_password if provided, otherwise hash a default or provided plaintext password
        if u.get('hashed_password'):
            password_hash = u['hashed_password']
        else:
            raw_password = u.get('password') or 'Password123!'
            password_hash = generate_password_hash(raw_password)
        if apply:
            try:
                cur.execute(
                    '''INSERT INTO users (username, email, password_hash, full_name, role)
                       VALUES (%s, %s, %s, %s, %s)
                       ON CONFLICT (email) DO NOTHING''',
                    (username, email, password_hash, full_name, role)
                )
                inserted += cur.rowcount
            except Exception as e:
                print(f"[users] Skip {email}: {e}")
        else:
            print(f"[dry-run users] would insert: {email} ({role})")
            inserted += 1
    return inserted


def import_proposal_feedback(cur, path, apply):
    if not os.path.exists(path):
        return 0
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    # Accept formats:
    # - { "feedback": [ ... ] }
    # - [ ... ]
    # - { id: {...}, ... }
    if isinstance(data, dict) and 'feedback' in data and isinstance(data['feedback'], list):
        items = data['feedback']
    elif isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = list(data.values())
    elif isinstance(data, list):
        items = data
    else:
        print(f"[feedback] Unsupported JSON structure in {path}")
        return 0

    inserted = 0
    for item in items:
        if not isinstance(item, dict):
            print(f"[feedback] Skipping non-dict entry: {item}")
            continue
        proposal_id = item.get('proposal_id') or item.get('proposalId')
        client_id = item.get('client_id') or item.get('clientId')
        # Map common fields
        feedback_text = item.get('feedback_text') or item.get('message') or item.get('feedback') or ''
        rating = item.get('rating') or None
        if apply:
            try:
                cur.execute(
                    '''INSERT INTO proposal_feedback (proposal_id, client_id, feedback_text, rating)
                       VALUES (%s, %s, %s, %s)''',
                    (proposal_id, client_id, feedback_text, rating)
                )
                inserted += cur.rowcount
            except Exception as e:
                print(f"[feedback] Skip: {e}")
        else:
            print(f"[dry-run feedback] would insert: proposal_id={proposal_id}, text={feedback_text[:30]}...")
            inserted += 1
    return inserted


def import_verification_tokens(cur, paths, apply):
    inserted = 0
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # Collect token dicts from various shapes:
        collected = []
        if isinstance(data, dict):
            # Case A: { "tokens": [ {..}, {..} ], other_token_id: {..} }
            if isinstance(data.get('tokens'), list):
                for entry in data['tokens']:
                    if isinstance(entry, dict):
                        collected.append(entry)
            # Include named keys that map to dicts
            for k, v in data.items():
                if k == 'tokens':
                    continue
                if isinstance(v, dict):
                    collected.append(v)
        elif isinstance(data, list):
            # Case B: top-level list
            for entry in data:
                if isinstance(entry, dict):
                    collected.append(entry)
        else:
            print(f"[verify] Unsupported JSON structure in {path}")
            continue

        for t in collected:
            if not isinstance(t, dict):
                continue
            email = t.get('email') or t.get('user') or ''
            issued_at = t.get('issued_at') or t.get('created_at')
            expires_at = t.get('expires_at')
            # Fallbacks
            if not issued_at:
                issued_at = datetime.utcnow().isoformat()
            if not expires_at:
                expires_at = (datetime.utcnow() + timedelta(hours=24)).isoformat()
            if apply:
                try:
                    cur.execute(
                        '''INSERT INTO email_verification_tokens (email, issued_at, expires_at)
                           VALUES (%s, %s, %s)''',
                        (email, issued_at, expires_at)
                    )
                    inserted += cur.rowcount
                except Exception as e:
                    print(f"[verify] Skip {email}: {e}")
            else:
                print(f"[dry-run verify] would insert token for {email}")
                inserted += 1
    return inserted


def import_storage_like(cur, paths, apply):
    # Best-effort import of content snippets into content table
    inserted = 0
    for path in paths:
        if not os.path.exists(path):
            continue
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"[storage] Could not read {path}: {e}")
            continue

        items = []
        if isinstance(data, dict):
            # Expect map of key -> object with label/content
            for k, v in data.items():
                items.append({"key": k, **(v if isinstance(v, dict) else {"content": str(v)})})
        elif isinstance(data, list):
            items = data
        else:
            print(f"[storage] Unsupported JSON structure in {path}")
            continue

        for item in items:
            key = item.get('key') or item.get('id') or os.path.basename(path)
            label = item.get('label') or item.get('title') or key
            content = item.get('content') or item.get('text') or ''
            category = item.get('category') or 'Templates'
            is_folder = bool(item.get('is_folder') or False)
            parent_id = item.get('parent_id')
            public_id = item.get('public_id')
            if apply:
                try:
                    cur.execute(
                        '''INSERT INTO content (key, label, content, category, is_folder, parent_id, public_id)
                           VALUES (%s, %s, %s, %s, %s, %s, %s)
                           ON CONFLICT (key) DO NOTHING''',
                        (key, label, content, category, is_folder, parent_id, public_id)
                    )
                    inserted += cur.rowcount
                except Exception as e:
                    print(f"[storage] Skip {key}: {e}")
            else:
                print(f"[dry-run storage] would insert content {key}")
                inserted += 1
    return inserted


def main():
    parser = argparse.ArgumentParser(description="Import legacy JSON files into PostgreSQL")
    parser.add_argument('--apply', action='store_true', help='Apply changes (otherwise dry run)')
    parser.add_argument('--delete', action='store_true', help='Delete files after successful import')
    args = parser.parse_args()

    base = os.path.dirname(os.path.abspath(__file__))

    users_path = os.path.join(base, 'users.json')
    feedback_path = os.path.join(base, 'proposal_feedback.json')
    verification_paths = [
        os.path.join(base, 'verification_tokens.json'),
        os.path.join(os.path.dirname(base), 'verification_tokens.json'),
    ]
    storage_like = [
        os.path.join(base, 'storage.json'),
        os.path.join(base, 'storage_stage2.json'),
        os.path.join(base, 'storage_stage3.json'),
        os.path.join(os.path.dirname(base), 'tmp_stage2_storage.json'),
        os.path.join(os.path.dirname(base), 'tmp_stage3_storage.json'),
    ]

    conn = connect_db()
    try:
        cur = conn.cursor()
        ensure_aux_tables(cur)
        conn.commit()

        total = 0
        total += import_users(cur, users_path, args.apply)
        total += import_proposal_feedback(cur, feedback_path, args.apply)
        total += import_verification_tokens(cur, verification_paths, args.apply)
        total += import_storage_like(cur, storage_like, args.apply)

        if args.apply:
            conn.commit()
            print(f"✅ Import complete. Inserted/processed rows: {total}")
        else:
            print(f"[dry-run] Would process rows: {total}")

        if args.apply and args.delete:
            to_delete = [p for p in [users_path, feedback_path, *verification_paths, *storage_like] if os.path.exists(p)]
            for p in to_delete:
                try:
                    os.remove(p)
                    print(f"🗑️ Deleted {p}")
                except Exception as e:
                    print(f"⚠️ Could not delete {p}: {e}")
    finally:
        conn.close()


if __name__ == '__main__':
    main()
