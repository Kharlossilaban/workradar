-- ============================================
-- Workradar Database Security Verification
-- ============================================
-- Jalankan query ini di MySQL untuk verifikasi
-- implementasi keamanan database
-- ============================================

USE workradar;

-- ============================================
-- 1. VERIFIKASI STRUKTUR TABEL
-- ============================================

SELECT '=== 1. VERIFIKASI STRUKTUR TABEL ===' AS Section;

-- Cek kolom security di tabel users
SELECT '--- Users Table Security Columns ---' AS Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'workradar' 
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME IN (
    'failed_login_attempts', 
    'locked_until', 
    'mfa_enabled', 
    'mfa_secret',
    'password_changed_at',
    'encrypted_email',
    'encrypted_phone',
    'email_hash',
    'last_login_at',
    'last_login_ip'
  );

-- Cek tabel audit_logs
SELECT '--- Audit Logs Table ---' AS Info;
SELECT COUNT(*) as total_columns 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'workradar' AND TABLE_NAME = 'audit_logs';

-- Cek tabel security_events
SELECT '--- Security Events Table ---' AS Info;
SELECT COUNT(*) as total_columns 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'workradar' AND TABLE_NAME = 'security_events';

-- Cek tabel login_attempts
SELECT '--- Login Attempts Table ---' AS Info;
SELECT COUNT(*) as total_columns 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'workradar' AND TABLE_NAME = 'login_attempts';

-- Cek tabel blocked_ips
SELECT '--- Blocked IPs Table ---' AS Info;
SELECT COUNT(*) as total_columns 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'workradar' AND TABLE_NAME = 'blocked_ips';

-- ============================================
-- 2. VERIFIKASI DATA AUDIT
-- ============================================

SELECT '=== 2. VERIFIKASI DATA AUDIT ===' AS Section;

-- Total audit logs
SELECT '--- Audit Logs Summary ---' AS Info;
SELECT 
    COUNT(*) as total_logs,
    COUNT(DISTINCT action) as unique_actions,
    MIN(created_at) as first_log,
    MAX(created_at) as last_log
FROM audit_logs;

-- Audit actions breakdown
SELECT '--- Actions Breakdown ---' AS Info;
SELECT action, COUNT(*) as count
FROM audit_logs
GROUP BY action
ORDER BY count DESC
LIMIT 10;

-- ============================================
-- 3. VERIFIKASI SECURITY EVENTS
-- ============================================

SELECT '=== 3. VERIFIKASI SECURITY EVENTS ===' AS Section;

-- Security events summary
SELECT '--- Security Events Summary ---' AS Info;
SELECT 
    event_type,
    severity,
    COUNT(*) as count
FROM security_events
GROUP BY event_type, severity
ORDER BY count DESC;

-- Recent security events
SELECT '--- Recent Security Events (Last 10) ---' AS Info;
SELECT 
    id,
    event_type,
    severity,
    user_id,
    ip_address,
    created_at
FROM security_events
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 4. VERIFIKASI LOGIN ATTEMPTS
-- ============================================

SELECT '=== 4. VERIFIKASI LOGIN ATTEMPTS ===' AS Section;

-- Login attempts summary
SELECT '--- Login Attempts Summary ---' AS Info;
SELECT 
    COUNT(*) as total_attempts,
    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failed
FROM login_attempts;

-- Failed login by IP
SELECT '--- Top Failed Login IPs ---' AS Info;
SELECT 
    ip_address,
    COUNT(*) as failed_attempts
FROM login_attempts
WHERE success = 0
GROUP BY ip_address
ORDER BY failed_attempts DESC
LIMIT 5;

-- ============================================
-- 5. VERIFIKASI BLOCKED IPS
-- ============================================

SELECT '=== 5. VERIFIKASI BLOCKED IPS ===' AS Section;

-- Active blocked IPs
SELECT '--- Active Blocked IPs ---' AS Info;
SELECT 
    ip_address,
    reason,
    blocked_until,
    is_permanent,
    created_at
FROM blocked_ips
WHERE blocked_until > NOW() OR is_permanent = 1;

-- ============================================
-- 6. VERIFIKASI ACCOUNT LOCKOUT
-- ============================================

SELECT '=== 6. VERIFIKASI ACCOUNT LOCKOUT ===' AS Section;

