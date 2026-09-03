-- ================================================================
-- SMART ZERO WASTE CITY - Complete Database Schema
-- ================================================================
-- 
-- Database: if0_42329659_db_SZWC
-- Host: sql311.infinityfree.com
-- User: if0_42329659
-- ================================================================

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(50) NOT NULL UNIQUE,
    `password` VARCHAR(255) NOT NULL,
    `email` VARCHAR(100),
    `phone` VARCHAR(20),
    `role` ENUM('admin', 'citizen') DEFAULT 'citizen',
    `name` VARCHAR(100),
    `address` TEXT,
    `latitude` DECIMAL(10, 8),
    `longitude` DECIMAL(11, 8),
    `recycling_score` INT(11) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `is_active` TINYINT(1) DEFAULT 1,
    PRIMARY KEY (`id`),
    INDEX (`username`),
    INDEX (`email`),
    INDEX (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. BINS TABLE
CREATE TABLE IF NOT EXISTS `bins` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `bin_id` VARCHAR(20) NOT NULL UNIQUE,
    `latitude` DECIMAL(10, 8) NOT NULL,
    `longitude` DECIMAL(11, 8) NOT NULL,
    `address` TEXT,
    `type` ENUM('Organic', 'Plastic', 'Paper', 'Glass', 'Metal', 'Electronic', 'Hazardous', 'Mixed') DEFAULT 'Mixed',
    `capacity` DECIMAL(10, 2) DEFAULT 100.00,
    `fill_level` DECIMAL(5, 2) DEFAULT 0.00,
    `status` ENUM('ACTIVE', 'FULL', 'MAINTENANCE', 'INACTIVE') DEFAULT 'ACTIVE',
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `last_emptied` TIMESTAMP NULL,
    `esp_id` VARCHAR(50),
    PRIMARY KEY (`id`),
    INDEX (`bin_id`),
    INDEX (`status`),
    INDEX (`esp_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. ROBOTS TABLE
CREATE TABLE IF NOT EXISTS `robots` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `robot_id` VARCHAR(20) NOT NULL UNIQUE,
    `esp_id` VARCHAR(50) UNIQUE,
    `name` VARCHAR(100),
    `api_key` VARCHAR(100) UNIQUE,
    `status` ENUM('IDLE', 'NAVIGATING', 'COLLECTING', 'RETURNING', 'CHARGING', 'OFFLINE', 'ERROR') DEFAULT 'OFFLINE',
    `latitude` DECIMAL(10, 8),
    `longitude` DECIMAL(11, 8),
    `battery_level` DECIMAL(5, 2) DEFAULT 0.00,
    `waste_collected` DECIMAL(10, 2) DEFAULT 0.00,
    `direction` VARCHAR(20) DEFAULT 'STOP',
    `distance_to_target` DECIMAL(10, 2) DEFAULT 0.00,
    `target_bin_id` VARCHAR(20),
    `last_telemetry` TIMESTAMP NULL,
    `connected_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX (`robot_id`),
    INDEX (`esp_id`),
    INDEX (`api_key`),
    INDEX (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. COLLECTION REQUESTS TABLE
CREATE TABLE IF NOT EXISTS `collection_requests` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `request_id` VARCHAR(20) NOT NULL UNIQUE,
    `citizen_id` INT(11) NOT NULL,
    `bin_id` VARCHAR(20),
    `robot_id` VARCHAR(20),
    `latitude` DECIMAL(10, 8) NOT NULL,
    `longitude` DECIMAL(11, 8) NOT NULL,
    `address` TEXT,
    `waste_type` VARCHAR(50) DEFAULT 'Mixed',
    `notes` TEXT,
    `status` ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED') DEFAULT 'PENDING',
    `request_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `assigned_time` TIMESTAMP NULL,
    `completion_time` TIMESTAMP NULL,
    `estimated_arrival` VARCHAR(50),
    `distance` DECIMAL(10, 2),
    `duration` INT(11),
    PRIMARY KEY (`id`),
    INDEX (`request_id`),
    INDEX (`citizen_id`),
    INDEX (`bin_id`),
    INDEX (`robot_id`),
    INDEX (`status`),
    FOREIGN KEY (`citizen_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. COLLECTION HISTORY TABLE
CREATE TABLE IF NOT EXISTS `collection_history` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `request_id` VARCHAR(20),
    `citizen_id` INT(11) NOT NULL,
    `bin_id` VARCHAR(20),
    `robot_id` VARCHAR(20),
    `waste_type` VARCHAR(50),
    `waste_amount` DECIMAL(10, 2) DEFAULT 0.00,
    `address` TEXT,
    `latitude` DECIMAL(10, 8),
    `longitude` DECIMAL(11, 8),
    `status` ENUM('COMPLETED', 'FAILED') DEFAULT 'COMPLETED',
    `collection_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `duration` INT(11),
    `feedback` TEXT,
    PRIMARY KEY (`id`),
    INDEX (`citizen_id`),
    INDEX (`bin_id`),
    INDEX (`robot_id`),
    INDEX (`collection_time`),
    FOREIGN KEY (`citizen_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. ESP32 DEVICES TABLE
CREATE TABLE IF NOT EXISTS `esp_devices` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `device_id` VARCHAR(50) NOT NULL UNIQUE,
    `api_key` VARCHAR(100) NOT NULL UNIQUE,
    `name` VARCHAR(100),
    `robot_id` VARCHAR(20),
    `status` ENUM('ONLINE', 'OFFLINE', 'ERROR') DEFAULT 'OFFLINE',
    `last_ping` TIMESTAMP NULL,
    `firmware_version` VARCHAR(20),
    `connected_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX (`device_id`),
    INDEX (`api_key`),
    INDEX (`robot_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. ADMIN LOGS TABLE
CREATE TABLE IF NOT EXISTS `admin_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `admin_id` INT(11) NOT NULL,
    `action` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `details` JSON,
    `ip_address` VARCHAR(45),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX (`admin_id`),
    INDEX (`action`),
    INDEX (`created_at`),
    FOREIGN KEY (`admin_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. SYSTEM SETTINGS TABLE
CREATE TABLE IF NOT EXISTS `system_settings` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `setting_key` VARCHAR(50) NOT NULL UNIQUE,
    `setting_value` TEXT,
    `setting_type` ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string',
    `description` TEXT,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ================================================================
-- INSERT DEFAULT ADMIN (FILLED WITH YOUR VALUES)
-- ================================================================

INSERT INTO `users` (`username`, `password`, `email`, `role`, `name`) 
VALUES ('Joshva', MD5('Joshva2014'), 'admin@szwc.com', 'admin', 'System Admin');

-- ================================================================
-- INSERT DEFAULT SYSTEM SETTINGS
-- ================================================================

INSERT INTO `system_settings` (`setting_key`, `setting_value`, `setting_type`, `description`) VALUES
('factory_lat', '0.000000', 'number', 'Factory Latitude (Set in Admin Panel)'),
('factory_lon', '0.000000', 'number', 'Factory Longitude (Set in Admin Panel)'),
('factory_address', 'Factory Location', 'string', 'Factory Address (Set in Admin Panel)'),
('map_center_lat', '0.000000', 'number', 'Map Center Latitude (Set in Admin Panel)'),
('map_center_lon', '0.000000', 'number', 'Map Center Longitude (Set in Admin Panel)'),
('update_interval', '5000', 'number', 'Update Interval in ms'),
('app_version', '3.0', 'string', 'App Version');

-- ================================================================
-- VERIFY
-- ================================================================
SHOW TABLES;
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL SELECT 'bins', COUNT(*) FROM bins
UNION ALL SELECT 'robots', COUNT(*) FROM robots
UNION ALL SELECT 'collection_requests', COUNT(*) FROM collection_requests
UNION ALL SELECT 'collection_history', COUNT(*) FROM collection_history
UNION ALL SELECT 'esp_devices', COUNT(*) FROM esp_devices
UNION ALL SELECT 'admin_logs', COUNT(*) FROM admin_logs
UNION ALL SELECT 'system_settings', COUNT(*) FROM system_settings;