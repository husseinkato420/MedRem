import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/language_service.dart';
import '../services/store.dart';
import 'contact_screen.dart';
import 'history_screen.dart';
import 'medicines_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0 = Today, 1 = Medicines, 2 = History, 3 = Profile
  int _selected = 0;

  void _signOut() async {
    await Store.clearAuth();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _go(int index) {
    setState(() => _selected = index);
    Navigator.pop(context);
  }

  void _open(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      LanguageService.t('today'),
      LanguageService.t('medicines'),
      LanguageService.t('history'),
      LanguageService.t('profile'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selected]),
        actions: [
          IconButton(
            tooltip: LanguageService.t('sync_now'),
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final ok = await Store.syncWithServer();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? LanguageService.t('synced')
                        : LanguageService.t('offline')),
                    duration: const Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.medication, color: AppColors.primary, size: 36),
              ),
              accountName: Text(Store.name.isEmpty ? 'Patient' : Store.name),
              accountEmail: Text(
                '${Store.phone} ${Store.clinicId.isNotEmpty ? "• ${Store.clinicId}" : ""}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: Text(LanguageService.t('today')),
              selected: _selected == 0,
              onTap: () => _go(0),
            ),
            ListTile(
              leading: const Icon(Icons.medication),
              title: Text(LanguageService.t('medicines')),
              selected: _selected == 1,
              onTap: () => _go(1),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(LanguageService.t('history')),
              selected: _selected == 2,
              onTap: () => _go(2),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(LanguageService.t('profile')),
              selected: _selected == 3,
              onTap: () => _go(3),
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: Text(LanguageService.t('clinic')),
              onTap: () => _open(const ContactScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(LanguageService.t('settings')),
              onTap: () => _open(const SettingsScreen()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(LanguageService.t('sign_out')),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      body: [
        const TodayScreen(),
        const MedicinesScreen(),
        const HistoryScreen(),
        const ProfileScreen(),
      ][_selected],
    );
  }
}
