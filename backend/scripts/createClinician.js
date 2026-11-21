require('dotenv').config();
const readline = require('node:readline/promises');
const { stdin: input, stdout: output } = require('node:process');
const bcrypt = require('bcryptjs');
const db = require('../src/db');
const { ugPhoneToE164 } = require('../src/sms');

async function main() {
  const prompt = readline.createInterface({ input, output });
  try {
    const fullName = (await prompt.question('Clinician full name: ')).trim();
    const phone = ugPhoneToE164(await prompt.question('Ugandan mobile phone: '));
    const password = await prompt.question('Password (at least 10 characters): ');
    const clinicId = (await prompt.question('Staff/clinic ID (optional): ')).trim();
    if (fullName.length < 2 || password.length < 10) {
      throw new Error('Provide a name and a password of at least 10 characters.');
    }
    const passwordHash = await bcrypt.hash(password, 12);
    await db.execute(
      `INSERT INTO users (full_name, phone, password_hash, role, clinic_id, sms_consent)
       VALUES (?, ?, ?, 'clinician', ?, FALSE)`,
      [fullName, phone, passwordHash, clinicId || null]
    );
    console.log(`Clinician account created for ${phone}.`);
  } finally {
    prompt.close();
    await db.end();
  }
}

main().catch(error => {
  console.error(`Could not create clinician account: ${error.message}`);
  process.exitCode = 1;
});
