const cron = require('node-cron');
const db = require('./db');
const { localDate, localTime, weekday } = require('./time');
const { sendMedicationReminder } = require('./sms');

function asArray(value, fallback = []) {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try { return JSON.parse(value); } catch (_) { return fallback; }
  }
  return fallback;
}

async function processDueReminders() {
  const date = localDate();
  const time = localTime();
  const day = weekday(date);

  const [medications] = await db.execute(
    `SELECT m.id, m.user_id, m.times, m.days_of_week, m.start_date, m.end_date,
            m.sms_enabled, u.sms_consent, u.phone
       FROM medications m
       JOIN users u ON u.id = m.user_id
      WHERE m.active = 1`
  );

  for (const med of medications) {
    const times = asArray(med.times);
    const days = asArray(med.days_of_week, [0,1,2,3,4,5,6]).map(Number);
    if (!times.includes(time) || !days.includes(day)) continue;
    if (med.start_date && date < String(med.start_date).slice(0, 10)) continue;
    if (med.end_date && date > String(med.end_date).slice(0, 10)) continue;

    if (process.env.SMS_ENABLED !== 'true' || !med.sms_enabled || !med.sms_consent) continue;

    const scheduledFor = `${date} ${time}:00`;
    let logId;
    try {
      const [insert] = await db.execute(
        `INSERT INTO reminder_logs (medication_id, user_id, scheduled_for, channel, status)
         VALUES (?, ?, ?, 'sms', 'pending')`,
        [med.id, med.user_id, scheduledFor]
      );
      logId = insert.insertId;
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') continue;
      console.error('Could not create SMS reminder log:', error.message);
      continue;
    }

    try {
      await sendMedicationReminder(med.phone);
      await db.execute(
        `UPDATE reminder_logs SET status = 'sent', sent_at = NOW(), error_message = NULL WHERE id = ?`,
        [logId]
      );
      console.log(`SMS reminder sent for medication ${med.id} at ${scheduledFor}`);
    } catch (error) {
      await db.execute(
        `UPDATE reminder_logs SET status = 'failed', error_message = ? WHERE id = ?`,
        [String(error.message).slice(0, 500), logId]
      );
      console.error(`SMS reminder failed for medication ${med.id}:`, error.message);
    }
  }
}

function startReminderScheduler() {
  // The cron expression is evaluated in Kampala time.
  cron.schedule('* * * * *', () => {
    processDueReminders().catch(error => console.error('Reminder scheduler error:', error));
  }, { timezone: process.env.APP_TIMEZONE || 'Africa/Kampala' });
  console.log(`Medication SMS scheduler started (${process.env.APP_TIMEZONE || 'Africa/Kampala'}).`);
}

module.exports = { startReminderScheduler, processDueReminders };
