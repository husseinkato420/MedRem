import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _prefKey = 'selected_language';
  static final ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'MedRemind',
      'today': 'Today',
      'medicines': 'My medicines',
      'history': 'History',
      'profile': 'Profile',
      'clinic': 'Clinic',
      'settings': 'Settings',
      'sign_out': 'Sign out',
      'hello': 'Hello',
      'doses_taken_today': 'doses taken today',
      'all_doses_taken': 'Well done! All doses taken today.',
      'taken': 'Taken',
      'skip': 'Skip',
      'skipped': 'Skipped',
      'overdue': 'Overdue',
      'coming_up': 'Coming up',
      'add_medicine': 'Add a medicine',
      'medicine_name': 'Medicine name',
      'dose': 'Dose',
      'dose_hint': 'Dose, for example 1 tablet',
      'pills_left': 'pills left',
      'pills_in_stock': 'Pills you have now',
      'tap_to_update': 'tap to update',
      'reminder_times': 'Reminder times',
      'add_time': 'Add time',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'is_finished': 'is finished',
      'refill_warning': 'Time to collect a refill from the clinic',
      'adherence_title': 'of doses taken',
      'no_medicines': 'No medicines yet.\nOpen the Medicines tab to add one.',
      'no_history': 'No dose logs yet.\nMark doses in the Today screen.',
      'clinic_title': 'Luweero Health Centre',
      'clinic_opd': 'Outpatient Department (OPD)',
      'clinic_location': 'Luweero District, Central Uganda',
      'clinic_phone': '+256 414 690 000 / 0772 000 000',
      'appointments': 'Refill Appointments',
      'schedule_refill': 'Add Next Refill Date',
      'next_refill': 'Next Scheduled Refill',
      'language': 'Language / Olulimi',
      'backend_server': 'Server Address (API IP)',
      'test_reminder': 'Send a test reminder',
      'reminders_subtitle': 'Every day at your dose times',
      'sync_status': 'Server Sync',
      'sync_now': 'Sync with Clinic',
      'synced': 'Connected & Synced',
      'offline': 'Offline (Saved locally)',
      'create_account': 'Create account',
      'sign_in': 'Sign in',
      'full_name': 'Full name',
      'phone_number': 'Phone number',
      'password': 'Password',
      'confirm_password': 'Confirm password',
      'disease_category': 'OPD Clinic / Condition',
      'clinic_id': 'OPD Card / Clinic Number',
      'sms_consent': 'Receive SMS text reminders on this phone',
      'already_account': 'Already have an account? Sign in',
      'need_account': 'Need an account? Register',
      'welcome_title': 'Luweero Health Centre OPD',
      'welcome_sub': 'Personal medication reminders & adherence tracking',
      'choose_language': 'Language'
    },
    'lg': {
      'app_title': 'MedRemind',
      'today': 'Leero',
      'medicines': 'Eddagala Lyange',
      'history': 'Ebyafaayo',
      'profile': 'Ebikukwatako',
      'clinic': 'Eddwaliro',
      'settings': 'Enteekateeka',
      'sign_out': 'Vaamu',
      'hello': 'Osiibye otya',
      'doses_taken_today': 'ku miti egimiddwa leero',
      'all_doses_taken': 'Webale nnyo! Omaze emiti gyonna egya leero.',
      'taken': 'Ndimize',
      'skip': 'Subizza',
      'skipped': 'Ndisubizza',
      'overdue': 'Liyiseeko obudde',
      'coming_up': 'Ligenda kuddako',
      'add_medicine': 'Yongerako eddagala',
      'medicine_name': 'Erinnya ly\'eddagala',
      'dose': 'Omuwendo',
      'dose_hint': 'Omuwendo, gamba empeke 1',
      'pills_left': 'empeke ezisigaddewo',
      'pills_in_stock': 'Empeke z\'olina kati',
      'tap_to_update': 'nyiga wano okukyusa',
      'reminder_times': 'Obudde bw\'okumira',
      'add_time': 'Yongerako obudde',
      'save': 'Kaza',
      'cancel': 'Sazaamu',
      'delete': 'Sangula',
      'is_finished': 'liweddeko',
      'refill_warning': 'Obudde butuuse okugenda ku ddwaliro ofune eddala',
      'adherence_title': 'ku buli kikumi eby\'eddagala eryamiziddwa',
      'no_medicines': 'Tewannabaawo ddagala.\nGgulawo ettabi ly\'eddagala oyongereko.',
      'no_history': 'Tewannabaawo bifaayo.\nLamba eddagala ly\'omize ku muko gwa Leero.',
      'clinic_title': 'Eddwaliro lya Luweero HC',
      'clinic_opd': 'Ekitongole ky\'Abalwadde ab\'ebweru (OPD)',
      'clinic_location': 'Disitulikiti y\'e Luweero, Uganda',
      'clinic_phone': '+256 414 690 000 / 0772 000 000',
      'appointments': 'Ensisinkano z\'okufuna eddagala',
      'schedule_refill': 'Wandiika olunaku oluddako',
      'next_refill': 'Olunaku lw\'okufuna eddagala',
      'language': 'Olulimi (Language)',
      'backend_server': 'Endagiriro ya Seva (IP)',
      'test_reminder': 'Gezako okusindika ekirowoozo',
      'reminders_subtitle': 'Buli lunaku mu budde bwo obw\'okumira',
      'sync_status': 'Okugatta n\'olukalala lw\'eddwaliro',
      'sync_now': 'Kwataagana n\'eddwaliro',
      'synced': 'Waliwo enkolagana n\'eddwaliro',
      'offline': 'Tewali yintaneeti (Bikaziddwa ku ssimu)',
      'create_account': 'Kolawo akaawunti',
      'sign_in': 'Yingira',
      'full_name': 'Amannya go gonna',
      'phone_number': 'Ennamba y\'essimu',
      'password': 'Ekigambo ekisumulula',
      'confirm_password': 'Ddamu ekigambo ekisumulula',
      'disease_category': 'Ekika ky\'obulwadde (OPD Clinic)',
      'clinic_id': 'Ennamba y\'ekkaadi ku ddwaliro',
      'sms_consent': 'Nzikiriza okufuna obubaka bwa SMS ku ssimu eno',
      'already_account': 'Olina akaawunti? Yingira',
      'need_account': 'Tolina kaawunti? Wandiisa',
      'welcome_title': 'Eddwaliro lya Luweero HC OPD',
      'welcome_sub': 'Okujjukiza n\'okulondoola obujjanjabi bw\'omulwadde',
      'choose_language': 'Olulimi'
    }
  };

  static Future<void> init(SharedPreferences p) async {
    final saved = p.getString(_prefKey) ?? 'en';
    currentLanguage.value = saved;
  }

  static Future<void> setLanguage(String lang) async {
    if (lang != 'en' && lang != 'lg') return;
    currentLanguage.value = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, lang);
  }

  static String t(String key) {
    final lang = currentLanguage.value;
    return _translations[lang]?[key] ?? _translations['en']?[key] ?? key;
  }
}
