class Medication {
  int id;
  String name;
  String dose;
  List<String> times; // 24h "HH:mm", for example "08:00"
  int pills;
  List<int> daysOfWeek;
  String? startDate;
  String? endDate;
  String instructions;
  bool smsEnabled;
  bool localRemindersEnabled;
  bool active;
  int? serverId;

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.times,
    required this.pills,
    this.daysOfWeek = const [0, 1, 2, 3, 4, 5, 6],
    this.startDate,
    this.endDate,
    this.instructions = '',
    this.smsEnabled = true,
    this.localRemindersEnabled = true,
    this.active = true,
    this.serverId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'times': times,
        'pills': pills,
        'daysOfWeek': daysOfWeek,
        'startDate': startDate,
        'endDate': endDate,
        'instructions': instructions,
        'smsEnabled': smsEnabled,
        'localRemindersEnabled': localRemindersEnabled,
        'active': active,
        'serverId': serverId,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        dose: j['dose'] as String? ?? '',
        times: List<String>.from(j['times'] ?? const <String>[]),
        pills: (j['pills'] as num?)?.toInt() ?? 0,
        daysOfWeek: List<int>.from(j['daysOfWeek'] ?? const [0, 1, 2, 3, 4, 5, 6]),
        startDate: j['startDate']?.toString(),
        endDate: j['endDate']?.toString(),
        instructions: j['instructions'] as String? ?? '',
        smsEnabled: j['smsEnabled'] as bool? ?? true,
        localRemindersEnabled: j['localRemindersEnabled'] as bool? ?? true,
        active: j['active'] as bool? ?? true,
        serverId: (j['serverId'] as num?)?.toInt(),
      );
}

String hhmm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

// "14:30" -> "2:30 PM"
String prettyTime(String t) {
  int h = int.parse(t.substring(0, 2));
  return '${h % 12 == 0 ? 12 : h % 12}:${t.substring(3)} ${h < 12 ? 'AM' : 'PM'}';
}
