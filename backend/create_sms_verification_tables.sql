-- ============================================================
-- SMS VERIFICATION TABLES FOR CLIENT ONBOARDING
-- ============================================================
-- Run this script in PGAdmin Query Tool
-- This adds phone verification fields to existing invitations table
-- and creates an audit table for SMS events

-- ============================================================
-- 1. ADD PHONE VERIFICATION FIELDS TO EXISTING TABLE
-- ============================================================

-- Add phone verification columns to client_onboarding_invitations
ALTER TABLE client_onboarding_invitations
    ADD COLUMN IF NOT EXISTS phone_number VARCHAR(32),
    ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verification_code_hash TEXT,
    ADD COLUMN IF NOT EXISTS verification_code_salt TEXT,
    ADD COLUMN IF NOT EXISTS code_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verification_attempts INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_code_sent_at TIMESTAMPTZ;

-- Add comment to explain the columns
COMMENT ON COLUMN client_onboarding_invitations.phone_number IS 'Client phone number for SMS verification (E.164 format)';
COMMENT ON COLUMN client_onboarding_invitations.phone_verified_at IS 'Timestamp when phone was successfully verified';
COMMENT ON COLUMN client_onboarding_invitations.verification_code_hash IS 'Hashed verification code (bcrypt/argon2)';
COMMENT ON COLUMN client_onboarding_invitations.verification_code_salt IS 'Salt used for hashing verification code';
COMMENT ON COLUMN client_onboarding_invitations.code_expires_at IS 'When the verification code expires (typically 10-15 minutes)';
COMMENT ON COLUMN client_onboarding_invitations.verification_attempts IS 'Number of failed verification attempts';
COMMENT ON COLUMN client_onboarding_invitations.last_code_sent_at IS 'Timestamp of last SMS code sent (for rate limiting)';

-- ============================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- ============================================================

-- Index for phone number lookups
CREATE INDEX IF NOT EXISTS idx_client_invite_phone 
    ON client_onboarding_invitations(phone_number) 
    WHERE phone_number IS NOT NULL;

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

-- ============================================================
-- 3. CREATE SMS VERIFICATION EVENTS AUDIT TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS sms_verification_events (
    id BIGSERIAL PRIMARY KEY,
    invitation_id BIGINT NOT NULL REFERENCES client_onboarding_invitations(id) ON DELETE CASCADE,
    phone_number VARCHAR(32),
    event_type VARCHAR(40) NOT NULL,
    event_detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE sms_verification_events IS 'Audit log for SMS verification events (code sent, verified, failed, etc.)';
COMMENT ON COLUMN sms_verification_events.invitation_id IS 'Reference to the client onboarding invitation';
COMMENT ON COLUMN sms_verification_events.phone_number IS 'Phone number involved in the event';
COMMENT ON COLUMN sms_verification_events.event_type IS 'Type of event: code_sent, code_verified, verify_failed, rate_limited, code_expired';
COMMENT ON COLUMN sms_verification_events.event_detail IS 'Additional details about the event (error messages, etc.)';

-- Create indexes for audit table
CREATE INDEX IF NOT EXISTS idx_sms_verif_invitation 
    ON sms_verification_events(invitation_id);

CREATE INDEX IF NOT EXISTS idx_sms_verif_type_time 
    ON sms_verification_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sms_verif_phone 
    ON sms_verification_events(phone_number) 
    WHERE phone_number IS NOT NULL;

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
        'phone_number', 
        'phone_verified_at', 
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
WHERE table_name = 'sms_verification_events'
ORDER BY ordinal_position;

-- ============================================================
-- DONE!
-- ============================================================
-- Your tables are now ready for SMS verification!
-- Next steps:
-- 1. Add Twilio credentials to .env file
-- 2. Install twilio: pip install twilio
-- 3. Implement the API endpoints in app.py

