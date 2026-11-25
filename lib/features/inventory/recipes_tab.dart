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
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

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
    // menu bertanda "tanpa resep" bukan kekurangan: tidak dihitung "belum ada resep"
    final noRecipe = menu.where((m) => !m.noRecipe && !has(m)).length;
    final withoutRecipe = menu.where((m) => m.noRecipe).length;
    final shown = menu
        .where((m) => _query.isEmpty || m.name.toLowerCase().contains(_query))
        .toList();

    Widget card(MenuItem m) {
      final h = hpp[m.id] ?? 0;
      final ok = has(m) && !m.noRecipe;
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ok
                            ? 'HPP ${rupiah.format(h.round())} • Jual ${rupiah.format(m.price)}'
                            : 'Jual ${rupiah.format(m.price)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                m.noRecipe
                    ? const StatusPill('Tanpa resep', tone: Tone.neutral)
                    : ok
                    ? StatusPill('Margin $pct%', tone: _marginTone(pct))
                    : const StatusPill('Belum ada resep', tone: Tone.warning),
                Icon(
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
            if (withoutRecipe > 0)
              StatTile(
                icon: Icons.no_food_outlined,
                label: 'Tanpa resep',
                value: '$withoutRecipe',
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  recipe.lines.isEmpty ? '-' : '$pct%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: marginTone.fg,
                  ),
                ),
                Text(
                  recipe.lines.isEmpty
                      ? 'Belum ada resep'
                      : rupiah.format((menu.price - hpp).round()),
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: marginTone.fg),
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
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${qtyText(l.qty)} ${ing?.unit ?? ''}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      if (price == null)
                                        Text(
                                          'belum ada harga beli',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  rupiah.format(cost.round()),
                                  style: GoogleFonts.plusJakartaSans(
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

    final cur =
        ref
            .watch(menuItemsProvider)
            .value
            ?.where((m) => m.id == menu.id)
            .firstOrNull ??
        menu;
    final canToggle = ref.watch(appUserProvider).value?.can('menu.update') ?? false;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cur.noRecipe) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.no_food_outlined, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menu ini ditandai tanpa resep: penjualannya tidak memotong stok bahan '
                    'dan HPP tidak dihitung.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        summary,
      ],
    );

    return Scaffold(
      appBar: RmsAppBar(
        title: Text('Resep ${menu.name}'),
        actions: [
          if (canToggle)
            PopupMenuButton<bool>(
              tooltip: 'Pengaturan resep',
              onSelected: (noRecipe) => ref
                  .read(menuRepositoryProvider)
                  .save(cur.copyWith(noRecipe: noRecipe)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: !cur.noRecipe,
                  child: Text(cur.noRecipe ? 'Pakai resep' : 'Tandai tanpa resep'),
                ),
              ],
            ),
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
                    child: head,
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
            children: [head, const SizedBox(height: 12), lines],
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
    final ing = await showAppDialog<Ingredient>(
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
