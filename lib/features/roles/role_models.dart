/// Satu aksi pada sebuah fitur, mis. fitur "menu" punya aksi create/read/...
class PermAction {
  const PermAction(this.key, this.label, this.permission);
  final String key;
  final String label;
  final String permission; // "menu.create"

  factory PermAction.fromJson(Map<String, dynamic> m) => PermAction(
    m['key'] as String,
    m['label'] as String,
    m['permission'] as String,
  );
}

class PermFeature {
  const PermFeature(this.key, this.label, this.group, this.actions);
  final String key;
  final String label;
  final String group;
  final List<PermAction> actions;

  factory PermFeature.fromJson(Map<String, dynamic> m) => PermFeature(
    m['key'] as String,
    m['label'] as String,
    m['group'] as String,
    [
      for (final a in m['actions'] as List<dynamic>)
        PermAction.fromJson(a as Map<String, dynamic>),
    ],
  );
}

/// Master data role dari server.
class RoleInfo {
  const RoleInfo({
    required this.key,
    required this.name,
    required this.description,
    required this.isSystem,
    required this.isStaff,
    required this.locked,
    required this.permissions,
    required this.userCount,
  });
  final String key;
  final String name;
  final String description;
  final bool isSystem; // peran bawaan: tidak bisa dihapus
  final bool isStaff; // boleh dikelola manager outlet
  final bool locked; // owner: tidak bisa diubah
  final Set<String> permissions;
  final int userCount;

  factory RoleInfo.fromJson(Map<String, dynamic> m) => RoleInfo(
    key: m['key'] as String,
    name: m['name'] as String? ?? '',
    description: m['description'] as String? ?? '',
    isSystem: m['is_system'] as bool? ?? false,
    isStaff: m['is_staff'] as bool? ?? false,
    locked: m['locked'] as bool? ?? false,
    permissions: {
      for (final p in (m['permissions'] as List<dynamic>? ?? const []))
        p as String,
    },
    userCount: (m['user_count'] as num?)?.toInt() ?? 0,
  );
}

/// Pilihan role di form pengguna.
class RoleOption {
  const RoleOption(this.key, this.name, this.assignable);
  final String key;
  final String name;
  final bool assignable; // boleh diberikan oleh pengguna yang sedang login

  factory RoleOption.fromJson(Map<String, dynamic> m) => RoleOption(
    m['key'] as String,
    m['name'] as String? ?? m['key'] as String,
    m['assignable'] as bool? ?? false,
  );
}

/// Nama tampilan sebuah role; cadangan: label peran bawaan, lalu key-nya.
String roleNameOf(String key, List<RoleOption> options) {
  for (final o in options) {
    if (o.key == key) return o.name;
  }
  return kBuiltInRoleLabels[key] ?? key;
}

const kBuiltInRoleLabels = {
  'owner': 'Owner',
  'manager': 'Manager',
  'head_chef': 'Head Chef',
  'cashier': 'Kasir',
  'waiter': 'Waiter',
  'kitchen': 'Dapur',
  'warehouse': 'Gudang',
};
