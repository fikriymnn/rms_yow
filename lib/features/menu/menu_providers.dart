import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import 'menu_availability.dart';
import 'menu_item.dart';

class MenuRepository extends LocalFirstRepository<MenuItem> {
  MenuRepository(super.ref);
  @override
  String get collection => 'menu_items';
  @override
  MenuItem fromMap(Map<String, dynamic> m) => MenuItem.fromMap(m);
  @override
  Map<String, dynamic> toMap(MenuItem i) => i.toMap();
  @override
  String idOf(MenuItem i) => i.id;
}

class AvailabilityRepository extends LocalFirstRepository<MenuAvailability> {
  AvailabilityRepository(super.ref);
  @override
  String get collection => 'menu_availability';
  @override
  MenuAvailability fromMap(Map<String, dynamic> m) =>
      MenuAvailability.fromMap(m);
  @override
  Map<String, dynamic> toMap(MenuAvailability a) => a.toMap();
  @override
  String idOf(MenuAvailability a) => a.id;
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref),
);
final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => AvailabilityRepository(ref),
);

/// Data master menu: dipakai semua outlet, hanya owner yang mengubah.
final menuMasterProvider = StreamProvider<List<MenuItem>>(
  (ref) => ref.watch(menuRepositoryProvider).watchAll(),
);

final availabilityStreamProvider = StreamProvider<List<MenuAvailability>>(
  (ref) => ref.watch(availabilityRepositoryProvider).watchAll(),
);

/// menuItemId -> tersedia di outlet ini (default: tersedia)
final availabilityProvider = Provider<Map<String, bool>>(
  (ref) => {
    for (final a
        in ref.watch(availabilityStreamProvider).value ?? <MenuAvailability>[])
      a.id: a.available,
  },
);

/// Menu yang dipakai POS dan resep: master + ketersediaan outlet ini.
final menuItemsProvider = Provider<AsyncValue<List<MenuItem>>>((ref) {
  final avail = ref.watch(availabilityProvider);
  return ref
      .watch(menuMasterProvider)
      .whenData(
        (l) => [
          for (final m in l)
            m.copyWith(available: m.available && (avail[m.id] ?? true)),
        ],
      );
});
