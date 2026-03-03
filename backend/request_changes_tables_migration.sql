-- Migration: Tables required for "Request Changes" workflow (Admin → Manager/Finance)
-- Run this on the deployed DB (e.g. Render PostgreSQL) if request-changes returns 500
-- or if document_comments / activity_log / notifications are missing or incomplete.
-- Safe to run multiple times (uses IF NOT EXISTS).

-- 1) document_comments – stores the change-request feedback and shows in History
CREATE TABLE IF NOT EXISTS document_comments (
  id SERIAL PRIMARY KEY,
  proposal_id INTEGER NOT NULL,
  comment_text TEXT NOT NULL,
  created_by INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  section_index INTEGER,
  highlighted_text TEXT,
  status VARCHAR(50) DEFAULT 'open',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_by INTEGER,
  resolved_at TIMESTAMP,
  FOREIGN KEY (proposal_id) REFERENCES proposals(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  FOREIGN KEY (resolved_by) REFERENCES users(id)
);

-- 2) activity_log – used for status change and “changes requested” timeline entries
CREATE TABLE IF NOT EXISTS activity_log (
  id SERIAL PRIMARY KEY,
  proposal_id INTEGER NOT NULL,
  user_id INTEGER,
  action_type VARCHAR(100) NOT NULL,
  action_description TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_activity_log_proposal ON activity_log(proposal_id, created_at DESC);

-- 3) notifications – used to notify manager/finance when changes are requested
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  proposal_id INTEGER,
  notification_type VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  read_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE
);

-- Optional: ensure proposals has updated_at (needed for status update)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'proposals' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE proposals ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
  END IF;
END $$;
