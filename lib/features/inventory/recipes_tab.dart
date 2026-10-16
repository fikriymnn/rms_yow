import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/features/auth/auth_providers.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../menu/menu_item.dart';
import '../menu/menu_providers.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

int _marginPct(int price, double hpp) =>
    price > 0 ? ((price - hpp) / price * 100).round() : 0;

class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuItemsProvider).value ?? <MenuItem>[];
    final recipes = ref.watch(recipesProvider).value ?? <String, Recipe>{};
    final hpp = ref.watch(hppProvider);
    if (menu.isEmpty) return const Center(child: Text('Belum ada menu'));

    return ListView(
      children: [
        for (final m in menu)
          Builder(
            builder: (_) {
              final r = recipes[m.id];
              final has = r != null && r.lines.isNotEmpty;
              final h = hpp[m.id] ?? 0;
              return ListTile(
                title: Text(m.name),
                subtitle: Text(
                  has
                      ? 'HPP ${rupiah.format(h.round())} • Margin ${_marginPct(m.price, h)}%'
                      : 'Belum ada resep',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecipeEditorPage(menu: m)),
                ),
              );
            },
          ),
      ],
    );
  }
}

class RecipeEditorPage extends ConsumerWidget {
  const RecipeEditorPage({super.key, required this.menu});
  final MenuItem menu;

  Future<void> _save(WidgetRef ref, Recipe r) =>
      ref.read(recipeRepositoryProvider).save(r);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe =
        ref.watch(recipesProvider).value?[menu.id] ?? Recipe(id: menu.id);
    final ings = {
      for (final i in ref.watch(ingredientsProvider).value ?? <Ingredient>[])
        i.id: i,
    };
    final avg = ref.watch(avgCostProvider);
    final hpp = ref.watch(hppProvider)[menu.id] ?? 0;
    final isOwner = ref.watch(appUserProvider).value?.role == AppRole.owner;

    return Scaffold(
      appBar: AppBar(title: Text('Resep ${menu.name}')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref, recipe, ings.values.toList()),
              icon: const Icon(Icons.add),
              label: const Text('Bahan'),
            )
          : null,
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _kv('Harga jual', rupiah.format(menu.price)),
                  _kv('HPP per porsi', rupiah.format(hpp.round())),
                  _kv(
                    'Margin',
                    '${rupiah.format((menu.price - hpp).round())} (${_marginPct(menu.price, hpp)}%)',
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: recipe.lines.isEmpty
                ? const Center(child: Text('Belum ada bahan di resep'))
                : ListView(
                    children: [
                      for (final l in recipe.lines)
                        Builder(
                          builder: (_) {
                            final ing = ings[l.ingredientId];
                            final cost = l.qty * (avg[l.ingredientId] ?? 0);
                            return ListTile(
                              title: Text(ing?.name ?? '(bahan dihapus)'),
                              subtitle: Text(
                                '${qtyText(l.qty)} ${ing?.unit ?? ''} • ${rupiah.format(cost.round())}'
                                '${avg[l.ingredientId] == null ? ' (belum ada harga beli)' : ''}',
                              ),
                              onTap: isOwner
                                  ? () => _editQty(context, ref, recipe, l, ing)
                                  : null,
                              trailing: !isOwner
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => _save(
                                        ref,
                                        Recipe(
                                          id: recipe.id,
                                          lines: [
                                            for (final x in recipe.lines)
                                              if (x.ingredientId !=
                                                  l.ingredientId)
                                                x,
                                          ],
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final st = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: st),
          Text(v, style: st),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    List<Ingredient> all,
  ) async {
    final avail =
        all
            .where((i) => !recipe.lines.any((l) => l.ingredientId == i.id))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (avail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada bahan lain. Tambahkan di tab Bahan.'),
        ),
      );
      return;
    }
    final ing = await showDialog<Ingredient>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih bahan'),
        children: [
          for (final i in avail)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text('${i.name} (${i.unit})'),
            ),
        ],
      ),
    );
    if (ing == null || !context.mounted) return;
    final r = await formDialog(
      context,
      ing.name,
      ['Takaran per porsi (${ing.unit})'],
      numeric: {0},
    );
    final q = r == null ? null : parseNum(r[0]);
    if (q == null || q <= 0) return;
    await _save(
      ref,
      Recipe(
        id: recipe.id,
        lines: [
          ...recipe.lines,
          RecipeLine(ingredientId: ing.id, qty: q),
        ],
      ),
    );
  }

  Future<void> _editQty(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    RecipeLine l,
    Ingredient? ing,
  ) async {
    final r = await formDialog(
      context,
      ing?.name ?? 'Takaran',
      ['Takaran per porsi (${ing?.unit ?? ''})'],
      initial: [qtyPlain(l.qty)],
      numeric: {0},
    );
    final q = r == null ? null : parseNum(r[0]);
    if (q == null || q <= 0) return;
    await _save(
      ref,
      Recipe(
        id: recipe.id,
        lines: [
          for (final x in recipe.lines)
            x.ingredientId == l.ingredientId
                ? RecipeLine(ingredientId: x.ingredientId, qty: q)
                : x,
        ],
      ),
    );
  }
}
