-- Apply only if you previously installed the Firebase/FCM-enabled project ZIP.
DROP TABLE IF EXISTS push_devices;

SET @has_push_enabled = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'medications'
     AND COLUMN_NAME = 'push_enabled'
);
SET @drop_push_enabled = IF(@has_push_enabled > 0,
  'ALTER TABLE medications DROP COLUMN push_enabled', 'SELECT 1');
PREPARE remove_push_column FROM @drop_push_enabled;
EXECUTE remove_push_column;
DEALLOCATE PREPARE remove_push_column;

ALTER TABLE reminder_logs MODIFY COLUMN channel ENUM('sms', 'push') NOT NULL DEFAULT 'sms';
DELETE FROM reminder_logs WHERE channel = 'push';
ALTER TABLE reminder_logs MODIFY COLUMN channel ENUM('sms') NOT NULL DEFAULT 'sms';
