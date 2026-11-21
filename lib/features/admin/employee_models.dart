/// Data karyawan dari server (/employees): orang yang bekerja, dengan atau tanpa akun login.
class EmployeeInfo {
  const EmployeeInfo({
    required this.id,
    required this.name,
    required this.position,
    required this.outletId,
    required this.active,
    required this.hasAccount,
    required this.username,
    required this.role,
    required this.roleName,
    required this.pinSet,
    required this.canClock,
  });

  final String id;
  final String name;
  final String position;
  final String? outletId;
  final bool active;
  final bool hasAccount;
  final String? username;
  final String role;
  final String roleName;
  final bool pinSet; // PIN absen bersama sudah diatur
  final bool canClock; // muncul di absen bersama

  factory EmployeeInfo.fromJson(Map<String, dynamic> m) => EmployeeInfo(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    position: m['position'] as String? ?? '',
    outletId: m['outlet_id'] as String?,
    active: m['active'] as bool? ?? true,
    hasAccount: m['has_account'] as bool? ?? false,
    username: m['username'] as String?,
    role: m['role'] as String? ?? '',
    roleName: m['role_name'] as String? ?? '',
    pinSet: m['attendance_pin_set'] as bool? ?? false,
    canClock: m['can_clock'] as bool? ?? true,
  );
}
