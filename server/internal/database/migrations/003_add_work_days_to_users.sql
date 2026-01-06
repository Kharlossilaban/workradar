-- Migration: Add work_days field to users table
-- This stores per-day work hours configuration as JSON

ALTER TABLE users ADD COLUMN work_days JSON DEFAULT NULL COMMENT 'Work hours configuration per day (Mon-Sun)';

-- Example JSON structure:
-- {
--   "0": {"start": "09:00", "end": "17:00", "is_work_day": true},  -- Monday
--   "1": {"start": "09:00", "end": "17:00", "is_work_day": true},  -- Tuesday
--   "2": {"start": "09:00", "end": "17:00", "is_work_day": true},  -- Wednesday
--   "3": {"start": "09:00", "end": "17:00", "is_work_day": true},  -- Thursday
--   "4": {"start": "09:00", "end": "17:00", "is_work_day": true},  -- Friday
--   "5": {"start": null, "end": null, "is_work_day": false},       -- Saturday
--   "6": {"start": null, "end": null, "is_work_day": false}        -- Sunday
-- }
