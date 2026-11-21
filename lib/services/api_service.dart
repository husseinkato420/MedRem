import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/medication.dart';

class ApiService {
  static const String _prefServerKey = 'backend_server_url';
  static const String _prefTokenKey = 'auth_jwt_token';

  // Default host: 10.0.2.2 for Android emulator, localhost for web/desktop
  static String defaultBaseUrl = kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? 'http://localhost:3000'
      : 'http://10.0.2.2:3000';

  static late SharedPreferences _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static String? _token;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    if (kIsWeb) {
      _token = prefs.getString(_prefTokenKey);
      return;
    }
    try {
      _token = await _secureStorage.read(key: _prefTokenKey);
      if (_token == null) {
        // Migrate an existing token out of plaintext preferences once.
        _token = prefs.getString(_prefTokenKey);
        if (_token != null) {
          await _secureStorage.write(key: _prefTokenKey, value: _token);
          await prefs.remove(_prefTokenKey);
        }
      }
    } catch (_) {
      _token = prefs.getString(_prefTokenKey);
    }
  }

  static String get baseUrl {
    return _prefs.getString(_prefServerKey) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    String clean = url.trim();
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    await _prefs.setString(_prefServerKey, clean);
  }

  static String? get token => _token;

  static Future<void> setToken(String? t) async {
    if (t == null) {
      _token = null;
      if (kIsWeb) {
        await _prefs.remove(_prefTokenKey);
      } else {
        try { await _secureStorage.delete(key: _prefTokenKey); }
        catch (_) { await _prefs.remove(_prefTokenKey); }
      }
    } else {
      _token = t;
      if (kIsWeb) {
        await _prefs.setString(_prefTokenKey, t);
      } else {
        try { await _secureStorage.write(key: _prefTokenKey, value: t); }
        catch (_) { await _prefs.setString(_prefTokenKey, t); }
      }
    }
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // -------------------------------------------------------------
  // Authentication
  // -------------------------------------------------------------
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String password,
    String diseaseCategory = 'General Outpatient',
    String clinicId = '',
    bool smsConsent = true,
    String preferredLanguage = 'en',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName,
              'phone': phone,
              'password': password,
              'role': 'patient',
              'diseaseCategory': diseaseCategory,
              'clinicId': clinicId,
              'smsConsent': smsConsent,
              'preferredLanguage': preferredLanguage,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        if (data['token'] != null) await setToken(data['token']);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed.'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: could not connect to server ($e)'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (data['token'] != null) await setToken(data['token']);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed.'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to server. Working in offline mode.'};
    }
  }

  // -------------------------------------------------------------
  // Medications Sync
  // -------------------------------------------------------------
  static Future<List<Medication>?> fetchRemoteMedications() async {
    if (token == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/medications'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['medications'] as List).map((m) {
          return Medication(
            id: (m['id'] as num).toInt(),
            serverId: (m['id'] as num).toInt(),
            name: m['name'],
            dose: m['dose'] ?? '',
            times: List<String>.from(m['times'] ?? []),
            pills: m['pills'] ?? 0,
            daysOfWeek: List<int>.from(m['daysOfWeek'] ?? const [0, 1, 2, 3, 4, 5, 6]),
            startDate: m['startDate']?.toString(),
            endDate: m['endDate']?.toString(),
            instructions: m['instructions'] ?? '',
            smsEnabled: m['smsEnabled'] == true,
            active: m['active'] != false,
          );
        }).toList();
        return list;
      }
    } catch (_) {}
    return null;
  }

  static Future<int?> syncCreateMedication(Medication m) async {
    if (token == null) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/medications'),
            headers: _headers,
            body: jsonEncode({
              'name': m.name,
              'dose': m.dose,
              'times': m.times,
              'daysOfWeek': m.daysOfWeek,
              'startDate': m.startDate,
              'endDate': m.endDate,
              'instructions': m.instructions,
              'pills': m.pills,
              'smsEnabled': m.smsEnabled,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 201) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['medication']['id'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> syncDeleteMedication(int medId) async {
    if (token == null) return false;
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/api/medications/$medId'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateSmsConsent(bool consent) async {
    if (token == null) return false;
    try {
      final res = await http.patch(Uri.parse('$baseUrl/api/auth/preferences'), headers: _headers,
          body: jsonEncode({'smsConsent': consent})).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // -------------------------------------------------------------
  // Dose Logging
  // -------------------------------------------------------------
  static Future<bool> syncDoseLog({
    required int medicationId,
    required String scheduledTime,
    required String status,
    String? date,
  }) async {
    if (token == null) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/doses/log'),
            headers: _headers,
            body: jsonEncode({
              'medicationId': medicationId,
              'scheduledTime': scheduledTime,
              'status': status,
              'date': date,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchDoseHistory() async {
    if (token == null) return null;
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/doses/history'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['history'] ?? []);
    } catch (_) { return null; }
  }

  // -------------------------------------------------------------
  // Appointments
  // -------------------------------------------------------------
  static Future<List<Map<String, dynamic>>?> fetchAppointments() async {
    if (token == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/appointments'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['appointments'] ?? []);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> createAppointment({
    required String appointmentDate,
    String clinicDepartment = 'Luweero Health Centre OPD',
    String purpose = 'Medication Refill & Review',
    String notes = '',
  }) async {
    if (token == null) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/appointments'),
            headers: _headers,
            body: jsonEncode({
              'appointmentDate': appointmentDate,
              'clinicDepartment': clinicDepartment,
              'purpose': purpose,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
