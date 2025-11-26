-- ============================================================
-- FIX CLIENT EMAIL ROUTING - Add necessary columns and tables
-- ============================================================

-- Add client_email column to proposals table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'proposals' AND column_name = 'client_email'
    ) THEN
        ALTER TABLE proposals ADD COLUMN client_email VARCHAR(255);
        CREATE INDEX IF NOT EXISTS idx_proposals_client_email ON proposals(client_email);
    END IF;
END $$;

-- Add client_id column to proposals table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'proposals' AND column_name = 'client_id'
    ) THEN
        ALTER TABLE proposals ADD COLUMN client_id INTEGER;
    END IF;
END $$;

-- Add client_name column to proposals table if it doesn't exist (if using client instead)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'proposals' AND column_name = 'client_name'
    ) THEN
        -- Check if 'client' column exists, if so, we might want to keep both
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'proposals' AND column_name = 'client'
        ) THEN
            ALTER TABLE proposals ADD COLUMN client_name VARCHAR(500);
        ELSE
            ALTER TABLE proposals ADD COLUMN client_name VARCHAR(500);
        END IF;
    END IF;
END $$;

-- Create clients table if it doesn't exist
CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    industry VARCHAR(100),
    company_size VARCHAR(50),
    location VARCHAR(255),
    business_type VARCHAR(100),
    project_needs TEXT,
    budget_range VARCHAR(50),
    timeline VARCHAR(100),
    additional_info TEXT,
    status VARCHAR(50) DEFAULT 'active',
    onboarding_token VARCHAR(500),
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for clients table
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_company ON clients(company_name);
CREATE INDEX IF NOT EXISTS idx_clients_status ON clients(status);
CREATE INDEX IF NOT EXISTS idx_clients_created_by ON clients(created_by);
CREATE INDEX IF NOT EXISTS idx_clients_created_at ON clients(created_at DESC);

-- Add foreign key constraint for client_id in proposals if clients table exists and column exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clients') 
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'proposals' AND column_name = 'client_id')
       AND NOT EXISTS (
           SELECT 1 FROM information_schema.table_constraints 
           WHERE constraint_name = 'proposals_client_id_fkey'
       ) THEN
        ALTER TABLE proposals 
        ADD CONSTRAINT proposals_client_id_fkey 
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create client_proposals link table if it doesn't exist
CREATE TABLE IF NOT EXISTS client_proposals (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    proposal_id INTEGER NOT NULL,
    relationship_type VARCHAR(50) DEFAULT 'primary',
    linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    linked_by INTEGER NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (linked_by) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(client_id, proposal_id)
);

-- Create indexes for client_proposals table
CREATE INDEX IF NOT EXISTS idx_client_proposals_client ON client_proposals(client_id);
CREATE INDEX IF NOT EXISTS idx_client_proposals_proposal ON client_proposals(proposal_id);

-- Verify tables and columns exist
SELECT 
    'proposals.client_email' as check_item,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'proposals' AND column_name = 'client_email'
    ) THEN 'EXISTS' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'proposals.client_id' as check_item,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'proposals' AND column_name = 'client_id'
    ) THEN 'EXISTS' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'clients table' as check_item,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'clients'
    ) THEN 'EXISTS' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'client_proposals table' as check_item,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'client_proposals'
    ) THEN 'EXISTS' ELSE 'MISSING' END as status;


















