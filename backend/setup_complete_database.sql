-- ===========================================================
-- 🗄️ Khonology Proposal System - COMPLETE Database Setup
-- ===========================================================
-- Run this script in pgAdmin to set up everything
-- ===========================================================

-- 1️⃣ Create Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'Financial Manager',
    department VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    is_email_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2️⃣ Create Proposals Table
CREATE TABLE IF NOT EXISTS proposals (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    client_name VARCHAR(500) NOT NULL,
    user_id INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'Draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    template_key VARCHAR(255),
    content TEXT,
    sections TEXT,
    pdf_url TEXT,
    client_can_edit BOOLEAN DEFAULT false,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 3️⃣ Create Content Library Table
CREATE TABLE IF NOT EXISTS content (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    label VARCHAR(500) NOT NULL,
    content TEXT,
    category VARCHAR(100) DEFAULT 'Templates',
    is_folder BOOLEAN DEFAULT false,
    parent_id INTEGER,
    public_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT false,
    FOREIGN KEY (parent_id) REFERENCES content(id) ON DELETE CASCADE
);

-- 4️⃣ Create Settings Table
CREATE TABLE IF NOT EXISTS settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5️⃣ Create Proposal Versions Table
CREATE TABLE IF NOT EXISTS proposal_versions (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER NOT NULL,
    version_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- 6️⃣ Create Document Comments Table
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
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
);

-- 7️⃣ Create Collaboration Invitations Table
CREATE TABLE IF NOT EXISTS collaboration_invitations (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER NOT NULL,
    inviter_id INTEGER NOT NULL,
    invitee_email VARCHAR(255) NOT NULL,
    token VARCHAR(500) UNIQUE NOT NULL,
    permission_level VARCHAR(50) DEFAULT 'view',
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    accepted_at TIMESTAMP,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (inviter_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 8️⃣ Create Collaboration Sessions Table
CREATE TABLE IF NOT EXISTS collaboration_sessions (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER NOT NULL,
    user_id INTEGER,
    guest_email VARCHAR(255),
    permission_level VARCHAR(50) DEFAULT 'view',
    last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 9️⃣ ENUM for Client Role
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

-- 🔟 Create Clients Table
CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    organization VARCHAR(150),
    role client_role_enum DEFAULT 'Client',
    token UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add client_id to proposals if not exists
ALTER TABLE proposals 
ADD COLUMN IF NOT EXISTS client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL;

-- Add signature fields to proposals
ALTER TABLE proposals 
ADD COLUMN IF NOT EXISTS released_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS signed_by VARCHAR(150),
ADD COLUMN IF NOT EXISTS signature_data TEXT;

-- 1️⃣1️⃣ Create Approvals Table
CREATE TABLE IF NOT EXISTS approvals (
    id SERIAL PRIMARY KEY,
    approver_name VARCHAR(150) NOT NULL,
    approver_email VARCHAR(150) NOT NULL,
    approved_pdf_path TEXT,
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE CASCADE
);

-- 1️⃣2️⃣ Create Client Dashboard Tokens Table
CREATE TABLE IF NOT EXISTS client_dashboard_tokens (
    id SERIAL PRIMARY KEY,
    token TEXT UNIQUE NOT NULL,
    client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1️⃣3️⃣ Create Proposal Feedback Table
CREATE TABLE IF NOT EXISTS proposal_feedback (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE CASCADE,
    client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
    feedback_text TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1️⃣4️⃣ CREATE INDEXES for Performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_proposals_user_id ON proposals(user_id);
CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_proposals_client_id ON proposals(client_id);
CREATE INDEX IF NOT EXISTS idx_content_key ON content(key);
CREATE INDEX IF NOT EXISTS idx_content_category ON content(category);
CREATE INDEX IF NOT EXISTS idx_comments_proposal_id ON document_comments(proposal_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_by ON document_comments(created_by);
CREATE INDEX IF NOT EXISTS idx_collab_invitation_token ON collaboration_invitations(token);
CREATE INDEX IF NOT EXISTS idx_collab_invitation_proposal ON collaboration_invitations(proposal_id);
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_token ON clients(token);
CREATE INDEX IF NOT EXISTS idx_approvals_proposal_id ON approvals(proposal_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_tokens_token ON client_dashboard_tokens(token);
CREATE INDEX IF NOT EXISTS idx_feedback_proposal_id ON proposal_feedback(proposal_id);

-- 1️⃣5️⃣ CREATE AUTO-UPDATE TRIGGERS
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_proposals_updated_at
    BEFORE UPDATE ON proposals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_content_updated_at
    BEFORE UPDATE ON content
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_settings_updated_at
    BEFORE UPDATE ON settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_clients_updated_at
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 1️⃣6️⃣ INSERT SAMPLE DATA (Optional - for testing)

-- Create test users with different roles
INSERT INTO users (username, email, password_hash, full_name, role) VALUES 
('admin', 'admin@khonology.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIxKCerina', 'Admin User', 'Admin'),
('ceo', 'ceo@khonology.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIxKCerina', 'CEO User', 'CEO'),
('financial', 'financial@khonology.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIxKCerina', 'Financial Manager', 'Financial Manager')
ON CONFLICT (email) DO NOTHING;

-- Note: All test users have password: "password123"

-- Create test clients
INSERT INTO clients (name, email, organization, role) VALUES 
('Jane Doe', 'jane.doe@example.com', 'Acme Corp', 'Client'),
('John Smith', 'john.smith@techcorp.com', 'Tech Corp', 'Client')
ON CONFLICT (email) DO NOTHING;

-- 1️⃣7️⃣ CREATE VIEWS for Common Queries
CREATE OR REPLACE VIEW dashboard_stats_view AS
SELECT 
    COUNT(*) as total_proposals,
    COUNT(CASE WHEN status = 'Draft' THEN 1 END) as draft_count,
    COUNT(CASE WHEN status = 'Pending CEO Approval' THEN 1 END) as pending_approval_count,
    COUNT(CASE WHEN status = 'Sent to Client' THEN 1 END) as sent_to_client_count,
    COUNT(CASE WHEN status = 'Signed' THEN 1 END) as signed_count
FROM proposals;

CREATE OR REPLACE VIEW user_proposals_view AS
SELECT 
    p.id,
    p.title,
    p.client_name,
    p.status,
    p.created_at,
    p.updated_at,
    u.full_name as owner_name,
    u.email as owner_email
FROM proposals p
JOIN users u ON p.user_id = u.id
WHERE p.status IS NOT NULL;

-- ✅ SETUP COMPLETE!
-- You can now start your Flask backend

