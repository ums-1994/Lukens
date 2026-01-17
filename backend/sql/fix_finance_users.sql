-- Fix finance manager users who were registered before the backend fix
-- This updates users who have 'manager' role but should be 'finance_manager'

-- Option 1: Update specific user by email
UPDATE users
SET role = 'finance_manager'
WHERE email = 'nkosikhonaayabonga@gmail.com';

-- Option 2: If you have a way to identify finance users (e.g., by department or name)
-- UPDATE users
-- SET role = 'finance_manager'
-- WHERE role = 'manager' 
--   AND (department ILIKE '%finance%' OR full_name ILIKE '%finance%');

-- Verify the update
SELECT id, email, username, role, full_name, department 
FROM users 
WHERE email = 'nkosikhonaayabonga@gmail.com';

-- Check all finance-related roles
SELECT id, email, username, role 
FROM users 
WHERE role IN ('finance_manager', 'financial_manager', 'finance manager', 'financial manager', 'finance')
ORDER BY role, email;

