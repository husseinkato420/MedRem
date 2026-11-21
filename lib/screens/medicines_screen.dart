import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/medication.dart';
import '../services/language_service.dart';
import '../services/store.dart';
import 'add_medication_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  Future<void> _add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
    );
    setState(() {});
  }

  Future<void> _delete(Medication m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${LanguageService.t('delete')} ${m.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LanguageService.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(LanguageService.t('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Store.deleteMedication(m);
      setState(() {});
    }
  }

  // Update the pills in stock after a clinic refill.
  Future<void> _refill(Medication m) async {
    final controller = TextEditingController(text: m.pills.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${m.name}: ${LanguageService.t('pills_in_stock')}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: LanguageService.t('pills_in_stock'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              m.pills = int.tryParse(controller.text) ?? m.pills;
              await Store.save();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(LanguageService.t('save')),
          ),
        ],
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(LanguageService.t('add_medicine'), style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 12),
        if (Store.meds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                LanguageService.t('no_medicines'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.grey),
              ),
            ),
          )
        else if (Store.meds.where((m) => m.active).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(LanguageService.t('no_medicines'), textAlign: TextAlign.center)),
          )
        else
          for (final m in Store.meds.where((m) => m.active))
            Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                onTap: () => _refill(m),
                title: Text(
                  '${m.name} ${m.dose}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${m.times.map(prettyTime).join(', ')} · ${m.daysOfWeek.map((d) => const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d]).join(', ')}\n${m.startDate == null ? 'Starts now' : 'From ${m.startDate}'}${m.endDate == null ? '' : ' · Until ${m.endDate}'}\n${m.pills} ${LanguageService.t('pills_left')} (${LanguageService.t('tap_to_update')})',
                    style: TextStyle(
                      fontSize: 15,
                      color: m.pills <= 5 ? AppColors.red : AppColors.grey,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                  onPressed: () => _delete(m),
                ),
              ),
            ),
      ],
    );
  }
}
