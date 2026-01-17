-- First, let's find all users to see what's in the database
SELECT id, email, username, role, full_name 
FROM users 
ORDER BY id DESC 
LIMIT 10;

-- Then update the user (replace with actual email from above query)
-- UPDATE users
-- SET role = 'finance_manager'
-- WHERE email = 'actual-email@example.com';

-- Or update by username if email doesn't match
-- UPDATE users
-- SET role = 'finance_manager'
-- WHERE username = 'nkosikhonaayabonga';

-- Verify after update
-- SELECT id, email, username, role FROM users WHERE role = 'finance_manager';

