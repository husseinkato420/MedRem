import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/medication.dart';
import '../services/language_service.dart';
import '../services/store.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Keys look like "medId|date|time". Newest first.
    final entries = Store.log.entries.toList();
    entries.sort((a, b) {
      final aKey = a.key.split('|').skip(1).join(' ');
      final bKey = b.key.split('|').skip(1).join(' ');
      return bKey.compareTo(aKey);
    });

    final takenCount = Store.log.values.where((v) => v == 'taken').length;
    final totalCount = Store.log.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  Store.adherence == null ? '--%' : '${Store.adherence}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: (Store.adherence ?? 0) >= 80 ? AppColors.green : AppColors.primary,
                  ),
                ),
                Text(
                  LanguageService.t('adherence_title'),
                  style: const TextStyle(fontSize: 18, color: AppColors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  '$takenCount / $totalCount ${LanguageService.t('doses_taken_today')}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                LanguageService.t('no_history'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.grey),
              ),
            ),
          )
        else
          for (final e in entries)
            Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  e.value == 'taken' ? Icons.check_circle : Icons.cancel,
                  color: e.value == 'taken' ? AppColors.green : AppColors.red,
                  size: 32,
                ),
                title: Text(
                  Store.meds
                          .where((m) => m.id.toString() == e.key.split('|')[0])
                          .map((m) => m.name)
                          .firstOrNull ??
                      'Medicine',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${e.key.split('|')[1]}  ${prettyTime(e.key.split('|')[2])}'),
                trailing: Text(
                  e.value == 'taken' ? LanguageService.t('taken') : LanguageService.t('skipped'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: e.value == 'taken' ? AppColors.green : AppColors.red,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
