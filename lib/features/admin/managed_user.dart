import '../auth/auth_providers.dart';
import '../roles/role_models.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.name,
    required this.position,
    required this.roleKey,
    required this.outletId,
    required this.active,
  });

  final String id;
  final String username;
  final String name;
  final String position;
  final String roleKey; // = roles.key (peran bawaan maupun buatan owner)
  final String? outletId;
  final bool active;

  factory ManagedUser.fromJson(Map<String, dynamic> m) => ManagedUser(
    id: m['id'] as String,
    username: m['username'] as String? ?? '',
    name: m['name'] as String? ?? '',
    position: m['position'] as String? ?? '',
    roleKey: m['role'] as String? ?? '',
    outletId: m['outlet_id'] as String?,
    active: m['active'] as bool? ?? true,
  );
}

/// Petunjuk untuk UI saja (server tetap yang memutuskan).
bool canManageUser(AppUser actor, ManagedUser t, List<RoleOption> options) {
  if (t.id == actor.uid || t.roleKey == 'owner') return false;
  if (actor.isOwner) return true;
  if (!actor.can('users.update')) return false;
  final staff = {
    for (final o in options)
      if (o.assignable) o.key,
  };
  return t.outletId == actor.outletId && staff.contains(t.roleKey);
}