-- Users with lockout status
SELECT '--- Users Lockout Status ---' AS Info;
SELECT 
    email,
    failed_login_attempts,
    locked_until,
    CASE 
        WHEN locked_until > NOW() THEN 'LOCKED'
        WHEN failed_login_attempts >= 5 THEN 'AT RISK'
        ELSE 'OK'
    END as status
FROM users
WHERE failed_login_attempts > 0 OR locked_until IS NOT NULL;

-- ============================================
-- 7. VERIFIKASI MFA STATUS
-- ============================================

SELECT '=== 7. VERIFIKASI MFA STATUS ===' AS Section;

-- MFA enabled users
SELECT '--- MFA Status Summary ---' AS Info;
SELECT 
    mfa_enabled,
    COUNT(*) as user_count
FROM users
GROUP BY mfa_enabled;

-- ============================================
-- 8. VERIFIKASI ENKRIPSI DATA
-- ============================================

SELECT '=== 8. VERIFIKASI ENKRIPSI DATA ===' AS Section;

-- Check encrypted fields (should show encrypted data, not plaintext)
SELECT '--- Encrypted Data Check ---' AS Info;
SELECT 
    id,
    email,
    CASE WHEN encrypted_email IS NOT NULL AND encrypted_email != '' THEN 'ENCRYPTED' ELSE 'NOT ENCRYPTED' END as email_status,
    CASE WHEN email_hash IS NOT NULL AND email_hash != '' THEN 'HASHED' ELSE 'NOT HASHED' END as hash_status,
    CASE WHEN encrypted_phone IS NOT NULL AND encrypted_phone != '' THEN 'ENCRYPTED' ELSE 'NOT ENCRYPTED' END as phone_status
FROM users
LIMIT 5;

-- ============================================
-- 9. VERIFIKASI DATABASE USERS (Jika dibuat)
-- ============================================

SELECT '=== 9. VERIFIKASI DATABASE USERS ===' AS Section;

-- Check MySQL users
SELECT '--- MySQL Users for Workradar ---' AS Info;
SELECT User, Host
FROM mysql.user
WHERE User LIKE 'workradar%';

-- ============================================
-- 10. VERIFIKASI VIEWS (Jika dibuat)
-- ============================================

SELECT '=== 10. VERIFIKASI SECURITY VIEWS ===' AS Section;

-- List views
SELECT '--- Available Views ---' AS Info;
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'workradar';

-- Test v_user_public_profiles (if exists)
-- SELECT * FROM v_user_public_profiles LIMIT 5;

-- ============================================
-- 11. VERIFIKASI STORED PROCEDURES (Jika dibuat)
-- ============================================

SELECT '=== 11. VERIFIKASI STORED PROCEDURES ===' AS Section;

-- List procedures
SELECT '--- Available Stored Procedures ---' AS Info;
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'workradar';

-- ============================================
-- 12. VERIFIKASI PASSWORD HISTORY
-- ============================================

SELECT '=== 12. VERIFIKASI PASSWORD HISTORY ===' AS Section;

-- Password history records
SELECT '--- Password History Summary ---' AS Info;
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as users_with_history
FROM password_histories;

-- ============================================
-- 13. STATISTIK KESELURUHAN
-- ============================================

SELECT '=== 13. STATISTIK KESELURUHAN ===' AS Section;

SELECT '--- Overall Security Statistics ---' AS Info;
SELECT 
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM users WHERE mfa_enabled = 1) as mfa_enabled_users,
    (SELECT COUNT(*) FROM users WHERE locked_until > NOW()) as locked_accounts,
    (SELECT COUNT(*) FROM audit_logs) as total_audit_logs,
    (SELECT COUNT(*) FROM security_events) as total_security_events,
    (SELECT COUNT(*) FROM login_attempts WHERE success = 0) as failed_logins,
    (SELECT COUNT(*) FROM blocked_ips WHERE blocked_until > NOW() OR is_permanent = 1) as active_blocked_ips;

-- ============================================
-- CLEANUP COMMANDS (Uncomment jika perlu)
-- ============================================

/*
-- Reset all lockouts
UPDATE users SET failed_login_attempts = 0, locked_until = NULL;

-- Clear blocked IPs
DELETE FROM blocked_ips;

-- Clear test users
DELETE FROM users WHERE email LIKE '%test%';

-- Clear audit logs (CAREFUL!)
-- DELETE FROM audit_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
*/

SELECT '=== VERIFICATION COMPLETE ===' AS Section;
