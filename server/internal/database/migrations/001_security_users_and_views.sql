-- ============================================
-- MINGGU 5: Access Control & Privilege Management
-- Database Security Migrations
-- ============================================

-- ============================================
-- 1. CREATE DATABASE USERS WITH DIFFERENT ROLES
-- ============================================

-- Drop users if exist (for re-run)
DROP USER IF EXISTS 'workradar_read'@'localhost';
DROP USER IF EXISTS 'workradar_read'@'%';
DROP USER IF EXISTS 'workradar_app'@'localhost';
DROP USER IF EXISTS 'workradar_app'@'%';
DROP USER IF EXISTS 'workradar_admin'@'localhost';
DROP USER IF EXISTS 'workradar_admin'@'%';

-- Read-Only User (untuk reporting/analytics)
-- Hanya bisa SELECT, tidak bisa modify data
CREATE USER 'workradar_read'@'localhost' IDENTIFIED BY 'WorkRadar_Read_2024!';
CREATE USER 'workradar_read'@'%' IDENTIFIED BY 'WorkRadar_Read_2024!';

GRANT SELECT ON workradar.* TO 'workradar_read'@'localhost';
GRANT SELECT ON workradar.* TO 'workradar_read'@'%';

-- Revoke access to sensitive columns for read user
-- Read user tidak boleh lihat password_hash, mfa_secret, encrypted fields
REVOKE SELECT ON workradar.users FROM 'workradar_read'@'localhost';
REVOKE SELECT ON workradar.users FROM 'workradar_read'@'%';

-- Grant select only on non-sensitive columns
GRANT SELECT (id, email, username, profile_picture, auth_provider, user_type, 
              vip_expires_at, work_days, mfa_enabled, created_at, updated_at) 
ON workradar.users TO 'workradar_read'@'localhost';
GRANT SELECT (id, email, username, profile_picture, auth_provider, user_type, 
              vip_expires_at, work_days, mfa_enabled, created_at, updated_at) 
ON workradar.users TO 'workradar_read'@'%';

-- Application User (untuk operasi normal aplikasi)
-- Bisa SELECT, INSERT, UPDATE - TIDAK BISA DELETE
CREATE USER 'workradar_app'@'localhost' IDENTIFIED BY 'WorkRadar_App_2024!';
CREATE USER 'workradar_app'@'%' IDENTIFIED BY 'WorkRadar_App_2024!';

GRANT SELECT, INSERT, UPDATE ON workradar.* TO 'workradar_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON workradar.* TO 'workradar_app'@'%';

-- Revoke sensitive column updates for app user
REVOKE UPDATE (user_type) ON workradar.users FROM 'workradar_app'@'localhost';
REVOKE UPDATE (user_type) ON workradar.users FROM 'workradar_app'@'%';

-- Grant DELETE only on specific tables (not users)
GRANT DELETE ON workradar.tasks TO 'workradar_app'@'localhost';
GRANT DELETE ON workradar.tasks TO 'workradar_app'@'%';
GRANT DELETE ON workradar.categories TO 'workradar_app'@'localhost';
GRANT DELETE ON workradar.categories TO 'workradar_app'@'%';
GRANT DELETE ON workradar.bot_messages TO 'workradar_app'@'localhost';
GRANT DELETE ON workradar.bot_messages TO 'workradar_app'@'%';
GRANT DELETE ON workradar.leaves TO 'workradar_app'@'localhost';
GRANT DELETE ON workradar.leaves TO 'workradar_app'@'%';
GRANT DELETE ON workradar.holidays TO 'workradar_app'@'localhost';
GRANT DELETE ON workradar.holidays TO 'workradar_app'@'%';
GRANT DELETE ON workradar.chat_messages TO 'workradar_app'@'localhost';
GRANT DELETE ON workradar.chat_messages TO 'workradar_app'@'%';

-- Grant EXECUTE for stored procedures
GRANT EXECUTE ON workradar.* TO 'workradar_app'@'localhost';
GRANT EXECUTE ON workradar.* TO 'workradar_app'@'%';

-- Admin User (untuk migrations & maintenance)
-- Full privileges
CREATE USER 'workradar_admin'@'localhost' IDENTIFIED BY 'WorkRadar_Admin_2024!';
CREATE USER 'workradar_admin'@'%' IDENTIFIED BY 'WorkRadar_Admin_2024!';

