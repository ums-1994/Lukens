-- add_finance_role_local_fix.sql
-- Safely add 'Financial Manager' to client_role_enum and update clients/users

-- 1) Add enum value 'Financial Manager' if missing
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

-- 2) Update clients with text-like matches (cast enum to text for comparison)
UPDATE clients
SET role = 'Financial Manager'
WHERE role::text ILIKE ANY (ARRAY['%financial manager%','%finance manager%','%financial_manager%','%finance_manager%']);

-- 3) Update users table (varchar role column) to standardized 'finance_manager'
UPDATE users
SET role = 'finance_manager'
WHERE LOWER(role) IN ('financial manager', 'finance manager', 'finance_manager', 'financial_manager');

-- 4) Optional: verify (selects for manual inspection)
-- SELECT DISTINCT role FROM clients;
-- SELECT DISTINCT role FROM users;
