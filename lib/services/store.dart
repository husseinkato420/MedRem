import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';
import 'api_service.dart';
import 'language_service.dart';
import 'notifier.dart';

// Everything is saved locally on the phone so the app works 100% offline.
// When connected to the Node.js backend, changes sync automatically.
class Store {
  static late SharedPreferences _p;
  static List<Medication> meds = [];
  // key: "medId|yyyy-MM-dd|HH:mm"  value: "taken" or "missed"
  static Map<String, String> log = {};
  static List<Map<String, dynamic>> appointments = [];
  static Set<int> _deletedServerMedicationIds = {};

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    LanguageService.init(_p);
    await ApiService.init(_p);

    meds = (jsonDecode(_p.getString('meds') ?? '[]') as List)
        .map((e) => Medication.fromJson(e))
        .toList();
    log = Map<String, String>.from(jsonDecode(_p.getString('log') ?? '{}'));
    appointments = List<Map<String, dynamic>>.from(
        jsonDecode(_p.getString('appointments') ?? '[]'));
    _deletedServerMedicationIds = (_p.getStringList('deleted_medication_ids') ?? [])
        .map(int.tryParse).whereType<int>().toSet();

    // Try a background sync if logged in
    if (loggedIn) {
      syncWithServer();
    }
  }

  static Future<void> save() async {
    await _p.setString('meds', jsonEncode(meds.map((m) => m.toJson()).toList()));
    await _p.setString('log', jsonEncode(log));
    await _p.setString('appointments', jsonEncode(appointments));
    await _p.setStringList('deleted_medication_ids', _deletedServerMedicationIds.map((id) => id.toString()).toList());
  }

  // ---- Account & Profile ----
  static String get name => _p.getString('name') ?? '';
  static String get phone => _p.getString('phone') ?? '';
  static String get clinicId => _p.getString('clinicId') ?? '';
  static String get diseaseCategory => _p.getString('diseaseCategory') ?? 'General Outpatient';
  static bool get smsConsent => _p.getBool('smsConsent') ?? false;
  static bool get registered => phone.isNotEmpty;
  static bool get loggedIn => _p.getBool('loggedIn') ?? false;
  static set loggedIn(bool v) => _p.setBool('loggedIn', v);

  static Future<void> setProfile({
    required String name,
    required String phone,
    String clinicId = '',
    String diseaseCategory = 'General Outpatient',
    bool smsConsent = false,
  }) async {
    final previousPhone = _p.getString('phone') ?? '';
    if (previousPhone.isNotEmpty && previousPhone != phone) {
      for (final medication in meds) {
        await Notifier.cancel(medication);
      }
      meds.clear();
      log.clear();
      appointments.clear();
      _deletedServerMedicationIds.clear();
      await save();
    }
    await _p.setString('name', name);
    await _p.setString('phone', phone);
    await _p.setString('clinicId', clinicId);
    await _p.setString('diseaseCategory', diseaseCategory);
    await _p.setBool('smsConsent', smsConsent);
    await _p.setBool('loggedIn', true);
  }

  static Future<bool> setSmsConsent(bool consent) async {
    await _p.setBool('smsConsent', consent);
    return ApiService.updateSmsConsent(consent);
  }

  static Future<void> clearAuth() async {
    await _p.setBool('loggedIn', false);
    await ApiService.setToken(null);
  }

  // ---- Doses & Adherence ----
  static String day([DateTime? d]) =>
      (d ?? DateTime.now()).toIso8601String().substring(0, 10);

  static String key(Medication m, String time) => '${m.id}|${day()}|$time';

  static Future<void> mark(Medication m, String time, String status) async {
    final k = key(m, time);
    final previous = log[k];
    if (previous == status) return;
    log[k] = status;
    if (status == 'taken' && previous != 'taken' && m.pills > 0) {
      m.pills--;
    } else if (previous == 'taken' && status != 'taken') {
      m.pills++;
    }
    await save();

    if (m.serverId != null) {
      ApiService.syncDoseLog(medicationId: m.serverId!, scheduledTime: time, status: status, date: day());
    }
  }

  // Share of logged doses that were taken, 0 to 100. Null if nothing logged yet.
  static int? get adherence {
    if (log.isEmpty) return null;
    return (log.values.where((s) => s == 'taken').length * 100 / log.length).round();
  }

  // ---- Medication CRUD ----
  static Future<void> addMedication(Medication m) async {
    meds.add(m);
    await save();
    await Notifier.schedule(m);

    if (loggedIn && ApiService.token != null) {
      final serverId = await ApiService.syncCreateMedication(m);
      if (serverId != null) {
        m.serverId = serverId;
        await save();
      }
    }
  }

  static Future<void> deleteMedication(Medication m) async {
    await Notifier.cancel(m);
    meds.remove(m);
    if (m.serverId != null) _deletedServerMedicationIds.add(m.serverId!);
    await save();

    // Sync to backend
    if (m.serverId != null) {
      if (await ApiService.syncDeleteMedication(m.serverId!)) {
        _deletedServerMedicationIds.remove(m.serverId!);
      }
      await save();
    }
  }

  // ---- Appointments & Refill Tracking ----
  static Future<void> addAppointment(String date, String dept, String purpose) async {
    appointments.add({
      'appointment_date': date,
      'clinic_department': dept,
      'purpose': purpose,
    });
    await save();

    // Sync to backend
    ApiService.createAppointment(
      appointmentDate: date,
      clinicDepartment: dept,
      purpose: purpose,
    );
  }

  // ---- Cloud Sync ----
  static Future<bool> syncWithServer() async {
    if (!loggedIn || ApiService.token == null) return false;
    try {
      for (final serverId in _deletedServerMedicationIds.toList()) {
        if (await ApiService.syncDeleteMedication(serverId)) _deletedServerMedicationIds.remove(serverId);
      }
      await save();
      await ApiService.updateSmsConsent(smsConsent);
      for (final medication in meds.where((m) => m.serverId == null).toList()) {
        final serverId = await ApiService.syncCreateMedication(medication);
        if (serverId != null) medication.serverId = serverId;
      }
      final remoteMeds = await ApiService.fetchRemoteMedications();
      if (remoteMeds == null) return false;
      final pendingLocal = meds.where((m) => m.serverId == null).toList();
      for (final remote in remoteMeds) {
        final existing = meds.where((m) => m.serverId == remote.serverId).firstOrNull;
        if (existing != null) {
          remote.id = existing.id;
          remote.localRemindersEnabled = existing.localRemindersEnabled;
        }
      }
      for (final previous in meds) {
        await Notifier.cancel(previous);
      }
      meds = [...remoteMeds.where((m) => m.active), ...pendingLocal];
      for (final m in meds) {
        await Notifier.cancel(m);
        await Notifier.schedule(m);
      }

      for (final entry in log.entries.toList()) {
        final parts = entry.key.split('|');
        if (parts.length != 3) continue;
        final localId = int.tryParse(parts[0]);
        final medication = meds.where((m) => m.id == localId).firstOrNull;
        if (medication?.serverId == null) continue;
        await ApiService.syncDoseLog(
          medicationId: medication!.serverId!,
          scheduledTime: parts[2],
          status: entry.value,
          date: parts[1],
        );
      }

      final remoteHistory = await ApiService.fetchDoseHistory();
      if (remoteHistory != null) {
        for (final dose in remoteHistory) {
          final serverId = (dose['medication_id'] as num?)?.toInt();
          final medication = meds.where((m) => m.serverId == serverId).firstOrNull;
          if (medication == null) continue;
          final date = dose['date'].toString().substring(0, 10);
          final time = dose['scheduled_time'].toString();
          final key = '${medication.id}|$date|$time';
          log.putIfAbsent(key, () => dose['status'].toString());
        }
      }

      final remoteAppts = await ApiService.fetchAppointments();
      if (remoteAppts != null) {
        appointments = remoteAppts;
      }

      await save();
      return true;
    } catch (_) {
      return false;
    }
  }
}
