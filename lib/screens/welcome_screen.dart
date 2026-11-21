import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/language_service.dart';
import '../widgets/logo_badge.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentLang = LanguageService.currentLanguage.value;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Language switch pill at top
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.language, size: 20, color: AppColors.primary),
                  label: Text(
                    currentLang == 'en' ? 'Oluganda' : 'English',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onPressed: () async {
                    await LanguageService.setLanguage(currentLang == 'en' ? 'lg' : 'en');
                    setState(() {});
                  },
                ),
              ),
              const Spacer(),
              const LogoBadge(size: 110),
              const SizedBox(height: 16),
              Text(
                LanguageService.t('app_title'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.dark),
              ),
              const SizedBox(height: 6),
              Text(
                LanguageService.t('welcome_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                LanguageService.t('welcome_sub'),
                style: const TextStyle(fontSize: 14, color: AppColors.grey),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  ),
                  child: Text(LanguageService.t('create_account'), style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ),
                  child: Text(LanguageService.t('sign_in'), style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
