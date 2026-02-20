import os
from datetime import datetime


def _truthy_env(name: str) -> bool:
    return os.getenv(name, '').strip().lower() in ('1', 'true', 'yes', 'y', 'on')


def ensure_dev_seeded(cursor, is_dev_mode: bool) -> None:
    """Dev-only idempotent seed.

    This must never run in prod unless explicitly enabled.
    """

    if not is_dev_mode:
        return

    if not _truthy_env('DEV_AUTO_SEED'):
        return

    now = datetime.utcnow()

    # ---------------------------------------------------------------------
    # Clients (creator dropdown etc.)
    # ---------------------------------------------------------------------
    try:
        cursor.execute('SELECT COUNT(*) FROM clients')
        clients_count = (cursor.fetchone() or [0])[0] or 0
    except Exception:
        clients_count = 0

    if clients_count == 0:
        for company_name in [
            'Standard Bank',
            'FNB',
            'ABSA',
            'Nedbank',
            'Capitec',
        ]:
            cursor.execute(
                """
                INSERT INTO clients (company_name, email, status, created_at, updated_at)
                VALUES (%s, %s, 'active', %s, %s)
                ON CONFLICT (email) DO NOTHING
                """,
                (
                    company_name,
                    f"{company_name.lower().replace(' ', '')}@example.com",
                    now,
                    now,
                ),
            )

    # ---------------------------------------------------------------------
    # Knowledge base tables for Risk Gate
    # ---------------------------------------------------------------------
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS kb_documents (
          id SERIAL PRIMARY KEY,
          key VARCHAR(255) UNIQUE NOT NULL,
          title VARCHAR(500) NOT NULL,
          doc_type VARCHAR(100) NOT NULL,
          tags JSONB,
          body TEXT,
          version VARCHAR(50),
          is_active BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS kb_clauses (
          id SERIAL PRIMARY KEY,
          document_id INTEGER NOT NULL REFERENCES kb_documents(id) ON DELETE CASCADE,
          clause_key VARCHAR(255) UNIQUE NOT NULL,
          title VARCHAR(500) NOT NULL,
          category VARCHAR(100) NOT NULL,
          severity VARCHAR(20) DEFAULT 'medium',
          clause_text TEXT NOT NULL,
          recommended_text TEXT,
          tags JSONB,
          is_active BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )

    cursor.execute("SELECT COUNT(*) FROM kb_documents")
    kb_docs_count = (cursor.fetchone() or [0])[0] or 0

    if kb_docs_count == 0:
        cursor.execute(
            """
            INSERT INTO kb_documents (key, title, doc_type, tags, body, version)
            VALUES (
              'risk_gate_core',
              'Risk Gate Core Policies',
              'policy',
              '["risk_gate","governance"]'::jsonb,
              'Core governance policies and pre-approved clause guidance for proposals, SOWs, and RFIs.',
              'v1'
            )
            ON CONFLICT (key) DO NOTHING
            """
        )

        cursor.execute("SELECT id FROM kb_documents WHERE key = 'risk_gate_core'")
        doc_row = cursor.fetchone()
        doc_id = doc_row[0] if doc_row else None

        if doc_id:
            clauses = [
                (
                    'confidentiality_minimum',
                    'Confidentiality Minimum',
                    'legal',
                    'high',
                    'This document contains confidential information and is intended solely for the recipient. Unauthorized disclosure is prohibited.',
                    'Add a confidentiality section stating the document is confidential, intended recipients, and disclosure restrictions.',
                    '["confidentiality","legal"]',
                ),
                (
                    'pii_handling_minimum',
                    'PII Handling Minimum',
                    'security',
                    'high',
                    'No personal data (PII) should be included unless required and authorized. Any personal data must be minimized and protected.',
                    'Remove personal identifiers (names, emails, phone numbers) from the document. Use placeholders where needed.',
                    '["pii","security"]',
                ),
                (
                    'no_credentials_minimum',
                    'No Credentials or Secrets',
                    'security',
                    'high',
                    'Credentials, API keys, access tokens, and secrets must never be included in proposals, SOWs, or RFIs.',
                    'Remove any credentials/tokens/keys and reference secure channels for credential exchange.',
                    '["secrets","security"]',
                ),
            ]

            for (
                clause_key,
                title,
                category,
                severity,
                clause_text,
                recommended_text,
                tags,
            ) in clauses:
                cursor.execute(
                    """
                    INSERT INTO kb_clauses (
                      document_id, clause_key, title, category, severity,
                      clause_text, recommended_text, tags
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb)
                    ON CONFLICT (clause_key) DO NOTHING
                    """,
                    (
                        doc_id,
                        clause_key,
                        title,
                        category,
                        severity,
                        clause_text,
                        recommended_text,
                        tags,
                    ),
                )

    # ---------------------------------------------------------------------
    # Content library modules (content_modules/module_versions)
    # ---------------------------------------------------------------------
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS content_modules (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            category VARCHAR(100) DEFAULT 'Other',
            body TEXT NOT NULL,
            version INTEGER DEFAULT 1,
            created_by INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_editable BOOLEAN DEFAULT true
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS module_versions (
            id SERIAL PRIMARY KEY,
            module_id INTEGER REFERENCES content_modules(id) ON DELETE CASCADE,
            version INTEGER NOT NULL,
            snapshot TEXT NOT NULL,
            note TEXT,
            created_by INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )

    cursor.execute('SELECT COUNT(*) FROM content_modules')
    modules_count = (cursor.fetchone() or [0])[0] or 0

    if modules_count == 0:
        seed_modules = [
            (
                'Khonology Company Overview',
                'Company Profile',
                'Khonology is a technology consulting firm specializing in digital transformation, enterprise software, and AI-powered solutions.',
                False,
            ),
            (
                'Executive Summary Template',
                'Templates',
                '# Executive Summary\n\n[Client Name] has engaged Khonology to ...',
                True,
            ),
            (
                'Standard Terms and Conditions',
                'Legal',
                '# Terms and Conditions\n\n1. Engagement Terms ...',
                False,
            ),
        ]

        for title, category, body, is_editable in seed_modules:
            cursor.execute(
                """
                INSERT INTO content_modules (title, category, body, is_editable, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
                """,
                (title, category, body, is_editable, now, now),
            )
            module_id = (cursor.fetchone() or [None])[0]
            if module_id:
                cursor.execute(
                    """
                    INSERT INTO module_versions (module_id, version, snapshot, note, created_at)
                    VALUES (%s, 1, %s, 'Initial version', %s)
                    """,
                    (module_id, body, now),
                )

    # ---------------------------------------------------------------------
    # Dev user + sample proposal (finance metrics / proposal lists)
    # ---------------------------------------------------------------------
    try:
        cursor.execute('SELECT COUNT(*) FROM users')
        users_count = (cursor.fetchone() or [0])[0] or 0
    except Exception:
        users_count = 0

    dev_owner_id = None
    if users_count == 0:
        # password_hash is not used when DEV_BYPASS_AUTH is enabled; keep as placeholder
        cursor.execute(
            """
            INSERT INTO users (username, email, password_hash, full_name, role, is_active, is_email_verified, created_at, updated_at)
            VALUES ('dev_admin', 'dev_admin@local', 'dev', 'Dev Admin', 'admin', true, true, %s, %s)
            ON CONFLICT (username) DO NOTHING
            RETURNING id
            """,
            (now, now),
        )
        row = cursor.fetchone()
        if row:
            dev_owner_id = row[0]

    if not dev_owner_id:
        cursor.execute("SELECT id FROM users ORDER BY id ASC LIMIT 1")
        row = cursor.fetchone()
        if row:
            dev_owner_id = row[0]

    if dev_owner_id:
        cursor.execute('SELECT COUNT(*) FROM proposals')
        proposals_count = (cursor.fetchone() or [0])[0] or 0

        if proposals_count == 0:
            cursor.execute(
                """
                INSERT INTO proposals (title, client, owner_id, status, created_at, updated_at)
                VALUES (%s, %s, %s, 'Draft', %s, %s)
                """,
                (
                    'Sample Proposal (Dev Seed)',
                    'Standard Bank',
                    dev_owner_id,
                    now,
                    now,
                ),
            )
