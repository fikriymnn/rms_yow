import '../auth/auth_providers.dart';

const staffRoles = [
  AppRole.cashier,
  AppRole.waiter,
  AppRole.kitchen,
  AppRole.warehouse,
];

String roleLabel(AppRole r) => switch (r) {
  AppRole.owner => 'Owner',
  AppRole.manager => 'Manager',
  AppRole.cashier => 'Kasir',
  AppRole.waiter => 'Waiter',
  AppRole.kitchen => 'Dapur',
  AppRole.warehouse => 'Gudang',
};

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.name,
    required this.position,
    required this.role,
    required this.outletId,
    required this.active,
  });

  final String id;
  final String username;
  final String name;
  final String position;
  final AppRole role;
  final String? outletId;
  final bool active;

  factory ManagedUser.fromJson(Map<String, dynamic> m) => ManagedUser(
    id: m['id'] as String,
    username: m['username'] as String? ?? '',
    name: m['name'] as String? ?? '',
    position: m['position'] as String? ?? '',
    role: AppRole.values.firstWhere(
      (r) => r.name == m['role'],
      orElse: () => AppRole.waiter,
    ),
    outletId: m['outlet_id'] as String?,
    active: m['active'] as bool? ?? true,
  );
}

/// Sama dengan aturan di server (server tetap yang memutuskan).
bool canManageUser(AppUser actor, ManagedUser t) {
  if (t.id == actor.uid || t.role == AppRole.owner) return false;
  if (actor.role == AppRole.owner) return true;
  if (actor.role == AppRole.manager) {
    return t.outletId == actor.outletId && staffRoles.contains(t.role);
  }
  return false;
}

List<AppRole> creatableRoles(AppUser actor) => switch (actor.role) {
  AppRole.owner => [AppRole.manager, ...staffRoles],
  AppRole.manager => staffRoles,
  _ => const [],
};
