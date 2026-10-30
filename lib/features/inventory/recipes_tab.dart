import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/features/auth/auth_providers.dart';
import 'package:rms_yow/features/inventory/recipe_history.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
import '../menu/menu_item.dart';
import '../menu/menu_providers.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

int _marginPct(int price, double hpp) =>
    price > 0 ? ((price - hpp) / price * 100).round() : 0;

Tone _marginTone(int pct) =>
    pct >= 60 ? Tone.success : (pct >= 30 ? Tone.warning : Tone.danger);

class RecipesTab extends ConsumerStatefulWidget {
  const RecipesTab({super.key});
  @override
  ConsumerState<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<RecipesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuItemsProvider).value ?? <MenuItem>[];
    final recipes = ref.watch(recipesProvider).value ?? <String, Recipe>{};
    final hpp = ref.watch(hppProvider);
    if (menu.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant_menu,
        title: 'Belum ada menu',
      );
    }
    bool has(MenuItem m) => (recipes[m.id]?.lines.isNotEmpty ?? false);
    final noRecipe = menu.where((m) => !has(m)).length;
    final shown = menu
        .where((m) => _query.isEmpty || m.name.toLowerCase().contains(_query))
        .toList();

    Widget card(MenuItem m) {
      final h = hpp[m.id] ?? 0;
      final ok = has(m);
      final pct = _marginPct(m.price, h);
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecipeEditorPage(menu: m)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ok
                            ? 'HPP ${rupiah.format(h.round())} • Jual ${rupiah.format(m.price)}'
                            : 'Jual ${rupiah.format(m.price)}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ok
                    ? StatusPill('Margin $pct%', tone: _marginTone(pct))
                    : const StatusPill('Belum ada resep', tone: Tone.warning),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdaptiveGrid(
          minTileWidth: 150,
          maxColumns: 3,
          children: [
            StatTile(
              icon: Icons.restaurant_menu,
              label: 'Menu',
              value: '${menu.length}',
            ),
            StatTile(
              icon: Icons.menu_book_outlined,
              label: 'Belum ada resep',
              value: '$noRecipe',
              tone: noRecipe > 0 ? Tone.warning : Tone.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Cari menu',
            isDense: true,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const EmptyState(
            icon: Icons.search_off,
            title: 'Menu tidak ditemukan',
          )
        else
          AdaptiveGrid(
            minTileWidth: 360,
            maxColumns: 3,
            children: [for (final m in shown) card(m)],
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
    final isOwner =
        ref.watch(appUserProvider).value?.can('recipes.update') ?? false;
    final pct = _marginPct(menu.price, hpp);
    final marginTone = toneColors(_marginTone(pct));

    final summary = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: marginTone.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'Margin',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  recipe.lines.isEmpty ? '-' : '$pct%',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: marginTone.fg,
                  ),
                ),
                Text(
                  recipe.lines.isEmpty
                      ? 'Belum ada resep'
                      : rupiah.format((menu.price - hpp).round()),
                  style: GoogleFonts.inter(fontSize: 13, color: marginTone.fg),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          KvRow('Harga jual', rupiah.format(menu.price)),
          KvRow('HPP per porsi', rupiah.format(hpp.round())),
        ],
      ),
    );

    final lines = SectionCard(
      title: 'Bahan per porsi (${recipe.lines.length})',
      child: recipe.lines.isEmpty
          ? const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Belum ada bahan di resep',
            )
          : Column(
              children: [
                for (final l in recipe.lines)
                  Builder(
                    builder: (_) {
                      final ing = ings[l.ingredientId];
                      final price = avg[l.ingredientId];
                      final cost = l.qty * (price ?? 0);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isOwner
                              ? () => _editQty(context, ref, recipe, l, ing)
                              : null,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              8,
                              isOwner ? 4 : 12,
                              8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ing?.name ?? '(bahan dihapus)',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${qtyText(l.qty)} ${ing?.unit ?? ''}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      if (price == null)
                                        Text(
                                          'belum ada harga beli',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  rupiah.format(cost.round()),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isOwner)
                                  IconButton(
                                    tooltip: 'Hapus bahan',
                                    icon: const Icon(Icons.close, size: 20),
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
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Resep ${menu.name}'),
        actions: [
          IconButton(
            tooltip: 'Riwayat resep',
            icon: const Icon(Icons.history),
            onPressed: () =>
                showRecipeHistory(context, ref, menu.id, menu.name),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref, recipe, ings.values.toList()),
              icon: const Icon(Icons.add),
              label: const Text('Bahan'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: summary,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 96),
                    children: [lines],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [summary, const SizedBox(height: 12), lines],
          );
        },
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
