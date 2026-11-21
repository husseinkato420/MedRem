import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/store.dart';
import '../widgets/logo_badge.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    final phone = _phone.text.trim();
    final password = _password.text;

    if (phone.isEmpty || password.isEmpty) {
      _showMessage('Please enter your phone number and password');
      return;
    }

    setState(() => _isLoading = true);

    // Attempt online sign in with Node.js backend
    final res = await ApiService.login(phone: phone, password: password);

    setState(() => _isLoading = false);

    if (res['success']) {
      final user = res['data']['user'];
      await Store.setProfile(
        name: user['fullName'] ?? 'Patient',
        phone: user['phone'] ?? phone,
        clinicId: user['clinicId'] ?? '',
        diseaseCategory: user['diseaseCategory'] ?? 'General Outpatient',
        smsConsent: user['smsConsent'] == true,
      );
      await Store.syncWithServer();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // Fallback: check if user exists locally
      if (Store.registered && phone == Store.phone) {
        Store.loggedIn = true;
        if (!mounted) return;
        _showMessage('Working in offline mode.');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        _showMessage(res['message'] ?? 'Incorrect phone number or password.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LanguageService.t('sign_in'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LogoBadge(size: 90),
            const SizedBox(height: 24),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _decoration(LanguageService.t('phone_number'), Icons.phone),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: _decoration(LanguageService.t('password'), Icons.lock),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(LanguageService.t('sign_in'), style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              ),
              child: Text(LanguageService.t('need_account')),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 18),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
