-- Persistent finance dashboard alerts (deal risk, discounts, etc.)
-- Run once on Postgres. Safe to re-run: uses IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS finance_alert_events (
    id SERIAL PRIMARY KEY,
    alert_type TEXT NOT NULL,
    proposal_id INTEGER NOT NULL,
    severity TEXT,
    details JSONB,
    proposal_title TEXT,
    client_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
    resolved_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_finance_alert_events_created
    ON finance_alert_events (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_finance_alert_events_resolved
    ON finance_alert_events (resolved_at);

-- At most one "open" row per (alert_type, proposal_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_finance_alert_events_open_unique
    ON finance_alert_events (alert_type, proposal_id)
    WHERE resolved_at IS NULL;
