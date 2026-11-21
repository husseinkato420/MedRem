import 'package:flutter_test/flutter_test.dart';
import 'package:medremind/models/medication.dart';

void main() {
  test('Medication survives save and load', () {
    final m = Medication(id: 1, name: 'Amlodipine', dose: '5mg', times: ['08:00', '20:00'], pills: 30);
    final back = Medication.fromJson(m.toJson());
    expect(back.name, 'Amlodipine');
    expect(back.times, ['08:00', '20:00']);
    expect(back.pills, 30);
  });

  test('Times show in 12 hour format', () {
    expect(prettyTime('00:05'), '12:05 AM');
    expect(prettyTime('14:30'), '2:30 PM');
  });
}
