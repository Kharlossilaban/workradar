-- Add fcm_token field to users table for Firebase Cloud Messaging
-- Migration: 007_add_fcm_token_to_users.sql

ALTER TABLE users 
ADD COLUMN fcm_token VARCHAR(255) NULL AFTER google_id,
ADD INDEX idx_fcm_token (fcm_token);
