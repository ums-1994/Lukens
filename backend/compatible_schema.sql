-- ===========================================================
-- 🗄️ KhonoPro Proposal System - Compatible Schema
-- ===========================================================
-- Works with existing proposals table (integer IDs)
-- ===========================================================

-- 1️⃣ ENUM for Client Role
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_role_enum') THEN
        CREATE TYPE client_role_enum AS ENUM (
            'Client',
            'Approver',
            'Admin'
        );
    END IF;
END$$;

-- 2️⃣ ENUM for Proposal Status (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proposal_status_enum') THEN
        CREATE TYPE proposal_status_enum AS ENUM (
            'Draft',
            'In Review',
            'Released',
            'Approved',
            'Signed',
            'Archived'
        );
    END IF;
END$$;

-- 3️⃣ CLIENTS TABLE (new)
CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    organization VARCHAR(150),
    region VARCHAR(80),
    role client_role_enum DEFAULT 'Client',
    token UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4️⃣ Update existing proposals table to add client_id
ALTER TABLE proposals 
ADD COLUMN IF NOT EXISTS client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL;

-- 5️⃣ Update proposals table to add new columns
ALTER TABLE proposals 
ADD COLUMN IF NOT EXISTS released_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS signed_by VARCHAR(150),
ADD COLUMN IF NOT EXISTS signature_data TEXT;

-- 6️⃣ APPROVALS TABLE
CREATE TABLE IF NOT EXISTS approvals (
    id SERIAL PRIMARY KEY,
    approver_name VARCHAR(150) NOT NULL,
    approver_email VARCHAR(150) NOT NULL,
    approved_pdf_path TEXT,
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE CASCADE
);

-- 7️⃣ CLIENT DASHBOARD TOKENS TABLE
CREATE TABLE IF NOT EXISTS client_dashboard_tokens (
    id SERIAL PRIMARY KEY,
    token TEXT UNIQUE NOT NULL,
    client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8️⃣ PROPOSAL FEEDBACK TABLE
CREATE TABLE IF NOT EXISTS proposal_feedback (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE CASCADE,
    client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
    feedback_text TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9️⃣ INDEXES for performance
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_token ON clients(token);
CREATE INDEX IF NOT EXISTS idx_proposals_client_id ON proposals(client_id);
CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_approvals_proposal_id ON approvals(proposal_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_tokens_token ON client_dashboard_tokens(token);
CREATE INDEX IF NOT EXISTS idx_dashboard_tokens_expires ON client_dashboard_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_feedback_proposal_id ON proposal_feedback(proposal_id);

-- 🔟 SAMPLE DATA (for testing)
INSERT INTO clients (name, email, organization, role) VALUES 
('Jane Doe', 'jane.doe@example.com', 'Acme Corp', 'Client'),
('John Smith', 'john.smith@techcorp.com', 'Tech Corp', 'Client'),
('Admin User', 'admin@khonology.com', 'Khonology', 'Admin')
ON CONFLICT (email) DO NOTHING;

-- 🔟 AUTO-UPDATE TRIGGERS
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_clients_updated_at
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_proposals_updated_at
    BEFORE UPDATE ON proposals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 🔟 VIEWS for common queries
CREATE OR REPLACE VIEW client_proposals_view AS
SELECT 
    p.id,
    p.title,
    p.status,
    p.created_at,
    p.released_at,
    p.signed_at,
    c.name as client_name,
    c.email as client_email,
    c.organization
FROM proposals p
LEFT JOIN clients c ON p.client_id = c.id
WHERE c.role = 'Client' OR c.role IS NULL;

CREATE OR REPLACE VIEW dashboard_stats_view AS
SELECT 
    COUNT(*) as total_proposals,
    COUNT(CASE WHEN status = 'Draft' THEN 1 END) as draft_count,
    COUNT(CASE WHEN status = 'In Review' THEN 1 END) as in_review_count,
    COUNT(CASE WHEN status = 'Released' THEN 1 END) as released_count,
    COUNT(CASE WHEN status = 'Approved' THEN 1 END) as approved_count,
    COUNT(CASE WHEN status = 'Signed' THEN 1 END) as signed_count
FROM proposals;
