class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.position = '',
    this.pinHash = '',
    this.pinSalt = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String position;
  final String pinHash;
  final String pinSalt;
  final bool active;

  bool get hasPin => pinHash.isNotEmpty;

  Employee copyWith({
    String? name,
    String? position,
    String? pinHash,
    String? pinSalt,
    bool? active,
  }) => Employee(
    id: id,
    name: name ?? this.name,
    position: position ?? this.position,
    pinHash: pinHash ?? this.pinHash,
    pinSalt: pinSalt ?? this.pinSalt,
    active: active ?? this.active,
  );

  factory Employee.fromMap(Map<String, dynamic> m) => Employee(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    position: m['position'] as String? ?? '',
    pinHash: m['pinHash'] as String? ?? '',
    pinSalt: m['pinSalt'] as String? ?? '',
    active: m['active'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'position': position,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
    'active': active,
  };
}

class Attendance {
  const Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.clockIn,
    this.clockOut,
    this.note = '',
    this.edited = false,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final int clockIn;
  final int? clockOut;
  final String note;
  final bool edited;

  bool get isOpen => clockOut == null;
  int get minutes =>
      clockOut == null ? 0 : ((clockOut! - clockIn) / 60000).round();

  Attendance copyWith({
    int? clockIn,
    int? clockOut,
    String? note,
    bool? edited,
  }) => Attendance(
    id: id,
    employeeId: employeeId,
    employeeName: employeeName,
    clockIn: clockIn ?? this.clockIn,
    clockOut: clockOut ?? this.clockOut,
    note: note ?? this.note,
    edited: edited ?? this.edited,
  );

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
    id: m['id'] as String,
    employeeId: m['employeeId'] as String? ?? '',
    employeeName: m['employeeName'] as String? ?? '',
    clockIn: (m['clockIn'] as num?)?.toInt() ?? 0,
    clockOut: (m['clockOut'] as num?)?.toInt(),
    note: m['note'] as String? ?? '',
    edited: m['edited'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'clockIn': clockIn,
    'clockOut': clockOut,
    'note': note,
    'edited': edited,
  };
}

String durationText(int minutes) =>
    '${minutes ~/ 60}j ${(minutes % 60).toString().padLeft(2, '0')}m';
