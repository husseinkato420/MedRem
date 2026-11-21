import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/language_service.dart';
import '../services/store.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  Future<void> _scheduleNewRefill() async {
    DateTime now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final dateStr = pickedDate.toIso8601String().substring(0, 10);
    await Store.addAppointment(
      dateStr,
      'Luweero Health Centre OPD Clinic',
      'Routine Medication Refill & Review',
    );
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheduled refill appointment on $dateStr')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LanguageService.t('clinic'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Clinic Details Header Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.local_hospital, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LanguageService.t('clinic_title'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    LanguageService.t('clinic_opd'),
                    style: const TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageService.t('clinic_location'),
                    style: const TextStyle(color: AppColors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact Details
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_in_talk, color: AppColors.primary),
                  title: const Text('OPD Helpline / Ennamba y\'essimu'),
                  subtitle: const Text('+256 772 123 456 / +256 414 690 100'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.access_time, color: AppColors.primary),
                  title: const Text('Working Hours / Obudde bw\'okukola'),
                  subtitle: const Text('Monday - Friday: 8:00 AM - 5:00 PM\nEmergencies: 24/7'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_pharmacy, color: AppColors.primary),
                  title: const Text('Pharmacy & Dispensing'),
                  subtitle: const Text('Main Outpatient Pharmacy Counter 2'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Scheduled Clinic Refill Appointments Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LanguageService.t('appointments'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(LanguageService.t('schedule_refill')),
                onPressed: _scheduleNewRefill,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (Store.appointments.isEmpty)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No refill appointments scheduled.\nTap "+ Add Next Refill Date" to set one.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.grey),
                  ),
                ),
              ),
            )
          else
            for (final a in Store.appointments)
              Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: Text(
                    '${a['appointment_date']}'.substring(0, 10),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${a['clinic_department'] ?? "Luweero Health Centre OPD"}\n${a['purpose'] ?? "Medication Refill"}',
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