GRANT ALL PRIVILEGES ON workradar.* TO 'workradar_admin'@'localhost';
GRANT ALL PRIVILEGES ON workradar.* TO 'workradar_admin'@'%';

FLUSH PRIVILEGES;

-- ============================================
-- 2. CREATE SECURITY VIEWS
-- ============================================

-- View untuk public user profile (hide sensitive info)
DROP VIEW IF EXISTS v_user_public_profiles;
CREATE VIEW v_user_public_profiles AS
SELECT 
    id,
    username,
    CONCAT(LEFT(email, 3), '***@', SUBSTRING_INDEX(email, '@', -1)) as email_masked,
    profile_picture,
    auth_provider,
    user_type,
    mfa_enabled,
    created_at
FROM users;

-- View untuk user dashboard (safe untuk display)
DROP VIEW IF EXISTS v_user_dashboard;
CREATE VIEW v_user_dashboard AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.profile_picture,
    u.user_type,
    u.vip_expires_at,
    u.mfa_enabled,
    u.last_login_at,
    COUNT(DISTINCT t.id) as total_tasks,
    COUNT(DISTINCT CASE WHEN t.is_completed = 1 THEN t.id END) as completed_tasks,
    COUNT(DISTINCT c.id) as total_categories
FROM users u
LEFT JOIN tasks t ON u.id = t.user_id
LEFT JOIN categories c ON u.id = c.user_id
GROUP BY u.id;

-- View untuk task summary (hide user details)
DROP VIEW IF EXISTS v_task_summaries;
CREATE VIEW v_task_summaries AS
SELECT 
    t.id,
    t.title,
    t.priority,
    t.is_completed,
    t.date,
    t.start_time,
    t.end_time,
    t.user_id,
    c.name as category_name,
    c.color as category_color
FROM tasks t
LEFT JOIN categories c ON t.category_id = c.id;

-- View untuk audit logs (untuk reporting)
DROP VIEW IF EXISTS v_audit_logs_summary;
CREATE VIEW v_audit_logs_summary AS
SELECT 
    al.id,
    al.action,
    al.table_name,
    al.record_id,
    al.ip_address,
    al.created_at,
    u.username as user_name,
    CONCAT(LEFT(u.email, 3), '***@', SUBSTRING_INDEX(u.email, '@', -1)) as user_email_masked
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.id;

-- View untuk security events dashboard
DROP VIEW IF EXISTS v_security_events_dashboard;
CREATE VIEW v_security_events_dashboard AS
SELECT 
    DATE(created_at) as event_date,
    event_type,
    severity,
    COUNT(*) as event_count
FROM security_events
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(created_at), event_type, severity
ORDER BY event_date DESC, event_count DESC;

-- View untuk blocked IPs summary
DROP VIEW IF EXISTS v_blocked_ips_active;
CREATE VIEW v_blocked_ips_active AS
SELECT 
    ip_address,
    reason,
    blocked_at,
    expires_at,
    TIMESTAMPDIFF(MINUTE, NOW(), expires_at) as minutes_remaining
FROM blocked_ips
WHERE expires_at > NOW() OR expires_at IS NULL;

-- View untuk subscription status
DROP VIEW IF EXISTS v_subscription_status;
CREATE VIEW v_subscription_status AS
SELECT 
    s.id,
    s.user_id,
    u.username,
    CONCAT(LEFT(u.email, 3), '***@', SUBSTRING_INDEX(u.email, '@', -1)) as email_masked,
    s.plan_type,
    s.status,
    s.started_at,
    s.expires_at,
    CASE 
        WHEN s.expires_at < NOW() THEN 'expired'
        WHEN s.expires_at < DATE_ADD(NOW(), INTERVAL 7 DAY) THEN 'expiring_soon'
        ELSE 'active'
    END as subscription_health
FROM subscriptions s
JOIN users u ON s.user_id = u.id;

-- View untuk payment history (sanitized)
DROP VIEW IF EXISTS v_payment_history;
CREATE VIEW v_payment_history AS
SELECT 
    t.id,
    t.order_id,
    t.user_id,
    u.username,
    t.amount,
    t.status,
    t.payment_type,
    t.created_at,
    t.updated_at
