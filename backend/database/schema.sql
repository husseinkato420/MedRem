CREATE DATABASE IF NOT EXISTS medremind
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE medremind;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  phone VARCHAR(20) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('patient', 'clinician', 'admin') NOT NULL DEFAULT 'patient',
  clinic_id VARCHAR(50) NULL,
  disease_category ENUM('HIV/AIDS', 'Hypertension', 'Tuberculosis', 'Diabetes', 'General Outpatient') NOT NULL DEFAULT 'General Outpatient',
  sms_consent BOOLEAN NOT NULL DEFAULT FALSE,
  preferred_language ENUM('en', 'lg') NOT NULL DEFAULT 'en',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_users_role (role),
  INDEX idx_users_disease (disease_category)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS medications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  dose VARCHAR(100) NOT NULL DEFAULT '',
  times JSON NOT NULL,
  days_of_week JSON NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  instructions TEXT NULL,
  sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  pills INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  prescribed_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_medications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_medications_prescriber FOREIGN KEY (prescribed_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_medications_user_active (user_id, active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dose_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  medication_id BIGINT UNSIGNED NOT NULL,
  scheduled_time VARCHAR(10) NOT NULL,
  date DATE NOT NULL,
  status ENUM('taken', 'missed') NOT NULL,
  channel ENUM('app', 'sms', 'clinician') NOT NULL DEFAULT 'app',
  logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_dose_instance (medication_id, date, scheduled_time),
  CONSTRAINT fk_doselogs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_doselogs_medication FOREIGN KEY (medication_id) REFERENCES medications(id) ON DELETE CASCADE,
  INDEX idx_doselogs_user_date (user_id, date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  appointment_date DATE NOT NULL,
  clinic_department VARCHAR(100) NOT NULL DEFAULT 'Luweero Health Centre OPD',
  purpose VARCHAR(255) NOT NULL DEFAULT 'Medication Refill & Review',
  status ENUM('scheduled', 'completed', 'missed') NOT NULL DEFAULT 'scheduled',
  notes TEXT NULL,
  created_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_appointments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_appointments_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_appointments_user_date (user_id, appointment_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reminder_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  medication_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  scheduled_for DATETIME NOT NULL,
  channel ENUM('sms') NOT NULL DEFAULT 'sms',
  status ENUM('pending', 'sent', 'failed') NOT NULL DEFAULT 'pending',
  sent_at DATETIME NULL,
  error_message VARCHAR(500) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_medication_schedule_channel (medication_id, scheduled_for, channel),
  CONSTRAINT fk_reminder_medication FOREIGN KEY (medication_id) REFERENCES medications(id) ON DELETE CASCADE,
  CONSTRAINT fk_reminder_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS incoming_sms_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  from_phone VARCHAR(20) NOT NULL,
  message_body TEXT NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  action_taken VARCHAR(100) NULL,
  received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_incoming_sms_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

