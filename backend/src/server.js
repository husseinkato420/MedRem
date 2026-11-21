require('dotenv').config();

const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
const db = require('./db');
const { requireAuth } = require('./auth');
const { ugPhoneToE164, sendSms, sendMedicationReminder } = require('./sms');
const { startReminderScheduler } = require('./reminderScheduler');
const { localDate, localTime } = require('./time');

if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32 || process.env.JWT_SECRET.startsWith('replace-')) {
  throw new Error('Set JWT_SECRET to a random value with at least 32 characters before starting MedRemind.');
}

const app = express();
app.use(helmet({
  contentSecurityPolicy: false // Allows inline scripts for simple clinician portal
}));
const allowedOrigins = (process.env.CORS_ORIGIN || '').split(',').map(value => value.trim()).filter(Boolean);
app.use(cors({ origin: allowedOrigins.length ? allowedOrigins : false }));
app.use(express.json({ limit: '200kb' }));
app.use(express.urlencoded({ extended: true }));

// Serve Clinician Web Portal static assets
app.use('/public', express.static(path.join(__dirname, '../public')));
app.use(express.static(path.join(__dirname, '../public')));

app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, limit: 12 }));
app.use('/api', rateLimit({ windowMs: 15 * 60 * 1000, limit: 600 }));

function issueToken(user) {
  return jwt.sign(
    { id: user.id, phone: user.phone, role: user.role || 'patient' },
    process.env.JWT_SECRET,
    { expiresIn: '30d' }
  );
}

function safeUser(user) {
  return {
    id: user.id,
    fullName: user.full_name,
    phone: user.phone,
    role: user.role || 'patient',
    clinicId: user.clinic_id || '',
    diseaseCategory: user.disease_category || 'General Outpatient',
    smsConsent: !!user.sms_consent,
    preferredLanguage: user.preferred_language || 'en'
  };
}

// Middleware to ensure clinician / staff privileges
function requireClinician(req, res, next) {
  if (!req.user || (req.user.role !== 'clinician' && req.user.role !== 'admin')) {
    return res.status(403).json({ message: 'Access denied. Clinician role required.' });
  }
  next();
}

app.get('/api/health', (_req, res) => res.json({
  status: 'ok',
  service: 'MedRemind Luweero HC API',
  timestamp: new Date().toISOString()
}));

