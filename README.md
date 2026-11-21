# MedRemind: Mobile-Based Medication Reminder System

### For Luweero Health Centre Outpatient Department (OPD) in Luweero District
**Bachelor of Business Computing (BBC) Project — Makerere University Business School (MUBS)**

---

## Overview

**MedRemind** is a digital health solution designed to solve the problem of medication non-adherence among chronic disease outpatients (HIV/AIDS, hypertension, tuberculosis, and diabetes) visiting Luweero Health Centre OPD.

The system combines:
1. **A Flutter Mobile Application** for personalized treatment schedules, local phone reminders, dose logging, and refill tracking, with English and Luganda support.
2. **A Node.js & MySQL Backend** providing JWT-authenticated APIs and SMS reminders through Africa's Talking.
3. **A Healthcare Provider Web Portal** allowing clinicians, nurses, and pharmacists to monitor patient adherence trends, view low-stock alerts, prescribe regimens, and schedule clinic refill visits.

---

## Key Features

* **Personalized schedules:** Set reminder times, days of the week, treatment dates, dose instructions, and SMS/local reminder preferences per medication.
* **Offline dose tracking:** Patients can record doses locally; pending medication and dose data sync when the backend is reachable. Local reminders are prepared for the next 14 days and refreshed when the app opens.
* **SMS reminders:** Node.js sends SMS only when the patient has opted in and the medication enables SMS. On-device reminders are scheduled locally and do not require Firebase or an internet connection.
* **Luganda Language Support:** Switch seamlessly between English and Oluganda across the entire mobile application.
* **Two-Way Dose Logging:** Doses can be logged via the mobile app or by replying to an SMS alert (`1`, `TAKEN`, or `NDIMIZE`).
* **Pill Inventory & Refill Warnings:** Real-time stock decrementing with warnings when pills drop to 5 or fewer.
* **Clinic Refill Calendar:** Schedule and track clinic refill pickup dates to avoid treatment interruptions.
* **Clinician OPD Dashboard:** Hospital staff can view compliance rates by chronic disease category and identify patients at risk of defaulting.

---

## Project Structure

```
├── lib/
│   ├── models/            # Medication and dose models
│   ├── screens/           # Today, Medicines, History, Profile, Clinic, Settings, Auth
│   ├── services/
│   │   ├── api_service.dart      # HTTP client connecting to Node.js backend
│   │   ├── language_service.dart # English & Luganda translation engine
│   │   ├── notifier.dart         # Local phone notifications (Africa/Kampala)
│   │   └── store.dart            # Offline-first storage & backend sync
│   └── main.dart          # App entry point with reactive language listener
├── backend/
│   ├── database/
│   │   └── schema.sql     # MySQL database structure (users, medications, dose_logs, appointments)
│   ├── public/
│   │   └── clinician.html # Luweero HC OPD Clinician Adherence Web Portal
│   ├── src/
│   │   ├── server.js      # Express REST API
│   │   ├── auth.js        # JWT verification middleware
│   │   ├── db.js          # MySQL connection pool
│   │   ├── reminderScheduler.js # Cron scheduler for daily dose reminders
│   │   └── sms.js         # Africa's Talking SMS dispatcher & parser
│   └── package.json
└── pubspec.yaml           # Flutter dependencies (http, flutter_local_notifications, timezone)
```

---

## How to Run

### 1. Start the Node.js Backend & Clinician Portal
```bash
cd backend
npm install
# Ensure MySQL is running and import database/schema.sql
npm run dev
```
* **API Health check:** `http://localhost:3000/api/health`
* **Clinician Web Portal:** `http://localhost:3000/clinician`

### Configure SMS reminders

1. Copy `backend/.env.example` to `backend/.env`. Set a unique random `JWT_SECRET` (at least 32 characters), database credentials, and a separate `SMS_WEBHOOK_SECRET`. The server refuses to start with the example JWT placeholder.
2. For SMS, configure the Africa's Talking username and API key, set `SMS_ENABLED=true`, and keep SMS consent turned off unless the patient has opted in. Configure the incoming-message callback to use the same webhook secret, for example as the `secret` query parameter on `/api/sms/incoming`.
3. Run `npm install` in `backend/`, apply `backend/database/schema.sql` for a new database or `backend/database/migrations/001_sms_consent.sql` to an existing database, then start the API. If you installed the earlier Firebase-enabled MedRemind archive, apply `backend/database/migrations/002_remove_fcm.sql` to remove its unused FCM tables and column.

Provision staff accounts from the backend directory with `npm run create:clinician`. Public registration only creates patient accounts.

### 2. Run the Flutter Mobile App
```bash
flutter pub get
flutter run
```
* On Android Emulator, the app automatically connects to `http://10.0.2.2:3000`.
* On a physical phone, set the API URL in **Settings**. Use HTTPS for production; plain HTTP is for local development only.
* Local phone reminders are not server push. The app refreshes its 14-day reminder window whenever it opens or resumes.
