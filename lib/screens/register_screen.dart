import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/store.dart';
import '../widgets/logo_badge.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _clinicId = TextEditingController();

  String _selectedDisease = 'General Outpatient';
  bool _smsConsent = false;
  bool _isLoading = false;

  final List<String> _diseases = [
    'General Outpatient',
    'HIV/AIDS',
    'Hypertension',
    'Tuberculosis',
    'Diabetes',
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _clinicId.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createAccount() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;
    final clinicId = _clinicId.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      _showMessage('Please fill in your name, phone number, and password');
      return;
    }
    if (phone.length < 10) {
      _showMessage('Enter a full phone number, for example 0771234567');
      return;
    }
    if (password.length < 10) {
      _showMessage('Use a password with at least 10 characters');
      return;
    }
    if (password != confirm) {
      _showMessage('The two passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    // Call backend API
    final res = await ApiService.register(
      fullName: name,
      phone: phone,
      password: password,
      diseaseCategory: _selectedDisease,
      clinicId: clinicId,
      smsConsent: _smsConsent,
      preferredLanguage: LanguageService.currentLanguage.value,
    );

    // Save profile locally regardless for offline resiliency
    await Store.setProfile(
      name: name,
      phone: phone,
      clinicId: clinicId,
      diseaseCategory: _selectedDisease,
      smsConsent: _smsConsent,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!res['success']) {
      // Show notice that account was saved locally
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${res['message']}. Working in offline mode.')),
      );
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LanguageService.t('create_account'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LogoBadge(size: 80),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(LanguageService.t('full_name'), Icons.person),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _decoration(LanguageService.t('phone_number'), Icons.phone),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedDisease,
              decoration: _decoration(LanguageService.t('disease_category'), Icons.medical_information),
              items: _diseases.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDisease = val);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _clinicId,
              decoration: _decoration('${LanguageService.t('clinic_id')} (Optional)', Icons.badge),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: _decoration(LanguageService.t('password'), Icons.lock),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: _decoration(LanguageService.t('confirm_password'), Icons.lock_outline),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              title: Text(LanguageService.t('sms_consent'), style: const TextStyle(fontSize: 14)),
              value: _smsConsent,
              onChanged: (val) => setState(() => _smsConsent = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _createAccount,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(LanguageService.t('create_account'), style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
