-- Find the user - try different searches
-- Search by email pattern
SELECT id, email, username, role, full_name 
FROM users 
WHERE email ILIKE '%nkosikhona%' OR email ILIKE '%ayabonga%';

-- Search by username pattern
SELECT id, email, username, role, full_name 
FROM users 
WHERE username ILIKE '%nkosikhona%' OR username ILIKE '%ayabonga%';

-- Or just list recent users
SELECT id, email, username, role, full_name, created_at
FROM users 
ORDER BY id DESC 
LIMIT 20;

