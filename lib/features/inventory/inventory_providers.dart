import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/core/db/app_database.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/local_first_repository.dart';
import '../../core/sync/sync_controller.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import 'inventory_models.dart';

class IngredientRepository extends LocalFirstRepository<Ingredient> {
  IngredientRepository(super.ref);
  @override
  String get collection => 'ingredients';
  @override
  Ingredient fromMap(Map<String, dynamic> m) => Ingredient.fromMap(m);
  @override
  Map<String, dynamic> toMap(Ingredient i) => i.toMap();
  @override
  String idOf(Ingredient i) => i.id;
}

class RecipeRepository extends LocalFirstRepository<Recipe> {
  RecipeRepository(super.ref);
  @override
  String get collection => 'recipes';
  @override
  Recipe fromMap(Map<String, dynamic> m) => Recipe.fromMap(m);
  @override
  Map<String, dynamic> toMap(Recipe r) => r.toMap();
  @override
  String idOf(Recipe r) => r.id;
}

class StockRepository extends LocalFirstRepository<StockMove> {
  StockRepository(super.ref);
  @override
  String get collection => 'stock_moves';
  @override
  StockMove fromMap(Map<String, dynamic> m) => StockMove.fromMap(m);
  @override
  Map<String, dynamic> toMap(StockMove s) => s.toMap();
  @override
  String idOf(StockMove s) => s.id;

  Future<void> record({
    required String ingredientId,
    required StockMoveType type,
    required double qty,
    double? unitCost,
    String note = '',
    String? id,
  }) {
    final u = ref.read(appUserProvider).value;
    return save(
      StockMove(
        id: id ?? const Uuid().v4(),
        ingredientId: ingredientId,
        type: type,
        qty: qty,
        at: DateTime.now().millisecondsSinceEpoch,
        unitCost: unitCost,
        note: note,
        userName: u?.name ?? '',
      ),
    );
  }

  /// Potong stok sesuai resep saat order dibayar. Idempotent (id deterministik).
  Future<void> deductForOrder(Order o) async {
    final recipes = {
      for (final r in await ref.read(recipeRepositoryProvider).watchAll().first)
        r.id: r,
    };
    final used = <String, double>{};
    for (final it in o.items) {
      final r = recipes[it.menuItemId];
      if (r == null) continue;
      for (final l in r.lines) {
        used[l.ingredientId] = (used[l.ingredientId] ?? 0) + l.qty * it.qty;
      }
    }
    final db = ref.read(databaseProvider);
    final user = ref.read(appUserProvider).value;
    for (final e in used.entries) {
      final id = 'sale_${o.id}_${e.key}';
      if (await db.find('stock_moves', id) != null) continue;
      await save(
        StockMove(
          id: id,
          ingredientId: e.key,
          type: StockMoveType.sale,
          qty: -e.value,
          at: o.paidAt ?? DateTime.now().millisecondsSinceEpoch,
          orderId: o.id,
          note: o.number,
          userName: user?.name ?? '',
        ),
      );
    }
  }
}

final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => IngredientRepository(ref),
);
final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref),
);
final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref),
);

final ingredientsProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref
      .watch(ingredientRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      ),
);

/// menuItemId -> resep
final recipesProvider = StreamProvider<Map<String, Recipe>>(
  (ref) => ref
      .watch(recipeRepositoryProvider)
      .watchAll()
      .map((l) => {for (final r in l) r.id: r}),
);

typedef StockAgg = ({double total, double pQty, double pCost});

/// ingredientId -> total stok & agregat pembelian (dihitung SQL).
final stockAggProvider = StreamProvider<Map<String, StockAgg>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchStockAgg()
      .map(
        (rows) => {
          for (final r in rows)
            if (r.data['ing'] != null)
              r.data['ing'] as String: (
                total: (r.data['total'] as num?)?.toDouble() ?? 0,
                pQty: (r.data['pqty'] as num?)?.toDouble() ?? 0,
                pCost: (r.data['pcost'] as num?)?.toDouble() ?? 0,
              ),
        },
      ),
);

/// ingredientId -> stok saat ini (jumlah semua mutasi)
final stockLevelsProvider = Provider<Map<String, double>>((ref) {
  final agg = ref.watch(stockAggProvider).value ?? <String, StockAgg>{};
  return {for (final e in agg.entries) e.key: e.value.total};
});

/// ingredientId -> harga beli rata-rata tertimbang per satuan dasar
final avgCostProvider = Provider<Map<String, double>>((ref) {
  final agg = ref.watch(stockAggProvider).value ?? <String, StockAgg>{};
  return {
    for (final e in agg.entries)
      if (e.value.pQty > 0) e.key: e.value.pCost / e.value.pQty,
  };
});

final stockVersionProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchStockVersion(),
);

Future<List<StockMove>> loadStockMoves(
  AppDatabase db, {
  String? ingredientId,
  int? start,
  int? end,
  int? limit,
}) async {
  final rows = await db.stockMoveRows(
    ingredientId: ingredientId,
    start: start,
    end: end,
    limit: limit,
  );
  return [
    for (final r in rows)
      StockMove.fromMap(jsonDecode(r.json) as Map<String, dynamic>),
  ];
}

/// Mutasi stok dalam rentang waktu (untuk laba rugi), dimuat via SQL.
final movesInRangeProvider = FutureProvider.autoDispose
    .family<List<StockMove>, ({int start, int end})>((ref, r) async {
      ref.watch(stockVersionProvider); // muat ulang saat ada mutasi baru
      return loadStockMoves(
        ref.read(databaseProvider),
        start: r.start,
        end: r.end,
      );
    });

/// menuItemId -> HPP per porsi
final hppProvider = Provider<Map<String, double>>((ref) {
  final avg = ref.watch(avgCostProvider);
  final recipes = ref.watch(recipesProvider).value ?? <String, Recipe>{};
  return {
    for (final r in recipes.values)
      r.id: r.lines.fold<double>(
        0,
        (s, l) => s + l.qty * (avg[l.ingredientId] ?? 0),
      ),
  };
});

void logStockError(Object e, StackTrace st) =>
    debugPrint('Pemotongan stok gagal: $e\n$st');
