import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sync/local_first_repository.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

List<RecipeLine>? _lines(Object? v) => v is List
    ? [
        for (final e in v)
          RecipeLine.fromMap(Map<String, dynamic>.from(e as Map)),
      ]
    : null;

class RecipeRevision {
  RecipeRevision.fromMap(Map<String, dynamic> m)
    : id = m['id'] as String,
      recipeId = m['recipeId'] as String? ?? '',
      at = (m['at'] as num?)?.toInt() ?? 0,
      byName = m['byName'] as String? ?? '',
      via = m['via'] as String? ?? '',
      before = _lines(m['before']),
      after = _lines(m['after']);

  final String id;
  final String recipeId;
  final int at;
  final String byName;
  final String via;
  final List<RecipeLine>? before;
  final List<RecipeLine>? after;
}

/// Hanya dibaca: riwayat ditulis oleh server.
class RecipeHistoryRepository extends LocalFirstRepository<RecipeRevision> {
  RecipeHistoryRepository(super.ref);
  @override
  String get collection => 'recipe_history';
  @override
  RecipeRevision fromMap(Map<String, dynamic> m) => RecipeRevision.fromMap(m);
  @override
  Map<String, dynamic> toMap(RecipeRevision r) => {'id': r.id};
  @override
  String idOf(RecipeRevision r) => r.id;
}

final recipeHistoryProvider = StreamProvider<List<RecipeRevision>>(
  (ref) => ref
      .watch(
        Provider<RecipeHistoryRepository>((r) => RecipeHistoryRepository(r)),
      )
      .watchAll()
      .map((l) => l..sort((a, b) => b.at.compareTo(a.at))),
);

List<String> describeChange(
  List<RecipeLine>? before,
  List<RecipeLine>? after,
  Map<String, Ingredient> ings,
) {
  final b = {for (final l in before ?? <RecipeLine>[]) l.ingredientId: l.qty};
  final a = {for (final l in after ?? <RecipeLine>[]) l.ingredientId: l.qty};
  String name(String id) => ings[id]?.name ?? '(bahan dihapus)';
  String unit(String id) => ings[id]?.unit ?? '';
  return [
    for (final id in {...b.keys, ...a.keys})
      if (!b.containsKey(id))
        '+ ${name(id)} ${qtyText(a[id]!)} ${unit(id)}'
      else if (!a.containsKey(id))
        '− ${name(id)} dihapus'
      else if (b[id] != a[id])
        '${name(id)}: ${qtyText(b[id]!)} → ${qtyText(a[id]!)} ${unit(id)}',
  ];
}

Future<void> showRecipeHistory(
  BuildContext context,
  WidgetRef ref,
  String menuId,
  String menuName,
) {
  final fmt = DateFormat('d MMM yyyy HH:mm');
  final ings = {
    for (final i in ref.read(ingredientsProvider).value ?? <Ingredient>[])
      i.id: i,
  };
  final revs = (ref.read(recipeHistoryProvider).value ?? <RecipeRevision>[])
      .where((r) => r.recipeId == menuId)
      .toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, sc) => ListView(
        controller: sc,
        children: [
          ListTile(title: Text('Riwayat resep $menuName')),
          if (revs.isEmpty) const ListTile(title: Text('Belum ada riwayat')),
          for (final r in revs)
            ListTile(
              isThreeLine: true,
              title: Text(
                '${fmt.format(DateTime.fromMillisecondsSinceEpoch(r.at))} • ${r.byName}',
              ),
              subtitle: Text(
                [
                  if (r.via.isNotEmpty) r.via,
                  if (r.before == null) 'Resep dibuat',
                  ...describeChange(r.before, r.after, ings),
                ].join('\n'),
              ),
            ),
        ],
      ),
    ),
  );
}