// -------------------------------------------------------------
// Authentication Endpoints
// -------------------------------------------------------------
app.post('/api/auth/register', async (req, res, next) => {
  try {
    const fullName = String(req.body.fullName || '').trim();
    const phone = ugPhoneToE164(req.body.phone);
    const password = String(req.body.password || '');
    // Public registration must never grant staff privileges.
    const role = 'patient';
    const clinicId = String(req.body.clinicId || '').trim();
    const diseaseCategory = req.body.diseaseCategory || 'General Outpatient';
    const smsConsent = req.body.smsConsent === true;
    const preferredLanguage = req.body.preferredLanguage === 'lg' ? 'lg' : 'en';

    if (fullName.length < 2 || password.length < 10) {
      return res.status(400).json({ message: 'Enter your full name and a password of at least 10 characters.' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const [result] = await db.execute(
      `INSERT INTO users (full_name, phone, password_hash, role, clinic_id, disease_category, sms_consent, preferred_language)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [fullName, phone, passwordHash, role, clinicId, diseaseCategory, smsConsent, preferredLanguage]
    );

    const user = {
      id: result.insertId,
      full_name: fullName,
      phone,
      role,
      clinic_id: clinicId,
      disease_category: diseaseCategory,
      sms_consent: smsConsent,
      preferred_language: preferredLanguage
    };

    res.status(201).json({
      message: 'Account created successfully.',
      token: issueToken(user),
      user: safeUser(user)
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'That phone number is already registered in MedRemind.' });
    }
    if (error.message && error.message.startsWith('Use a valid')) {
      return res.status(400).json({ message: error.message });
    }
    next(error);
  }
});

app.post('/api/auth/login', async (req, res, next) => {
  try {
    const phone = ugPhoneToE164(req.body.phone);
    const password = String(req.body.password || '');
    const [rows] = await db.execute('SELECT * FROM users WHERE phone = ? LIMIT 1', [phone]);

    if (!rows.length || !(await bcrypt.compare(password, rows[0].password_hash))) {
      return res.status(401).json({ message: 'Incorrect phone number or password.' });
    }

    const user = rows[0];
    res.json({
      message: 'Signed in successfully.',
      token: issueToken(user),
      user: safeUser(user)
    });
  } catch (error) {
    if (error.message && error.message.startsWith('Use a valid')) {
      return res.status(400).json({ message: error.message });
    }
    next(error);
  }
});

app.get('/api/auth/me', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await db.execute('SELECT * FROM users WHERE id = ?', [req.user.id]);
    if (!rows.length) return res.status(404).json({ message: 'Account not found.' });
    res.json({ user: safeUser(rows[0]) });
  } catch (error) { next(error); }
});

app.patch('/api/auth/preferences', requireAuth, async (req, res, next) => {
  try {
    const updates = [];
    const params = [];
    if (typeof req.body.smsConsent === 'boolean') {
      updates.push('sms_consent = ?');
      params.push(req.body.smsConsent);
    }
    if (['en', 'lg'].includes(req.body.preferredLanguage)) {
      updates.push('preferred_language = ?');
      params.push(req.body.preferredLanguage);
    }
    if (!updates.length) return res.status(400).json({ message: 'No valid preferences to update.' });

    params.push(req.user.id);
    await db.execute(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
    res.json({ message: 'Preferences updated successfully.' });
  } catch (error) { next(error); }
});

// -------------------------------------------------------------
// Medication Management Endpoints
// -------------------------------------------------------------
function validateMedication(body) {
  const name = String(body.name || '').trim();
  const dose = String(body.dose || '').trim();
  const times = body.times;
  const days = body.daysOfWeek === undefined ? [0,1,2,3,4,5,6] : body.daysOfWeek;
  if (!name || !Array.isArray(times) || !times.length ||
      times.some(t => !/^([01]\d|2[0-3]):[0-5]\d$/.test(t)) ||
      !Array.isArray(days) || !days.length || days.some(d => !Number.isInteger(d) || d < 0 || d > 6)) {
    return { error: 'Provide a medicine name, valid 24-hour times (HH:mm), and weekdays (0=Sunday to 6=Saturday).' };
  }
  const startDate = body.startDate || null;
  const endDate = body.endDate || null;
  if (startDate && !isDateString(startDate)) return { error: 'startDate must be a real date in YYYY-MM-DD format.' };
  if (endDate && !isDateString(endDate)) return { error: 'endDate must be a real date in YYYY-MM-DD format.' };
  if (startDate && endDate && endDate < startDate) return { error: 'endDate cannot be before startDate.' };
  return {
    value: {
      name, dose, times: [...new Set(times)].sort(), daysOfWeek: [...new Set(days)].sort(),
      startDate, endDate, instructions: String(body.instructions || '').trim(),
      smsEnabled: body.smsEnabled === true,
      pills: Math.max(0, Number.parseInt(body.pills, 10) || 0)
    }
  };
}

function isDateString(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value;
}

function formatMedication(m) {
  const parse = v => typeof v === 'string' ? JSON.parse(v) : v;
  return {
    id: m.id,
    userId: m.user_id,
    name: m.name,
    dose: m.dose,
    times: parse(m.times),
    daysOfWeek: parse(m.days_of_week),
    startDate: m.start_date,
    endDate: m.end_date,
    instructions: m.instructions,
    smsEnabled: !!m.sms_enabled,
    pills: m.pills,
    active: !!m.active,
    prescribedBy: m.prescribed_by
  };
}

app.get('/api/medications', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await db.execute(
      'SELECT * FROM medications WHERE user_id = ? ORDER BY active DESC, created_at DESC',
      [req.user.id]
    );
    res.json({ medications: rows.map(formatMedication) });
  } catch (error) { next(error); }
});

app.post('/api/medications', requireAuth, async (req, res, next) => {
  try {
    const checked = validateMedication(req.body);
    if (checked.error) return res.status(400).json({ message: checked.error });
    const m = checked.value;
    const [result] = await db.execute(
      `INSERT INTO medications
       (user_id, name, dose, times, days_of_week, start_date, end_date, instructions, sms_enabled, pills)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.id, m.name, m.dose, JSON.stringify(m.times), JSON.stringify(m.daysOfWeek),
       m.startDate, m.endDate, m.instructions, m.smsEnabled, m.pills]
    );
    const [rows] = await db.execute('SELECT * FROM medications WHERE id = ? AND user_id = ?', [result.insertId, req.user.id]);
    res.status(201).json({ medication: formatMedication(rows[0]) });
  } catch (error) { next(error); }
});

app.put('/api/medications/:id', requireAuth, async (req, res, next) => {
  try {
    const checked = validateMedication(req.body);
    if (checked.error) return res.status(400).json({ message: checked.error });
    const m = checked.value;
    const [result] = await db.execute(
      `UPDATE medications SET name=?, dose=?, times=?, days_of_week=?, start_date=?, end_date=?,
       instructions=?, sms_enabled=?, pills=?, active=? WHERE id=? AND user_id=?`,
      [m.name, m.dose, JSON.stringify(m.times), JSON.stringify(m.daysOfWeek), m.startDate,
       m.endDate, m.instructions, m.smsEnabled, m.pills, req.body.active === false ? 0 : 1,
       req.params.id, req.user.id]
    );
    if (!result.affectedRows) return res.status(404).json({ message: 'Medication not found.' });
    const [rows] = await db.execute('SELECT * FROM medications WHERE id=? AND user_id=?', [req.params.id, req.user.id]);
    res.json({ medication: formatMedication(rows[0]) });
  } catch (error) { next(error); }
});

app.delete('/api/medications/:id', requireAuth, async (req, res, next) => {
  try {
    const [result] = await db.execute('DELETE FROM medications WHERE id=? AND user_id=?', [req.params.id, req.user.id]);
    if (!result.affectedRows) return res.status(404).json({ message: 'Medication not found.' });
    res.json({ message: 'Medication deleted.' });
  } catch (error) { next(error); }
});

// -------------------------------------------------------------
// Adherence & Dose Logging Endpoints
// -------------------------------------------------------------
app.post('/api/doses/log', requireAuth, async (req, res, next) => {
  try {
    const { medicationId, scheduledTime, date, status } = req.body;
    if (!medicationId || !scheduledTime || !['taken', 'missed'].includes(status)) {
      return res.status(400).json({ message: 'medicationId, scheduledTime, and status (taken/missed) required.' });
    }
    const logDate = date || localDate();
    if (!isDateString(logDate) || logDate > localDate() || !/^([01]\d|2[0-3]):[0-5]\d$/.test(scheduledTime)) {
      return res.status(400).json({ message: 'date must be YYYY-MM-DD and scheduledTime must be HH:mm.' });
    }

    const [medications] = await db.execute(
      'SELECT id, times, days_of_week, start_date, end_date FROM medications WHERE id = ? AND user_id = ? AND active = 1',
      [medicationId, req.user.id]
    );
    if (!medications.length) return res.status(404).json({ message: 'Medication not found for this account.' });
    const med = formatMedication({ ...medications[0], name: '', dose: '', pills: 0, sms_enabled: 0, instructions: '', active: 1 });
    const weekday = new Date(`${logDate}T12:00:00+03:00`).getDay();
    if (!med.times.includes(scheduledTime) || !med.daysOfWeek.includes(weekday) ||
        (med.startDate && logDate < String(med.startDate).slice(0, 10)) ||
        (med.endDate && logDate > String(med.endDate).slice(0, 10))) {
      return res.status(400).json({ message: 'Dose does not match the medication schedule for that date.' });
    }

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();
      const [existing] = await connection.execute(
        'SELECT status FROM dose_logs WHERE medication_id = ? AND date = ? AND scheduled_time = ? FOR UPDATE',
        [medicationId, logDate, scheduledTime]
      );
      const previousStatus = existing[0]?.status;
      await connection.execute(
      `INSERT INTO dose_logs (user_id, medication_id, scheduled_time, date, status, channel)
       VALUES (?, ?, ?, ?, ?, 'app')
       ON DUPLICATE KEY UPDATE status = VALUES(status), logged_at = CURRENT_TIMESTAMP`,
        [req.user.id, medicationId, scheduledTime, logDate, status]
      );
      if (status !== previousStatus && (status === 'taken' || previousStatus === 'taken')) {
        await connection.execute(
          'UPDATE medications SET pills = GREATEST(0, pills + ?) WHERE id = ? AND user_id = ?',
          [status === 'taken' ? -1 : 1, medicationId, req.user.id]
        );
      }
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }

    res.json({ message: 'Dose logged successfully.', status, date: logDate, scheduledTime });
  } catch (error) { next(error); }
});

app.get('/api/doses/history', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await db.execute(
      `SELECT d.id, d.medication_id, m.name as medication_name, m.dose,
              d.scheduled_time, d.date, d.status, d.channel, d.logged_at
         FROM dose_logs d
         JOIN medications m ON m.id = d.medication_id
        WHERE d.user_id = ?
        ORDER BY d.date DESC, d.scheduled_time DESC LIMIT 100`,
      [req.user.id]
    );
    res.json({ history: rows });
  } catch (error) { next(error); }
});