FROM transactions t
JOIN users u ON t.user_id = u.id;

-- ============================================
-- 3. CREATE STORED PROCEDURES
-- ============================================

-- Procedure untuk safe password change
DROP PROCEDURE IF EXISTS sp_change_password;
DELIMITER $$
CREATE PROCEDURE sp_change_password(
    IN p_user_id VARCHAR(36),
    IN p_new_password_hash VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_user_exists INT;
    DECLARE v_old_hash VARCHAR(255);
    
    -- Check if user exists
    SELECT COUNT(*), password_hash INTO v_user_exists, v_old_hash 
    FROM users WHERE id = p_user_id;
    
    IF v_user_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        -- Update password
        UPDATE users 
        SET password_hash = p_new_password_hash,
            password_changed_at = NOW(),
            failed_login_attempts = 0,
            locked_until = NULL
        WHERE id = p_user_id;
        
        -- Log to password history
        INSERT INTO password_histories (user_id, password_hash, created_at)
        VALUES (p_user_id, v_old_hash, NOW());
        
        SET p_success = TRUE;
        SET p_message = 'Password changed successfully';
    END IF;
END$$
DELIMITER ;

-- Procedure untuk upgrade user ke VIP
DROP PROCEDURE IF EXISTS sp_upgrade_to_vip;
DELIMITER $$
CREATE PROCEDURE sp_upgrade_to_vip(
    IN p_user_id VARCHAR(36),
    IN p_duration_days INT,
    IN p_admin_user_id VARCHAR(36),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_user_exists INT;
    DECLARE v_current_type VARCHAR(20);
    DECLARE v_new_expiry DATETIME;
    
    -- Check if user exists
    SELECT COUNT(*), user_type INTO v_user_exists, v_current_type 
    FROM users WHERE id = p_user_id;
    
    IF v_user_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        -- Calculate new expiry
        SET v_new_expiry = DATE_ADD(NOW(), INTERVAL p_duration_days DAY);
        
        -- Update user type
        UPDATE users 
        SET user_type = 'vip',
            vip_expires_at = v_new_expiry
        WHERE id = p_user_id;
        
        -- Log audit
        INSERT INTO audit_logs (user_id, action, table_name, record_id, new_value, created_at)
        VALUES (p_admin_user_id, 'UPGRADE_VIP', 'users', p_user_id, 
                CONCAT('{"user_type":"vip","vip_expires_at":"', v_new_expiry, '"}'), NOW());
        
        SET p_success = TRUE;
        SET p_message = CONCAT('User upgraded to VIP until ', v_new_expiry);
    END IF;
END$$
DELIMITER ;

-- Procedure untuk lock account (admin action)
DROP PROCEDURE IF EXISTS sp_lock_account;
DELIMITER $$
CREATE PROCEDURE sp_lock_account(
    IN p_user_id VARCHAR(36),
    IN p_reason VARCHAR(255),
    IN p_duration_minutes INT,
    IN p_admin_user_id VARCHAR(36),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_user_exists INT;
    DECLARE v_lock_until DATETIME;
    
    SELECT COUNT(*) INTO v_user_exists FROM users WHERE id = p_user_id;
    
    IF v_user_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        SET v_lock_until = DATE_ADD(NOW(), INTERVAL p_duration_minutes MINUTE);
        
        UPDATE users 
        SET locked_until = v_lock_until
        WHERE id = p_user_id;
        
        -- Log security event
        INSERT INTO security_events (event_type, severity, user_id, details, created_at)
        VALUES ('ACCOUNT_LOCKED_ADMIN', 'HIGH', p_user_id, 
                CONCAT('{"reason":"', p_reason, '","locked_by":"', p_admin_user_id, 
                       '","locked_until":"', v_lock_until, '"}'), NOW());
        
        SET p_success = TRUE;
        SET p_message = CONCAT('Account locked until ', v_lock_until);
    END IF;
END$$
DELIMITER ;

-- Procedure untuk unlock account
DROP PROCEDURE IF EXISTS sp_unlock_account;
DELIMITER $$
CREATE PROCEDURE sp_unlock_account(
    IN p_user_id VARCHAR(36),
    IN p_admin_user_id VARCHAR(36),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_user_exists INT;
    
    SELECT COUNT(*) INTO v_user_exists FROM users WHERE id = p_user_id;
    
    IF v_user_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        UPDATE users 
        SET locked_until = NULL,
            failed_login_attempts = 0
        WHERE id = p_user_id;
        
        -- Log security event
        INSERT INTO security_events (event_type, severity, user_id, details, created_at)
        VALUES ('ACCOUNT_UNLOCKED', 'INFO', p_user_id, 
                CONCAT('{"unlocked_by":"', p_admin_user_id, '"}'), NOW());
        
        SET p_success = TRUE;
        SET p_message = 'Account unlocked successfully';
    END IF;
END$$
DELIMITER ;

-- Procedure untuk soft delete user (GDPR compliance)
DROP PROCEDURE IF EXISTS sp_soft_delete_user;
DELIMITER $$
CREATE PROCEDURE sp_soft_delete_user(
    IN p_user_id VARCHAR(36),
    IN p_admin_user_id VARCHAR(36),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_user_exists INT;
    DECLARE v_email VARCHAR(255);
    
    SELECT COUNT(*), email INTO v_user_exists, v_email 
    FROM users WHERE id = p_user_id;
    
    IF v_user_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        -- Anonymize user data instead of hard delete
        UPDATE users 
        SET email = CONCAT('deleted_', p_user_id, '@deleted.local'),
            username = CONCAT('deleted_user_', LEFT(p_user_id, 8)),
            password_hash = '',
            profile_picture = NULL,
            google_id = NULL,
            fcm_token = NULL,
            mfa_enabled = FALSE,
            mfa_secret = NULL,
            encrypted_email = NULL,
            encrypted_phone = NULL,
            email_hash = NULL,
            phone = NULL
        WHERE id = p_user_id;
        
        -- Log audit
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_value, created_at)
        VALUES (p_admin_user_id, 'SOFT_DELETE', 'users', p_user_id, 
                CONCAT('{"original_email":"', LEFT(v_email, 3), '***"}'), NOW());
        
        SET p_success = TRUE;
        SET p_message = 'User data anonymized successfully';
    END IF;
END$$
DELIMITER ;

-- Procedure untuk get user security status
DROP PROCEDURE IF EXISTS sp_get_user_security_status;
DELIMITER $$
CREATE PROCEDURE sp_get_user_security_status(
    IN p_user_id VARCHAR(36)
)
BEGIN
    SELECT 
        u.id,
        u.username,
        u.mfa_enabled,
        u.failed_login_attempts,
        u.locked_until,
        u.password_changed_at,
        u.last_login_at,
        u.last_login_ip,
        CASE 
            WHEN u.locked_until > NOW() THEN 'LOCKED'
            WHEN u.failed_login_attempts >= 3 THEN 'AT_RISK'
            WHEN u.mfa_enabled = FALSE THEN 'MFA_DISABLED'
            WHEN u.password_changed_at < DATE_SUB(NOW(), INTERVAL 60 DAY) THEN 'PASSWORD_EXPIRED'
            ELSE 'SECURE'
        END as security_status,
        (SELECT COUNT(*) FROM security_events WHERE user_id = p_user_id 
         AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)) as recent_security_events,
        (SELECT COUNT(*) FROM audit_logs WHERE user_id = p_user_id 
         AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)) as recent_activities
    FROM users u
    WHERE u.id = p_user_id;
END$$
DELIMITER ;

-- Procedure untuk cleanup expired sessions/tokens
DROP PROCEDURE IF EXISTS sp_cleanup_expired_data;
DELIMITER $$
CREATE PROCEDURE sp_cleanup_expired_data()
BEGIN
    DECLARE v_blocked_deleted INT DEFAULT 0;
    DECLARE v_resets_deleted INT DEFAULT 0;
    
    -- Clean expired blocked IPs
    DELETE FROM blocked_ips WHERE expires_at < NOW();
    SET v_blocked_deleted = ROW_COUNT();
    
    -- Clean expired password resets
    DELETE FROM password_resets WHERE expires_at < NOW();
    SET v_resets_deleted = ROW_COUNT();
    
    -- Log cleanup
    INSERT INTO audit_logs (action, table_name, new_value, created_at)
    VALUES ('CLEANUP', 'system', 
            CONCAT('{"blocked_ips_deleted":', v_blocked_deleted, 
                   ',"password_resets_deleted":', v_resets_deleted, '}'), NOW());
    
    SELECT v_blocked_deleted as blocked_ips_cleaned, 
           v_resets_deleted as password_resets_cleaned;
END$$
DELIMITER ;

-- ============================================
-- 4. CREATE TRIGGERS FOR AUDIT
-- ============================================

-- Trigger untuk auto-log user updates
DROP TRIGGER IF EXISTS tr_users_after_update;
DELIMITER $$
CREATE TRIGGER tr_users_after_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    -- Only log significant changes
    IF OLD.user_type != NEW.user_type 
       OR OLD.mfa_enabled != NEW.mfa_enabled 
       OR OLD.locked_until != NEW.locked_until THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_value, new_value, created_at)
        VALUES (NEW.id, 'UPDATE', 'users', NEW.id,
                CONCAT('{"user_type":"', OLD.user_type, '","mfa_enabled":', OLD.mfa_enabled, 
                       ',"locked_until":"', IFNULL(OLD.locked_until, 'null'), '"}'),
                CONCAT('{"user_type":"', NEW.user_type, '","mfa_enabled":', NEW.mfa_enabled, 
                       ',"locked_until":"', IFNULL(NEW.locked_until, 'null'), '"}'),
                NOW());
    END IF;
END$$
DELIMITER ;

-- Trigger untuk log failed login attempts
DROP TRIGGER IF EXISTS tr_users_failed_login;
DELIMITER $$
CREATE TRIGGER tr_users_failed_login
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF NEW.failed_login_attempts > OLD.failed_login_attempts THEN
        INSERT INTO security_events (event_type, severity, user_id, details, created_at)
        VALUES ('FAILED_LOGIN_ATTEMPT', 
                CASE WHEN NEW.failed_login_attempts >= 5 THEN 'HIGH' ELSE 'WARNING' END,
                NEW.id, 
                CONCAT('{"attempts":', NEW.failed_login_attempts, '}'),
                NOW());
    END IF;
END$$
DELIMITER ;

-- ============================================
-- 5. GRANT VIEW ACCESS
-- ============================================

-- Read user can access views
GRANT SELECT ON workradar.v_user_public_profiles TO 'workradar_read'@'localhost';
GRANT SELECT ON workradar.v_user_public_profiles TO 'workradar_read'@'%';
GRANT SELECT ON workradar.v_task_summaries TO 'workradar_read'@'localhost';
GRANT SELECT ON workradar.v_task_summaries TO 'workradar_read'@'%';
GRANT SELECT ON workradar.v_audit_logs_summary TO 'workradar_read'@'localhost';
GRANT SELECT ON workradar.v_audit_logs_summary TO 'workradar_read'@'%';
GRANT SELECT ON workradar.v_security_events_dashboard TO 'workradar_read'@'localhost';
GRANT SELECT ON workradar.v_security_events_dashboard TO 'workradar_read'@'%';

-- App user can access all views
GRANT SELECT ON workradar.v_user_public_profiles TO 'workradar_app'@'localhost';
GRANT SELECT ON workradar.v_user_public_profiles TO 'workradar_app'@'%';
GRANT SELECT ON workradar.v_user_dashboard TO 'workradar_app'@'localhost';
GRANT SELECT ON workradar.v_user_dashboard TO 'workradar_app'@'%';
GRANT SELECT ON workradar.v_task_summaries TO 'workradar_app'@'localhost';
GRANT SELECT ON workradar.v_task_summaries TO 'workradar_app'@'%';
GRANT SELECT ON workradar.v_subscription_status TO 'workradar_app'@'localhost';
GRANT SELECT ON workradar.v_subscription_status TO 'workradar_app'@'%';
GRANT SELECT ON workradar.v_payment_history TO 'workradar_app'@'localhost';
GRANT SELECT ON workradar.v_payment_history TO 'workradar_app'@'%';

FLUSH PRIVILEGES;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify setup:
-- SHOW GRANTS FOR 'workradar_read'@'localhost';
-- SHOW GRANTS FOR 'workradar_app'@'localhost';
-- SHOW GRANTS FOR 'workradar_admin'@'localhost';
-- SELECT * FROM information_schema.views WHERE table_schema = 'workradar';
-- SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema = 'workradar';
