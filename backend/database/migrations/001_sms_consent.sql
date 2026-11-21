-- Apply once to an existing database. Existing accounts must opt in again
-- before scheduled SMS reminders resume.
ALTER TABLE users MODIFY COLUMN sms_consent BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE users SET sms_consent = FALSE;
ALTER TABLE medications MODIFY COLUMN sms_enabled BOOLEAN NOT NULL DEFAULT FALSE;
