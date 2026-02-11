-- Check for user ID 266 (from backend logs)
SELECT id, email, username, role, full_name, created_at
FROM users 
WHERE id = 266;

-- Get the highest user ID to see what's the latest
SELECT MAX(id) as max_id, COUNT(*) as total_users FROM users;

-- List ALL users ordered by ID (to see if 266 exists)
SELECT id, email, username, role, full_name, created_at
FROM users 
ORDER BY id DESC;

-- Check if there are any users created recently (today)
SELECT id, email, username, role, full_name, created_at
FROM users 
WHERE created_at >= CURRENT_DATE
ORDER BY id DESC;

