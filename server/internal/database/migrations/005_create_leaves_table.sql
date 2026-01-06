-- Migration: Create leaves table
-- Stores user leave/cuti records

CREATE TABLE IF NOT EXISTS leaves (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    date DATE NOT NULL,
    reason VARCHAR(255) NOT NULL,
    is_approved BOOLEAN DEFAULT FALSE,
    approved_by VARCHAR(36) NULL COMMENT 'Admin/manager who approved',
    approved_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    CONSTRAINT fk_leaves_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Index for faster queries
    INDEX idx_leaves_user_id (user_id),
    INDEX idx_leaves_date (date),
    INDEX idx_leaves_is_approved (is_approved)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
