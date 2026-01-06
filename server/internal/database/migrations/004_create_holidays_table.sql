-- Migration: Create holidays table
-- Stores national and personal holidays

CREATE TABLE IF NOT EXISTS holidays (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NULL COMMENT 'NULL for national holidays, user ID for personal holidays',
    name VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    is_national BOOLEAN DEFAULT FALSE,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraint for user_id
    CONSTRAINT fk_holidays_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Index for faster queries
    INDEX idx_holidays_date (date),
    INDEX idx_holidays_user_id (user_id),
    INDEX idx_holidays_is_national (is_national)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert Indonesian national holidays for 2026-2027
INSERT INTO holidays (id, user_id, name, date, is_national, description) VALUES
-- 2026 Holidays
('holiday_2026_newyear', NULL, 'Tahun Baru Masehi 2026', '2026-01-01', TRUE, 'Perayaan Tahun Baru Masehi'),
('holiday_2026_cny', NULL, 'Tahun Baru Imlek 2577', '2026-02-17', TRUE, 'Tahun Baru Imlek'),
('holiday_2026_nyepi', NULL, 'Hari Suci Nyepi', '2026-03-19', TRUE, 'Tahun Baru Saka 1948'),
('holiday_2026_goodfriday', NULL, 'Wafat Yesus Kristus', '2026-04-03', TRUE, 'Jumat Agung'),
('holiday_2026_eidfitr1', NULL, 'Hari Raya Idul Fitri 1447 H', '2026-04-20', TRUE, 'Hari pertama Idul Fitri'),
('holiday_2026_eidfitr2', NULL, 'Hari Raya Idul Fitri 1447 H', '2026-04-21', TRUE, 'Hari kedua Idul Fitri'),
('holiday_2026_labor', NULL, 'Hari Buruh Internasional', '2026-05-01', TRUE, 'May Day'),
('holiday_2026_ascension', NULL, 'Kenaikan Yesus Kristus', '2026-05-14', TRUE, 'Ascension Day'),
('holiday_2026_vesak', NULL, 'Hari Raya Waisak 2570', '2026-06-01', TRUE, 'Waisak'),
('holiday_2026_pancasila', NULL, 'Hari Lahir Pancasila', '2026-06-01', TRUE, 'Pancasila Day'),
('holiday_2026_eidadha', NULL, 'Hari Raya Idul Adha 1447 H', '2026-06-27', TRUE, 'Idul Adha'),
('holiday_2026_muharram', NULL, 'Tahun Baru Islam 1448 H', '2026-07-18', TRUE, 'Islamic New Year'),
('holiday_2026_independence', NULL, 'Hari Kemerdekaan RI', '2026-08-17', TRUE, 'Indonesia Independence Day'),
('holiday_2026_mawlid', NULL, 'Maulid Nabi Muhammad SAW', '2026-09-26', TRUE, 'Prophet Muhammad\'s Birthday'),
('holiday_2026_christmas', NULL, 'Hari Raya Natal', '2026-12-25', TRUE, 'Christmas Day'),

-- 2027 Holidays
('holiday_2027_newyear', NULL, 'Tahun Baru Masehi 2027', '2027-01-01', TRUE, 'Perayaan Tahun Baru Masehi'),
('holiday_2027_cny', NULL, 'Tahun Baru Imlek 2578', '2027-02-06', TRUE, 'Tahun Baru Imlek'),
('holiday_2027_nyepi', NULL, 'Hari Suci Nyepi', '2027-03-09', TRUE, 'Tahun Baru Saka 1949'),
('holiday_2027_goodfriday', NULL, 'Wafat Yesus Kristus', '2027-03-26', TRUE, 'Jumat Agung'),
('holiday_2027_eidfitr1', NULL, 'Hari Raya Idul Fitri 1448 H', '2027-04-09', TRUE, 'Hari pertama Idul Fitri'),
('holiday_2027_eidfitr2', NULL, 'Hari Raya Idul Fitri 1448 H', '2027-04-10', TRUE, 'Hari kedua Idul Fitri'),
('holiday_2027_labor', NULL, 'Hari Buruh Internasional', '2027-05-01', TRUE, 'May Day'),
('holiday_2027_ascension', NULL, 'Kenaikan Yesus Kristus', '2027-05-06', TRUE, 'Ascension Day'),
('holiday_2027_vesak', NULL, 'Hari Raya Waisak 2571', '2027-05-20', TRUE, 'Waisak'),
('holiday_2027_pancasila', NULL, 'Hari Lahir Pancasila', '2027-06-01', TRUE, 'Pancasila Day'),
('holiday_2027_eidadha', NULL, 'Hari Raya Idul Adha 1448 H', '2027-06-16', TRUE, 'Idul Adha'),
('holiday_2027_muharram', NULL, 'Tahun Baru Islam 1449 H', '2027-07-07', TRUE, 'Islamic New Year'),
('holiday_2027_independence', NULL, 'Hari Kemerdekaan RI', '2027-08-17', TRUE, 'Indonesia Independence Day'),
('holiday_2027_mawlid', NULL, 'Maulid Nabi Muhammad SAW', '2027-09-15', TRUE, 'Prophet Muhammad\'s Birthday'),
('holiday_2027_christmas', NULL, 'Hari Raya Natal', '2027-12-25', TRUE, 'Christmas Day');
