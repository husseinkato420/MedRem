let smsClient = null;

function getSmsClient() {
  if (smsClient) return smsClient;
  if (process.env.SMS_ENABLED !== 'true') return null;
  if (!process.env.AT_API_KEY || !process.env.AT_USERNAME) {
    throw new Error("SMS is enabled but Africa's Talking credentials are missing.");
  }
  const AfricasTalking = require('africastalking');
  const at = AfricasTalking({
    apiKey: process.env.AT_API_KEY,
    username: process.env.AT_USERNAME
  });
  smsClient = at.SMS;
  return smsClient;
}

function ugPhoneToE164(input) {
  const digits = String(input || '').replace(/[\s()-]/g, '');
  if (/^\+2567\d{8}$/.test(digits)) return digits;
  if (/^2567\d{8}$/.test(digits)) return `+${digits}`;
  if (/^07\d{8}$/.test(digits)) return `+256${digits.slice(1)}`;
  if (/^7\d{8}$/.test(digits)) return `+256${digits}`;
  throw new Error('Use a valid Ugandan mobile number, e.g. 0771234567.');
}

async function sendSms(phone, message) {
  const client = getSmsClient();
  if (!client) {
    return { skipped: true, reason: 'SMS_ENABLED is not true or gateway is not configured.' };
  }
  const to = ugPhoneToE164(phone);
  const options = { to: [to], message };
  if (process.env.AT_SENDER_ID) options.from = process.env.AT_SENDER_ID;
  return client.send(options);
}

async function sendMedicationReminder(phone) {
  const message = 'MedRemind: It is time for your scheduled medicine. Reply 1 or TAKEN to confirm, or follow health provider instructions.';
  return sendSms(phone, message);
}

async function sendAppointmentReminder(phone, date, clinic = 'Luweero Health Centre OPD') {
  const message = `MedRemind: Reminder for your clinic refill/review at ${clinic} on ${date}. Please keep your appointment.`;
  return sendSms(phone, message);
}

module.exports = {
  sendSms,
  sendMedicationReminder,
  sendAppointmentReminder,
  ugPhoneToE164
};
