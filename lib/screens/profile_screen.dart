import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/language_service.dart';
import '../services/store.dart';
import '../widgets/logo_badge.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const LogoBadge(size: 90),
            const SizedBox(height: 16),
            Text(
              Store.name.isEmpty ? 'Outpatient' : Store.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              Store.phone,
              style: const TextStyle(fontSize: 18, color: AppColors.grey),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge, color: AppColors.primary),
                      title: Text(LanguageService.t('clinic_id')),
                      subtitle: Text(
                        Store.clinicId.isNotEmpty ? Store.clinicId : 'OPD-PENDING',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.medical_services, color: AppColors.primary),
                      title: Text(LanguageService.t('disease_category')),
                      subtitle: Text(
                        Store.diseaseCategory,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.health_and_safety, color: AppColors.green),
                      title: const Text('Overall Adherence'),
                      subtitle: Text(
                        Store.adherence != null ? '${Store.adherence}% compliance' : 'No logs yet',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
