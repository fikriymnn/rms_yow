import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/meta_db.dart';
import '../../core/sync/local_first_repository.dart';
import 'opname_models.dart';

class OpnameRepository extends LocalFirstRepository<StockOpname> {
  OpnameRepository(super.ref);
  @override
  String get collection => 'stock_opnames';
  @override
  StockOpname fromMap(Map<String, dynamic> m) => StockOpname.fromMap(m);
  @override
  Map<String, dynamic> toMap(StockOpname o) => o.toMap();
  @override
  String idOf(StockOpname o) => o.id;
}

final opnameRepositoryProvider = Provider<OpnameRepository>(
  (ref) => OpnameRepository(ref),
);

/// Semua tiket opname outlet aktif, terbaru dulu.
final opnamesProvider = StreamProvider<List<StockOpname>>(
  (ref) => ref
      .watch(opnameRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
);

final opnameProvider = Provider.family<StockOpname?, String>(
  (ref, id) => ref.watch(opnamesProvider).value?.where((o) => o.id == id).firstOrNull,
);

/// Draf hitungan di perangkat (tombol "Simpan hitungan"). Bertahan walau aplikasi ditutup
/// atau pengiriman gagal; dihapus setelah server selesai memproses tiket.
class OpnameDraftStore {
  OpnameDraftStore(this.ref);
  final Ref ref;

  String _key(String id) => 'opname_draft_$id';

  Future<({Map<String, OpnameCount> counts, int? savedAt})> load(String id) async {
    final m = await ref.read(metaDbProvider).getMeta(_key(id));
    if (m == null) return (counts: <String, OpnameCount>{}, savedAt: null);
    final raw = Map<String, dynamic>.from(m['counts'] as Map? ?? const {});
    return (
      counts: {
        for (final e in raw.entries)
          e.key: OpnameCount.fromMap(Map<String, dynamic>.from(e.value as Map)),
      },
      savedAt: (m['savedAt'] as num?)?.toInt(),
    );
  }

  Future<int> save(String id, Map<String, OpnameCount> counts) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref.read(metaDbProvider).putMeta(_key(id), {
      'savedAt': now,
      'counts': {
        for (final e in counts.entries)
          if (!e.value.isEmpty) e.key: e.value.toMap(),
      },
    });
    return now;
  }

  Future<void> clear(String id) => ref.read(metaDbProvider).removeMeta(_key(id));
}

final opnameDraftStoreProvider = Provider<OpnameDraftStore>(
  (ref) => OpnameDraftStore(ref),
);

/// Jumlah bahan yang sudah terisi di draf perangkat (untuk progres di daftar tiket).
final opnameDraftFilledProvider = FutureProvider.autoDispose.family<int, String>((ref, id) async {
  final d = await ref.read(opnameDraftStoreProvider).load(id);
  return d.counts.values.where((c) => c.actual.trim().isNotEmpty).length;
});
