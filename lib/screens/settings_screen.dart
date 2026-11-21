import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/notifier.dart';
import '../services/store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverController;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _updateServerUrl() async {
    await ApiService.setBaseUrl(_serverController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server address updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = LanguageService.currentLanguage.value;

    return Scaffold(
      appBar: AppBar(title: Text(LanguageService.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Switcher Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        LanguageService.t('language'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('English (Default)'),
                    value: 'en',
                    groupValue: currentLang,
                    onChanged: (val) async {
                      if (val != null) {
                        await LanguageService.setLanguage(val);
                        setState(() {});
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Oluganda (Luganda)'),
                    value: 'lg',
                    groupValue: currentLang,
                    onChanged: (val) async {
                      if (val != null) {
                        await LanguageService.setLanguage(val);
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Backend API Server Address Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        LanguageService.t('backend_server'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use http://10.0.2.2:3000 for Android emulator or your PC IP (e.g. http://192.168.1.5:3000) for a physical phone.',
                    style: TextStyle(fontSize: 13, color: AppColors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serverController,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            labelText: 'API URL',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _updateServerUrl,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(LanguageService.t('save')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(LanguageService.t('sync_now')),
                    onPressed: () async {
                      final ok = await Store.syncWithServer();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? LanguageService.t('synced')
                                : LanguageService.t('offline')),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            color: Colors.white,
            child: SwitchListTile(
              title: const Text('SMS medication reminders'),
              subtitle: const Text('Consent can be changed at any time. Standard SMS charges may apply.'),
              value: Store.smsConsent,
              onChanged: (value) async {
                final synced = await Store.setSmsConsent(value);
                if (mounted) setState(() {});
                if (mounted && !synced) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved on this device; the clinic server will update when you sync.')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Notifications Testing Card
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications, color: AppColors.primary),
                  title: const Text('Notifications / Okujjukiza'),
                  subtitle: Text(LanguageService.t('reminders_subtitle')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active, color: AppColors.green),
                  title: Text(LanguageService.t('test_reminder')),
                  onTap: () {
                    Notifier.test();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test reminder fired! Check notification bar.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
