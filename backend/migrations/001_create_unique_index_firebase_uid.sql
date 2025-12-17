-- Migration: create unique index on users.firebase_uid to prevent duplicate links
-- Run this once after resolving any existing duplicates.

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_firebase_uid ON users (firebase_uid);
