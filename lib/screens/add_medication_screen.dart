import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/medication.dart';
import '../services/language_service.dart';
import '../services/store.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _dose = TextEditingController();
  final TextEditingController _pills = TextEditingController(text: '30');
  final TextEditingController _instructions = TextEditingController();
  final List<String> _times = ['08:00'];
  final Set<int> _daysOfWeek = {0, 1, 2, 3, 4, 5, 6};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _smsEnabled = false;
  bool _localRemindersEnabled = true;
  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _pills.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (t == null) return;
    final s = hhmm(t.hour, t.minute);
    if (!_times.contains(s)) setState(() => _times.add(s));
    _times.sort();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _times.isEmpty || _daysOfWeek.isEmpty ||
        (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a medicine name, time and at least one day. Check the treatment dates.')),
      );
      return;
    }

    final m = Medication(
      id: DateTime.now().millisecondsSinceEpoch % 100000000,
      name: _name.text.trim(),
      dose: _dose.text.trim(),
      times: _times,
      pills: int.tryParse(_pills.text) ?? 0,
      daysOfWeek: _daysOfWeek.toList()..sort(),
      startDate: _startDate == null ? null : Store.day(_startDate),
      endDate: _endDate == null ? null : Store.day(_endDate),
      instructions: _instructions.text.trim(),
      smsEnabled: _smsEnabled,
      localRemindersEnabled: _localRemindersEnabled,
    );

    await Store.addMedication(m);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LanguageService.t('add_medicine'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(LanguageService.t('medicine_name'), Icons.medication),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dose,
              decoration: _decoration(LanguageService.t('dose_hint'), Icons.local_pharmacy),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pills,
              keyboardType: TextInputType.number,
              decoration: _decoration(LanguageService.t('pills_in_stock'), Icons.inventory_2),
            ),
            const SizedBox(height: 24),
            Text(
              LanguageService.t('reminder_times'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _times)
                  Chip(
                    label: Text(prettyTime(t), style: const TextStyle(fontSize: 18)),
                    onDeleted: () => setState(() => _times.remove(t)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(LanguageService.t('add_time'), style: const TextStyle(fontSize: 18)),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Days of the week', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 0; day < _dayLabels.length; day++)
                  FilterChip(
                    label: Text(_dayLabels[day]),
                    selected: _daysOfWeek.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _daysOfWeek.add(day);
                      } else {
                        _daysOfWeek.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (value != null) setState(() => _startDate = value);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(_startDate == null ? 'Start date (optional)' : 'Starts ${Store.day(_startDate)}'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(context: context, initialDate: _endDate ?? _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (value != null) setState(() => _endDate = value);
                },
                icon: const Icon(Icons.stop),
                label: Text(_endDate == null ? 'End date (optional)' : 'Ends ${Store.day(_endDate)}'),
              )),
            ]),
            if (_startDate != null || _endDate != null)
              TextButton(onPressed: () => setState(() { _startDate = null; _endDate = null; }), child: const Text('Clear treatment dates')),
            const SizedBox(height: 12),
            TextField(controller: _instructions, maxLines: 2,
              decoration: _decoration('Instructions (optional)', Icons.notes)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('SMS reminders'),
              subtitle: const Text('Requires SMS consent and clinic SMS service setup.'),
              value: _smsEnabled,
              onChanged: (value) => setState(() => _smsEnabled = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Phone reminders'),
              subtitle: const Text('Scheduled on this phone. SMS reminders are controlled separately.'),
              value: _localRemindersEnabled,
              onChanged: (value) => setState(() => _localRemindersEnabled = value),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _save,
                child: Text(LanguageService.t('save'), style: const TextStyle(fontSize: 20)),
              ),
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
