import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/local_first_repository.dart';
import 'attendance_models.dart';

/// Catatan masuk yang belum pulang lebih dari ini dianggap "lupa pulang".
const kStaleHours = 16;

class EmployeeRepository extends LocalFirstRepository<Employee> {
  EmployeeRepository(super.ref);
  @override
  String get collection => 'employees';
  @override
  Employee fromMap(Map<String, dynamic> m) => Employee.fromMap(m);
  @override
  Map<String, dynamic> toMap(Employee e) => e.toMap();
  @override
  String idOf(Employee e) => e.id;
}

class AttendanceRepository extends LocalFirstRepository<Attendance> {
  AttendanceRepository(super.ref);
  @override
  String get collection => 'attendance';
  @override
  Attendance fromMap(Map<String, dynamic> m) => Attendance.fromMap(m);
  @override
  Map<String, dynamic> toMap(Attendance a) => a.toMap();
  @override
  String idOf(Attendance a) => a.id;
}

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(ref),
);
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(ref),
);

final employeesProvider = StreamProvider<List<Employee>>(
  (ref) => ref
      .watch(employeeRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      ),
);

final attendanceProvider = StreamProvider<List<Attendance>>(
  (ref) => ref
      .watch(attendanceRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.clockIn.compareTo(a.clockIn))),
);

// ---- PIN ----
String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

String newSalt() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

bool verifyPin(Employee e, String pin) =>
    e.hasPin && hashPin(pin, e.pinSalt) == e.pinHash;

bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

// ---- status ----
int get _staleLimit => DateTime.now()
    .subtract(const Duration(hours: kStaleHours))
    .millisecondsSinceEpoch;

/// Catatan masuk yang masih terbuka dan belum basi (daftar sudah urut terbaru).
Attendance? openRecordOf(List<Attendance> all, String employeeId) => all
    .where(
      (a) => a.employeeId == employeeId && a.isOpen && a.clockIn >= _staleLimit,
    )
    .firstOrNull;

bool isStale(Attendance a) => a.isOpen && a.clockIn < _staleLimit;

// ---- aksi ----
Future<void> clockIn(WidgetRef ref, Employee e) => ref
    .read(attendanceRepositoryProvider)
    .save(
      Attendance(
        id: const Uuid().v4(),
        employeeId: e.id,
        employeeName: e.name,
        clockIn: DateTime.now().millisecondsSinceEpoch,
      ),
    );

Future<void> clockOut(WidgetRef ref, Attendance a) => ref
    .read(attendanceRepositoryProvider)
    .save(a.copyWith(clockOut: DateTime.now().millisecondsSinceEpoch));
