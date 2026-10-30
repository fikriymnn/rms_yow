import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import 'dining_table.dart';

class TableRepository extends LocalFirstRepository<DiningTable> {
  TableRepository(super.ref);
  @override
  String get collection => 'tables';
  @override
  DiningTable fromMap(Map<String, dynamic> m) => DiningTable.fromMap(m);
  @override
  Map<String, dynamic> toMap(DiningTable t) => t.toMap();
  @override
  String idOf(DiningTable t) => t.id;
}

final tableRepositoryProvider = Provider<TableRepository>(
  (ref) => TableRepository(ref),
);

final tablesProvider = StreamProvider<List<DiningTable>>(
  (ref) => ref
      .watch(tableRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      ),
);
