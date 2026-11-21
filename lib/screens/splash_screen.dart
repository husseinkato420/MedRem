import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/store.dart';
import '../widgets/logo_badge.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _next();
  }

  // Wait 2 seconds, then go home if signed in, otherwise to the welcome screen.
  Future<void> _next() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Store.loggedIn ? const HomeScreen() : const WelcomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LogoBadge(size: 160),
              SizedBox(height: 24),
              Text('MedRemind',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.dark)),
              SizedBox(height: 8),
              Text('Luweero Health Centre', style: TextStyle(fontSize: 16, color: AppColors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