app.get('/api/doses/stats', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await db.execute(
      `SELECT
         COUNT(*) as total_doses,
         SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken_count,
         SUM(CASE WHEN status = 'missed' THEN 1 ELSE 0 END) as missed_count
       FROM dose_logs
       WHERE user_id = ?`,
      [req.user.id]
    );

    const total = rows[0].total_doses || 0;
    const taken = rows[0].taken_count || 0;
    const percentage = total > 0 ? Math.round((taken / total) * 100) : null;

    res.json({
      totalDoses: total,
      takenDoses: taken,
      missedDoses: rows[0].missed_count || 0,
      adherencePercentage: percentage
    });
  } catch (error) { next(error); }
});

// -------------------------------------------------------------
// Clinic Appointments & Refill Reminders Endpoints
// -------------------------------------------------------------
app.get('/api/appointments', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await db.execute(
      `SELECT * FROM appointments WHERE user_id = ? ORDER BY appointment_date ASC`,
      [req.user.id]
    );
    res.json({ appointments: rows });
  } catch (error) { next(error); }
});

app.post('/api/appointments', requireAuth, async (req, res, next) => {
  try {
    const { appointmentDate, clinicDepartment, purpose, notes, patientId } = req.body;
    if (!isDateString(appointmentDate)) {
      return res.status(400).json({ message: 'Valid appointmentDate (YYYY-MM-DD) is required.' });
    }
    let targetUserId = req.user.id;
    if (patientId !== undefined) {
      if (!['clinician', 'admin'].includes(req.user.role)) {
        return res.status(403).json({ message: 'Clinician role required to schedule for a patient.' });
      }
      const [patients] = await db.execute("SELECT id FROM users WHERE id = ? AND role = 'patient'", [patientId]);
      if (!patients.length) return res.status(404).json({ message: 'Patient not found.' });
      targetUserId = patientId;
    }
    const [result] = await db.execute(
      `INSERT INTO appointments (user_id, appointment_date, clinic_department, purpose, notes, created_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        targetUserId,
        appointmentDate,
        clinicDepartment || 'Luweero Health Centre OPD',
        purpose || 'Medication Refill & Review',
        notes || null,
        targetUserId === req.user.id ? null : req.user.id
      ]
    );
    res.status(201).json({ message: 'Appointment scheduled.', id: result.insertId });
  } catch (error) { next(error); }
});

// -------------------------------------------------------------
// Clinician Portal APIs (Luweero HC OPD Doctor/Nurse Portal)
// -------------------------------------------------------------
app.get('/api/clinician/stats', requireAuth, requireClinician, async (_req, res, next) => {
  try {
    const [patientCount] = await db.execute("SELECT COUNT(*) as count FROM users WHERE role = 'patient'");
    const [medCount] = await db.execute("SELECT COUNT(*) as count FROM medications WHERE active = 1");
    const [adherence] = await db.execute(`
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken
      FROM dose_logs
    `);
    const [lowStock] = await db.execute("SELECT COUNT(*) as count FROM medications WHERE active = 1 AND pills <= 5");

    const totalDoses = adherence[0].total || 0;
    const takenDoses = adherence[0].taken || 0;
    const avgAdherence = totalDoses > 0 ? Math.round((takenDoses / totalDoses) * 100) : null;

    res.json({
      totalPatients: patientCount[0].count,
      activeMedications: medCount[0].count,
      averageAdherence: avgAdherence,
      lowStockCount: lowStock[0].count
    });
  } catch (error) { next(error); }
});

app.get('/api/clinician/patients', requireAuth, requireClinician, async (_req, res, next) => {
  try {
    const [patients] = await db.execute(`
      SELECT u.id, u.full_name, u.phone, u.clinic_id, u.disease_category, u.created_at,
             (SELECT COUNT(*) FROM medications m WHERE m.user_id = u.id AND m.active = 1) AS active_meds,
             (SELECT MIN(m.pills) FROM medications m WHERE m.user_id = u.id AND m.active = 1) AS min_pills_left,
             (SELECT COUNT(*) FROM dose_logs d WHERE d.user_id = u.id) AS total_logged_doses,
             (SELECT COUNT(*) FROM dose_logs d WHERE d.user_id = u.id AND d.status = 'taken') AS taken_doses
        FROM users u
       WHERE u.role = 'patient'
    ORDER BY u.created_at DESC
    `);

    const result = patients.map(p => {
      const total = Number(p.total_logged_doses || 0);
      const taken = Number(p.taken_doses || 0);
      const adherence = total > 0 ? Math.round((taken / total) * 100) : null;
      return {
        id: p.id,
        fullName: p.full_name,
        phone: p.phone,
        clinicId: p.clinic_id,
        diseaseCategory: p.disease_category,
        activeMeds: p.active_meds || 0,
        minPillsLeft: p.min_pills_left,
        adherenceRate: adherence,
        registeredAt: p.created_at
      };
    });

    res.json({ patients: result });
  } catch (error) { next(error); }
});

app.get('/api/clinician/patients/:id', requireAuth, requireClinician, async (req, res, next) => {
  try {
    const [userRows] = await db.execute(
      "SELECT id, full_name, phone, clinic_id, disease_category, sms_consent, created_at FROM users WHERE id = ? AND role = 'patient'",
      [req.params.id]
    );
    if (!userRows.length) return res.status(404).json({ message: 'Patient not found.' });

    const [meds] = await db.execute(
      'SELECT * FROM medications WHERE user_id = ? ORDER BY active DESC, created_at DESC',
      [req.params.id]
    );
    const [recentDoses] = await db.execute(
      `SELECT d.*, m.name as medication_name FROM dose_logs d
         JOIN medications m ON m.id = d.medication_id
        WHERE d.user_id = ? ORDER BY d.date DESC, d.scheduled_time DESC LIMIT 20`,
      [req.params.id]
    );
    const [appointments] = await db.execute(
      'SELECT * FROM appointments WHERE user_id = ? ORDER BY appointment_date ASC',
      [req.params.id]
    );

    res.json({
      patient: userRows[0],
      medications: meds.map(formatMedication),
      recentDoses,
      appointments
    });
  } catch (error) { next(error); }
});

app.post('/api/clinician/prescribe', requireAuth, requireClinician, async (req, res, next) => {
  try {
    const { patientId } = req.body;
    if (!patientId) return res.status(400).json({ message: 'patientId is required.' });
    const [patients] = await db.execute("SELECT id FROM users WHERE id = ? AND role = 'patient'", [patientId]);
    if (!patients.length) return res.status(404).json({ message: 'Patient not found.' });

    const checked = validateMedication(req.body);
    if (checked.error) return res.status(400).json({ message: checked.error });
    const m = checked.value;

    const [result] = await db.execute(
      `INSERT INTO medications
       (user_id, name, dose, times, days_of_week, start_date, end_date, instructions, sms_enabled, pills, prescribed_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [patientId, m.name, m.dose, JSON.stringify(m.times), JSON.stringify(m.daysOfWeek),
       m.startDate, m.endDate, m.instructions, m.smsEnabled, m.pills, req.user.id]
    );

    res.status(201).json({ message: 'Medication prescribed successfully.', medicationId: result.insertId });
  } catch (error) { next(error); }
});

// -------------------------------------------------------------
// Two-Way SMS Webhook (Africa's Talking incoming message receiver)
// -------------------------------------------------------------
app.post('/api/sms/incoming', async (req, res, next) => {
  try {
    const webhookSecret = process.env.SMS_WEBHOOK_SECRET || '';
    const suppliedSecret = String(req.get('x-webhook-secret') || req.query.secret || '');
    const suppliedBytes = Buffer.from(suppliedSecret);
    const secretBytes = Buffer.from(webhookSecret);
    if (process.env.NODE_ENV === 'production' && !webhookSecret) {
      return res.status(503).send('SMS webhook secret is not configured.');
    }
    if (webhookSecret && (suppliedBytes.length !== secretBytes.length ||
        !crypto.timingSafeEqual(suppliedBytes, secretBytes))) {
      return res.status(401).send('Unauthorized SMS webhook.');
    }
    // Africa's Talking payload format: from, to, text, date, id
    const from = req.body.from || req.body.phone;
    const text = String(req.body.text || '').trim();

    console.log('Incoming SMS callback received.');
    if (!from || !text) {
      return res.status(400).send('Missing from or text parameter');
    }

    const cleanPhone = ugPhoneToE164(from);
    const [users] = await db.execute('SELECT * FROM users WHERE phone = ? LIMIT 1', [cleanPhone]);
    const user = users[0] || null;

    let actionTaken = 'Ignored (unrecognized command)';

    // Check if patient is confirming a dose: "1", "YES", "TAKEN", "NDIMIZE"
    const lower = text.toLowerCase();
    if (user && (lower === '1' || lower === 'yes' || lower === 'taken' || lower === 'ndimize' || lower.includes('taken'))) {
      const today = localDate();
      const nowTime = localTime();

      // Match a confirmation to a dose scheduled recently today instead of
      // recording it against the current clock time or an arbitrary medicine.
      const [dueMeds] = await db.execute(
        `SELECT * FROM medications WHERE user_id = ? AND active = 1 ORDER BY id ASC`,
        [user.id]
      );
      const todayWeekday = new Date(`${today}T12:00:00+03:00`).getDay();
      const due = [];
      for (const medication of dueMeds) {
        const parseList = value => Array.isArray(value) ? value : JSON.parse(value || '[]');
        const times = parseList(medication.times);
        const days = parseList(medication.days_of_week).map(Number);
        if (!days.includes(todayWeekday)) continue;
        if (medication.start_date && today < String(medication.start_date).slice(0, 10)) continue;
        if (medication.end_date && today > String(medication.end_date).slice(0, 10)) continue;
        for (const scheduledTime of times) {
          const minutesLate = (Number(nowTime.slice(0, 2)) * 60 + Number(nowTime.slice(3))) -
            (Number(scheduledTime.slice(0, 2)) * 60 + Number(scheduledTime.slice(3)));
          if (minutesLate >= 0 && minutesLate <= 360) due.push({ medication, scheduledTime, minutesLate });
        }
      }

      due.sort((a, b) => a.minutesLate - b.minutesLate);
      if (due.length) {
        const { medication: med, scheduledTime } = due[0];
        const connection = await db.getConnection();
        try {
          await connection.beginTransaction();
          const [existing] = await connection.execute(
            'SELECT status FROM dose_logs WHERE medication_id = ? AND date = ? AND scheduled_time = ? FOR UPDATE',
            [med.id, today, scheduledTime]
          );
          await connection.execute(
            `INSERT INTO dose_logs (user_id, medication_id, scheduled_time, date, status, channel)
             VALUES (?, ?, ?, ?, 'taken', 'sms')
             ON DUPLICATE KEY UPDATE status = 'taken', channel = 'sms', logged_at = CURRENT_TIMESTAMP`,
            [user.id, med.id, scheduledTime, today]
          );
          if (existing[0]?.status !== 'taken') {
            await connection.execute('UPDATE medications SET pills = GREATEST(0, pills - 1) WHERE id = ? AND user_id = ?', [med.id, user.id]);
          }
          await connection.commit();
        } catch (error) {
          await connection.rollback();
          throw error;
        } finally {
          connection.release();
        }

        actionTaken = `Dose recorded as taken for med ${med.id} at ${scheduledTime}`;

        // Send polite confirmation SMS back
        try {
          const reply = user.preferred_language === 'lg'
            ? 'MedRemind: Weebale kutegeeza. Twandiise nti omize eddagala lyayo leero.'
            : 'MedRemind: Thank you. Your medication dose has been recorded as taken today.';
          await sendSms(cleanPhone, reply);
        } catch (e) {
          console.error('Failed to send confirmation SMS:', e.message);
        }
      }
    }

    await db.execute(
      `INSERT INTO incoming_sms_logs (from_phone, message_body, user_id, action_taken)
       VALUES (?, ?, ?, ?)`,
      [from, text, user ? user.id : null, actionTaken]
    );

    res.status(200).send('OK');
  } catch (error) {
    console.error('Incoming SMS error:', error.message);
    res.status(200).send('ERROR_LOGGED');
  }
});

// Serve the Clinician Portal Web App
app.get('/clinician', (_req, res) => {
  res.sendFile(path.join(__dirname, '../public/clinician.html'));
});
app.get('/portal', (_req, res) => res.redirect('/clinician'));

// -------------------------------------------------------------
// Error Handler & Startup
// -------------------------------------------------------------
app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ message: 'Server error. Check the backend terminal for details.' });
});

const port = Number(process.env.PORT || 3000);
async function start() {
  try {
    await db.query('SELECT 1');
    console.log('Connected to MySQL database.');
  } catch (err) {
    console.warn('MySQL connection warning (ensure MySQL is running before starting the server):', err.message);
  }
  app.listen(port, () => {
    console.log(`MedRemind API running on http://localhost:${port}`);
    console.log(`Luweero HC OPD Clinician Portal: http://localhost:${port}/clinician`);
  });
  startReminderScheduler();
}

start().catch(error => {
  console.error('Could not start MedRemind API:', error.message);
  process.exit(1);
});
