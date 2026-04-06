-- Run once if profile photo PATCH returns "column does not exist"
-- (Normally added automatically by init_pg_schema in app.py / api.utils.database.)

ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_public_id TEXT;
