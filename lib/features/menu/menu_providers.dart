import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
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

final menuRepositoryProvider =
    Provider<MenuRepository>((ref) => MenuRepository(ref));

final menuItemsProvider = StreamProvider<List<MenuItem>>(
    (ref) => ref.watch(menuRepositoryProvider).watchAll());
