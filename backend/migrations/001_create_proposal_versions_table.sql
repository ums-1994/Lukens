-- Migration: Create proposal_versions table for autosave and version history
-- Created: 2025-01-27
-- Description: This table stores version history for proposals with autosave functionality

-- Create proposal_versions table
CREATE TABLE IF NOT EXISTS proposal_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id UUID NOT NULL,
  version_number INT NOT NULL,
  content JSONB NOT NULL,
  created_by UUID,
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- Foreign key constraints (assuming users table exists)
  CONSTRAINT fk_proposal_versions_proposal_id 
    FOREIGN KEY (proposal_id) 
    REFERENCES proposals(id) ON DELETE CASCADE,
    
  CONSTRAINT fk_proposal_versions_created_by 
    FOREIGN KEY (created_by) 
    REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_proposal_versions_proposal_id 
  ON proposal_versions(proposal_id);

CREATE INDEX IF NOT EXISTS idx_proposal_versions_created_at 
  ON proposal_versions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_proposal_versions_version_number 
  ON proposal_versions(proposal_id, version_number);

-- Add comments for documentation
COMMENT ON TABLE proposal_versions IS 'Stores version history for proposals with autosave functionality';
COMMENT ON COLUMN proposal_versions.id IS 'Unique identifier for the version';
COMMENT ON COLUMN proposal_versions.proposal_id IS 'Reference to the parent proposal';
COMMENT ON COLUMN proposal_versions.version_number IS 'Sequential version number for the proposal';
COMMENT ON COLUMN proposal_versions.content IS 'JSON content of the proposal at this version';
COMMENT ON COLUMN proposal_versions.created_by IS 'User who created this version';
COMMENT ON COLUMN proposal_versions.created_at IS 'Timestamp when this version was created';
