-- add_kb_tables_and_seed_render.sql
-- Run these commands in your psql session connected to Render database

-- 1) Create KB documents table
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
);

-- 2) Create KB clauses table
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
);

-- 3) Seed the core policy document
INSERT INTO kb_documents (key, title, doc_type, tags, body, version)
VALUES (
  'risk_gate_core',
  'Risk Gate Core Policies',
  'policy',
  '["risk_gate","governance"]'::jsonb,
  'Core governance policies and pre-approved clause guidance for proposals, SOWs, and RFIs.',
  'v1'
)
ON CONFLICT (key) DO NOTHING;

-- 4) Seed starter clauses
INSERT INTO kb_clauses (document_id, clause_key, title, category, severity, clause_text, recommended_text, tags)
SELECT
  d.id,
  v.clause_key,
  v.title,
  v.category,
  v.severity,
  v.clause_text,
  v.recommended_text,
  v.tags::jsonb
FROM kb_documents d
CROSS JOIN (
  VALUES
    (
      'confidentiality_minimum',
      'Confidentiality Minimum',
      'legal',
      'high',
      'This document contains confidential information and is intended solely for the recipient. Unauthorized disclosure is prohibited.',
      'Add a confidentiality section stating the document is confidential, intended recipients, and disclosure restrictions.',
      '["confidentiality","legal"]'
    ),
    (
      'pii_handling_minimum',
      'PII Handling Minimum',
      'security',
      'high',
      'No personal data (PII) should be included unless required and authorized. Any personal data must be minimized and protected.',
      'Remove personal identifiers (names, emails, phone numbers) from the document. Use placeholders where needed.',
      '["pii","security"]'
    ),
    (
      'no_credentials_minimum',
      'No Credentials or Secrets',
      'security',
      'high',
      'Credentials, API keys, access tokens, and secrets must never be included in proposals, SOWs, or RFIs.',
      'Remove any credentials/tokens/keys and reference secure channels for credential exchange.',
      '["secrets","security"]'
    )
) AS v(clause_key, title, category, severity, clause_text, recommended_text, tags)
WHERE d.key = 'risk_gate_core'
ON CONFLICT (clause_key) DO NOTHING;

-- 5) Verify
SELECT key, title FROM kb_documents ORDER BY id;
SELECT clause_key, category, severity FROM kb_clauses ORDER BY clause_key;
