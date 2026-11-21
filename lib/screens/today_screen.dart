import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/medication.dart';
import '../services/language_service.dart';
import '../services/store.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Future<void> _mark(Medication m, String time, String status) async {
    await Store.mark(m, time, status);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Only show doses covered by the medication's active dates and weekdays.
    final today = Store.day();
    final weekday = DateTime.now().weekday % 7;
    final doses = [
      for (final m in Store.meds.where((m) => m.active && m.daysOfWeek.contains(weekday) &&
          (m.startDate == null || today.compareTo(m.startDate!) >= 0) &&
          (m.endDate == null || today.compareTo(m.endDate!) <= 0)))
        for (final t in m.times) (m, t),
    ];
    doses.sort((a, b) => a.$2.compareTo(b.$2));

    final now = hhmm(DateTime.now().hour, DateTime.now().minute);
    final taken = doses.where((d) => Store.log[Store.key(d.$1, d.$2)] == 'taken').length;
    final low = Store.meds.where((m) => m.active && m.pills <= 5).toList();

    // Check for upcoming refill appointments
    final upcomingAppointments = Store.appointments.where((a) {
      final dateStr = (a['appointment_date'] ?? '').toString().substring(0, 10);
      return dateStr.isNotEmpty && dateStr.compareTo(Store.day()) >= 0;
    }).toList();

    if (doses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medication_outlined, size: 64, color: AppColors.grey),
              const SizedBox(height: 12),
              Text(
                LanguageService.t('no_medicines'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final firstName = Store.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary & Progress Card
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${LanguageService.t('hello')}${firstName.isNotEmpty ? " $firstName" : ""}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$taken of ${doses.length} ${LanguageService.t('doses_taken_today')}',
                  style: const TextStyle(fontSize: 17, color: AppColors.grey),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: doses.isEmpty ? 0 : taken / doses.length,
                  minHeight: 10,
                  color: AppColors.green,
                  backgroundColor: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                if (taken == doses.length && doses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    LanguageService.t('all_doses_taken'),
                    style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Upcoming Refill Appointment Card if exists
        for (final appt in upcomingAppointments)
          Card(
            color: const Color(0xFFE0F2FE),
            child: ListTile(
              leading: const Icon(Icons.event_note, color: AppColors.primary, size: 30),
              title: Text(
                '${LanguageService.t('next_refill')}: ${appt['appointment_date'].toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${appt['clinic_department'] ?? "Luweero Health Centre OPD"} • ${appt['purpose'] ?? "Refill"}',
              ),
            ),
          ),

        // Low Pill Stock Warnings
        for (final m in low)
          Card(
            color: const Color(0xFFFEF3C7),
            child: ListTile(
              leading: const Icon(Icons.warning_amber, color: AppColors.warn, size: 32),
              title: Text(
                m.pills == 0
                    ? '${m.name} ${LanguageService.t('is_finished')}'
                    : '${m.name}: ${m.pills} ${LanguageService.t('pills_left')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(LanguageService.t('refill_warning')),
            ),
          ),
        const SizedBox(height: 8),

        // Dose Action Cards
        for (final d in doses) _doseCard(d.$1, d.$2, now),
      ],
    );
  }

  Widget _doseCard(Medication m, String time, String now) {
    final status = Store.log[Store.key(m, time)];
    final overdue = status == null && time.compareTo(now) < 0;
    final color = status == 'taken'
        ? AppColors.green
        : (status == 'missed' || overdue)
            ? AppColors.red
            : AppColors.primary;
    final label = status == 'taken'
        ? LanguageService.t('taken')
        : status == 'missed'
            ? LanguageService.t('skipped')
            : overdue
                ? LanguageService.t('overdue')
                : LanguageService.t('coming_up');

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  prettyTime(time),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              m.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (m.dose.isNotEmpty)
              Text(
                m.dose,
                style: const TextStyle(fontSize: 16, color: AppColors.grey),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'taken' ? AppColors.green : Colors.grey.shade100,
                      foregroundColor: status == 'taken' ? Colors.white : Colors.black87,
                      elevation: status == 'taken' ? 2 : 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _mark(m, time, 'taken'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(LanguageService.t('taken'), style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: status == 'missed' ? AppColors.red : Colors.grey.shade700,
                      side: BorderSide(
                        color: status == 'missed' ? AppColors.red : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _mark(m, time, 'missed'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(LanguageService.t('skip'), style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
