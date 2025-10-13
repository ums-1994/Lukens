-- ===========================================================
-- 🗄️ Khonology Proposal System - Client Database Schema
-- ===========================================================
-- PostgreSQL Version
-- Author: Assistant
-- ===========================================================

-- 1️⃣ ENUM for Proposal Status
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

-- 2️⃣ ENUM for Client Role
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

-- 3️⃣ CLIENT TABLE
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    organization VARCHAR(150),
    role client_role_enum DEFAULT 'Client',
    token UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4️⃣ PROPOSALS TABLE
CREATE TABLE IF NOT EXISTS proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    content TEXT,
    pdf_path TEXT,
    status proposal_status_enum DEFAULT 'Draft',
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    created_by UUID, -- Internal user who created the proposal
    released_at TIMESTAMP,
    signed_at TIMESTAMP,
    signed_by VARCHAR(150),
    signature_data TEXT, -- Base64 encoded signature
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5️⃣ APPROVALS TABLE
CREATE TABLE IF NOT EXISTS approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    approver_name VARCHAR(150) NOT NULL,
    approver_email VARCHAR(150) NOT NULL,
    approved_pdf_path TEXT,
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    proposal_id UUID REFERENCES proposals(id) ON DELETE CASCADE
);

-- 6️⃣ CLIENT DASHBOARD TOKENS TABLE
CREATE TABLE IF NOT EXISTS client_dashboard_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token TEXT UNIQUE NOT NULL,
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    proposal_id UUID REFERENCES proposals(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7️⃣ PROPOSAL FEEDBACK TABLE
CREATE TABLE IF NOT EXISTS proposal_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proposal_id UUID REFERENCES proposals(id) ON DELETE CASCADE,
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    feedback_text TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8️⃣ INDEXES for performance
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_token ON clients(token);
CREATE INDEX IF NOT EXISTS idx_proposals_client_id ON proposals(client_id);
CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_approvals_proposal_id ON approvals(proposal_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_tokens_token ON client_dashboard_tokens(token);
CREATE INDEX IF NOT EXISTS idx_dashboard_tokens_expires ON client_dashboard_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_feedback_proposal_id ON proposal_feedback(proposal_id);

-- 9️⃣ SAMPLE DATA (for testing)
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
JOIN clients c ON p.client_id = c.id
WHERE c.role = 'Client';

CREATE OR REPLACE VIEW dashboard_stats_view AS
SELECT 
    COUNT(*) as total_proposals,
    COUNT(CASE WHEN status = 'Draft' THEN 1 END) as draft_count,
    COUNT(CASE WHEN status = 'In Review' THEN 1 END) as in_review_count,
    COUNT(CASE WHEN status = 'Released' THEN 1 END) as released_count,
    COUNT(CASE WHEN status = 'Approved' THEN 1 END) as approved_count,
    COUNT(CASE WHEN status = 'Signed' THEN 1 END) as signed_count
FROM proposals;
