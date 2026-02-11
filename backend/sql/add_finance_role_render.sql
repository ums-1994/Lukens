-- add_finance_role_render.sql
-- Run these commands in your psql session connected to Render database

-- 1) Standardize existing user roles to 'finance_manager'
UPDATE users
SET role = 'finance_manager'
WHERE LOWER(role) IN ('financial manager', 'finance manager', 'finance_manager', 'financial_manager');

-- 2) Standardize client records if clients.role uses free-text (cast ENUM to text for comparison)
UPDATE clients
SET role = 'Financial Manager'
WHERE LOWER(role::text) IN ('financial manager', 'finance manager', 'finance_manager', 'financial_manager');

-- 3) If clients use an ENUM type named client_role_enum, add 'Financial Manager' safely
DO $$
BEGIN
    IF EXISTS(SELECT 1 FROM pg_type WHERE typname = 'client_role_enum') THEN
        IF NOT EXISTS(
            SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = 'client_role_enum' AND e.enumlabel = 'Financial Manager'
        ) THEN
            ALTER TYPE client_role_enum ADD VALUE 'Financial Manager';
        END IF;
    END IF;
END$$;

-- 4) Verify the changes
SELECT DISTINCT role FROM users ORDER BY role;
SELECT DISTINCT role FROM clients ORDER BY role;

