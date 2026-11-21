# MedRemind Backend & Clinician Portal

Node.js REST API, MySQL database, SMS scheduler, and Web Clinician Adherence Portal for the **Luweero Health Centre Outpatient Department (OPD)** medication reminder project.

---

## Architectural Decision Note: Why Node.js + MySQL Over Firebase

For this project, **Node.js (Express) with a relational MySQL database** was selected over Firebase Firestore for several critical engineering and contextual reasons in Uganda:

1. **Relational Data Integrity:** Healthcare adherence tracking requires strict relational relationships (Foreign Keys) between patients, prescribed regimens, daily dose logs, and clinic refill appointments. MySQL provides ACID guarantees and structured schema enforcement that NoSQL document stores (like Firestore) lack.
2. **Local Deployment & Zero Cloud Bill Risk:** In Uganda, deploying Firebase functions and triggering SMS requires a paid Google Cloud Billing account linked to a foreign currency credit card. A Node.js backend can run locally, on an on-premise clinic server, or on standard local hosting without credit card lockouts.
3. **SMS Gateway Independence:** Direct integration with Africa's Talking API with two-way SMS webhooks is easier and more controllable within an Express server than with Firebase Cloud Functions.
4. **Academic Evaluation Alignment:** Academic computing panels at Makerere University Business School (MUBS) require Entity-Relationship Diagrams (ERDs), SQL DDL/DML, and database normalization (1NF–3NF), which are best demonstrated with MySQL.

---

## Requirements

- **Node.js 20 or newer**
- **MySQL 8.0+** (or MariaDB)
- **Africa's Talking account** (optional SMS delivery)

---

## Setup & Running

### 1. Database Setup
Create and import the database schema:
```bash
mysql -u root -p < database/schema.sql
```
This sets up:
* `users` (with roles: `patient`, `clinician`, `admin`, chronic disease categories: `HIV/AIDS`, `Hypertension`, `Tuberculosis`, `Diabetes`, `General Outpatient`, and language preferences).
* `medications` (prescriptions, daily times, pill counts).
* `dose_logs` (tracks taken/missed adherence instances via mobile app or SMS).
* `appointments` (tracks clinic refill and doctor review visits).
* `reminder_logs` (records dispatched SMS alerts).
* `incoming_sms_logs` (two-way incoming SMS replies).

### 2. Configure Environment (`.env`)
Copy `.env.example` to `.env`:
```powershell
Copy-Item .env.example .env
```
Update your database credentials, set a random `JWT_SECRET` of at least 32 characters, and configure SMS if you plan to use it:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=medremind
PORT=3000
JWT_SECRET=<random-secret-at-least-32-characters>
SMS_WEBHOOK_SECRET=<separate-random-secret>
SMS_ENABLED=false
AT_USERNAME=sandbox
AT_API_KEY=your_key
APP_TIMEZONE=Africa/Kampala
```

### 3. Install & Start Backend
```bash
npm install
npm run dev
```

Create staff accounts from the trusted backend host with `npm run create:clinician`. Public patient registration cannot create staff accounts. For a new database, import `database/schema.sql`. For an existing database, apply `database/migrations/001_sms_consent.sql`; this turns SMS consent off for existing accounts so each patient can opt in again. If you installed the earlier Firebase-enabled MedRemind archive, also apply `database/migrations/002_remove_fcm.sql`.

### SMS delivery and local reminders

SMS delivery requires `SMS_ENABLED=true`, Africa's Talking credentials, patient SMS consent, and medication-level SMS enabled. Configure the incoming SMS callback to `/api/sms/incoming` with the same `SMS_WEBHOOK_SECRET` in the `secret` query parameter (or `X-Webhook-Secret` header, if supported by the provider). Production rejects incoming callbacks if the secret is not configured.

The Node.js scheduler sends SMS over Africa's Talking. The Flutter app schedules local notifications on the patient's phone; it refreshes the next 14 days when the app opens or resumes. These are not remote push notifications, so no Firebase project or push service credentials are needed.

---

## Clinician Web Portal

When the server is running, clinicians and hospital administrators can access the portal directly at:
👉 **`http://localhost:3000/clinician`**

### Features of the Clinician Portal:
* **Cohort Overview:** Real-time metrics on total enrolled outpatients, cohort-wide adherence percentage, and low pill stock alerts.
* **Clinic Categorization:** Filter patients by chronic condition (HIV/AIDS ART, Hypertension, TB, Diabetes).
* **Patient Clinical Chart:** View a patient's prescription history, adherence percentage, and raw dose logs.
* **Prescribe Regimen:** Doctors/pharmacists can prescribe new medications directly to a patient.
* **Schedule Refill:** Set next clinic pickup dates to prevent treatment interruptions.

---

## API Endpoints

### 1. Authentication
* `POST /api/auth/register` — Register a patient account.
* `POST /api/auth/login` — Sign in and receive a JWT token.
* `GET /api/auth/me` — Retrieve current authenticated user profile.
* `PATCH /api/auth/preferences` — Update SMS consent and language preference (`en` / `lg`).

### 2. Patient Medications
* `GET /api/medications` — Retrieve authenticated user's active prescriptions.
* `POST /api/medications` — Add a new medication schedule.
* `PUT /api/medications/:id` — Update medication details or pill count.
* `DELETE /api/medications/:id` — Delete a medication.

### 3. Adherence & Dose Logging
* `POST /api/doses/log` — Record a dose status (`taken` / `missed`). Automatically decrements pill inventory when taken.
* `GET /api/doses/history` — Retrieve history of doses taken and missed.
* `GET /api/doses/stats` — Calculate overall adherence percentage and dose breakdown.

### 4. Appointments & Refills
* `GET /api/appointments` — Fetch scheduled clinic refill visits.
* `POST /api/appointments` — Schedule a new clinic refill or review visit.

### 5. Clinician Management (Requires Clinician JWT)
* `GET /api/clinician/stats` — Overall facility statistics.
* `GET /api/clinician/patients` — List of all registered outpatients with adherence scores.
* `GET /api/clinician/patients/:id` — Full medical chart of a patient.
* `POST /api/clinician/prescribe` — Prescribe medication to a patient.

### 6. Two-Way SMS Webhook
* `POST /api/sms/incoming` — Africa's Talking incoming SMS webhook. When patients reply with `1`, `YES`, `TAKEN`, or `NDIMIZE`, the system automatically logs their dose as taken and sends a confirmation reply.
