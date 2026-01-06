-- Add google_id field to users table for Google OAuth integration
-- Migration: 006_add_google_id_to_users.sql

ALTER TABLE users 
ADD COLUMN google_id VARCHAR(255) NULL UNIQUE AFTER id,
ADD INDEX idx_google_id (google_id);
