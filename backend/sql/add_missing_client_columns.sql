-- Migration to add missing client detail columns
-- These columns are required for the enhanced Proposal Wizard autofill

ALTER TABLE clients 
ADD COLUMN IF NOT EXISTS holding_information TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS client_contact_email TEXT,
ADD COLUMN IF NOT EXISTS client_contact_mobile TEXT,
ADD COLUMN IF NOT EXISTS additional_info JSONB;

-- Comment on columns for clarity
COMMENT ON COLUMN clients.holding_information IS 'Parent company or group information';
COMMENT ON COLUMN clients.address IS 'Physical or postal address of the client';
COMMENT ON COLUMN clients.client_contact_email IS 'Email address for the specific client contact';
COMMENT ON COLUMN clients.client_contact_mobile IS 'Mobile/Phone number for the specific client contact';
COMMENT ON COLUMN clients.additional_info IS 'JSON storage for any other client-specific metadata';
