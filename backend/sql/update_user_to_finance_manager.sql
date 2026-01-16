-- Update specific user to finance_manager role
-- Replace 'nkosikhonaayabonga@gmail.com' with the actual email if different

UPDATE users
SET role = 'finance_manager'
WHERE email = 'nkosikhonaayabonga@gmail.com';

-- Verify the update
SELECT id, email, role FROM users WHERE email = 'nkosikhonaayabonga@gmail.com';

