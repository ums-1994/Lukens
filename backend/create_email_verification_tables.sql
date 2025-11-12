-- ============================================================
-- EMAIL VERIFICATION TABLES FOR CLIENT ONBOARDING
-- ============================================================
-- Run this script in PGAdmin Query Tool
-- This adds email verification fields to existing invitations table
-- and creates an audit table for verification events

-- ============================================================
-- 1. ADD EMAIL VERIFICATION FIELDS TO EXISTING TABLE
-- ============================================================

-- Add email verification columns to client_onboarding_invitations
ALTER TABLE client_onboarding_invitations
    ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verification_code_hash TEXT,
    ADD COLUMN IF NOT EXISTS verification_code_salt TEXT,
    ADD COLUMN IF NOT EXISTS code_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verification_attempts INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_code_sent_at TIMESTAMPTZ;

-- Add comments to explain the columns
COMMENT ON COLUMN client_onboarding_invitations.email_verified_at IS 'Timestamp when email was successfully verified';
COMMENT ON COLUMN client_onboarding_invitations.verification_code_hash IS 'Hashed verification code (bcrypt/argon2)';
COMMENT ON COLUMN client_onboarding_invitations.verification_code_salt IS 'Salt used for hashing verification code';
COMMENT ON COLUMN client_onboarding_invitations.code_expires_at IS 'When the verification code expires (typically 10-15 minutes)';
COMMENT ON COLUMN client_onboarding_invitations.verification_attempts IS 'Number of failed verification attempts';
COMMENT ON COLUMN client_onboarding_invitations.last_code_sent_at IS 'Timestamp of last verification code sent (for rate limiting)';

-- ============================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- ============================================================

-- Index for expiry checks
CREATE INDEX IF NOT EXISTS idx_client_invite_expires 
    ON client_onboarding_invitations(expires_at) 
    WHERE status = 'pending';

-- Index for code expiry checks
CREATE INDEX IF NOT EXISTS idx_client_invite_code_expires 
    ON client_onboarding_invitations(code_expires_at) 
    WHERE verification_code_hash IS NOT NULL;

-- Index for status filtering
CREATE INDEX IF NOT EXISTS idx_client_invite_status 
    ON client_onboarding_invitations(status);

-- Index for email verification status
CREATE INDEX IF NOT EXISTS idx_client_invite_email_verified 
    ON client_onboarding_invitations(email_verified_at) 
    WHERE email_verified_at IS NOT NULL;

-- ============================================================
-- 3. CREATE EMAIL VERIFICATION EVENTS AUDIT TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS email_verification_events (
    id BIGSERIAL PRIMARY KEY,
    invitation_id BIGINT NOT NULL REFERENCES client_onboarding_invitations(id) ON DELETE CASCADE,
    email VARCHAR(255),
    event_type VARCHAR(40) NOT NULL,
    event_detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE email_verification_events IS 'Audit log for email verification events (code sent, verified, failed, etc.)';
COMMENT ON COLUMN email_verification_events.invitation_id IS 'Reference to the client onboarding invitation';
COMMENT ON COLUMN email_verification_events.email IS 'Email address involved in the event';
COMMENT ON COLUMN email_verification_events.event_type IS 'Type of event: code_sent, code_verified, verify_failed, rate_limited, code_expired';
COMMENT ON COLUMN email_verification_events.event_detail IS 'Additional details about the event (error messages, etc.)';

-- Create indexes for audit table
CREATE INDEX IF NOT EXISTS idx_email_verif_invitation 
    ON email_verification_events(invitation_id);

CREATE INDEX IF NOT EXISTS idx_email_verif_type_time 
    ON email_verification_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_email_verif_email 
    ON email_verification_events(email) 
    WHERE email IS NOT NULL;

-- ============================================================
-- 4. VERIFY TABLES WERE CREATED
-- ============================================================

-- Check if columns were added
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'client_onboarding_invitations'
    AND column_name IN (
        'email_verified_at', 
        'verification_code_hash',
        'verification_code_salt',
        'code_expires_at',
        'verification_attempts',
        'last_code_sent_at'
    )
ORDER BY column_name;

-- Check if audit table exists
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'email_verification_events'
ORDER BY ordinal_position;

-- ============================================================
-- DONE!
-- ============================================================
-- Your tables are now ready for email verification!
-- Next steps:
-- 1. Implement the API endpoints in app.py
-- 2. Update the frontend onboarding page

