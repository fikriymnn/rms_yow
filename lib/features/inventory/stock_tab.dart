import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/sync/sync_controller.dart';
import 'package:rms_yow/features/auth/auth_providers.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

enum _StockFilter { all, low }

class StockTab extends ConsumerStatefulWidget {
  const StockTab({super.key});
  @override
  ConsumerState<StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<StockTab> {
  _StockFilter _filter = _StockFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ings = ref.watch(ingredientsProvider).value ?? <Ingredient>[];
    final levels = ref.watch(stockLevelsProvider);
    final canOps =
        ref.watch(appUserProvider).value?.can('stock.create') ?? false;
    bool low(Ingredient i) =>
        i.minStock > 0 && (levels[i.id] ?? 0) <= i.minStock;

    if (ings.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada bahan',
        message: 'Tambahkan di tab Bahan.',
      );
    }

    final lowCount = ings.where(low).length;
    final emptyCount = ings.where((i) => (levels[i.id] ?? 0) <= 0).length;
    final shown =
        ings
            .where(
              (i) =>
                  (_filter == _StockFilter.all || low(i)) &&
                  (_query.isEmpty || i.name.toLowerCase().contains(_query)),
            )
            .toList()
          ..sort((a, b) {
            final la = low(a) ? 0 : 1, lb = low(b) ? 0 : 1;
            return la != lb
                ? la.compareTo(lb)
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdaptiveGrid(
          minTileWidth: 150,
          maxColumns: 3,
          children: [
            StatTile(
              icon: Icons.inventory_2_outlined,
              label: 'Total bahan',
              value: '${ings.length}',
            ),
            StatTile(
              icon: Icons.warning_amber_rounded,
              label: 'Stok menipis',
              value: '$lowCount',
              tone: lowCount > 0 ? Tone.warning : Tone.success,
            ),
            StatTile(
              icon: Icons.remove_shopping_cart_outlined,
              label: 'Habis',
              value: '$emptyCount',
              tone: emptyCount > 0 ? Tone.danger : Tone.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Cari bahan',
            isDense: true,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Semua'),
              selected: _filter == _StockFilter.all,
              onSelected: (_) => setState(() => _filter = _StockFilter.all),
            ),
            ChoiceChip(
              label: Text('Perlu dibeli $lowCount'),
              selected: _filter == _StockFilter.low,
              onSelected: (_) => setState(() => _filter = _StockFilter.low),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const EmptyState(
            icon: Icons.search_off,
            title: 'Bahan tidak ditemukan',
          )
        else
          AdaptiveGrid(
            minTileWidth: 340,
            maxColumns: 3,
            children: [
              for (final i in shown)
                _IngredientStockCard(
                  ingredient: i,
                  level: levels[i.id] ?? 0,
                  isLow: low(i),
                  onTap: canOps
                      ? () => _menu(context, ref, i)
                      : () => _history(context, ref, i),
                ),
            ],
          ),
      ],
    );
  }
}

class _IngredientStockCard extends StatelessWidget {
  const _IngredientStockCard({
    required this.ingredient,
    required this.level,
    required this.isLow,
    required this.onTap,
  });
  final Ingredient ingredient;
  final double level;
  final bool isLow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = ingredient;
    final empty = level <= 0;
    final ratio = i.minStock > 0
        ? (level / (i.minStock * 2)).clamp(0.0, 1.0).toDouble()
        : null;
    final color = isLow ? AppColors.danger : AppColors.ink;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLow ? AppColors.danger : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      i.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isLow)
                    StatusPill(
                      empty ? 'Habis' : 'Menipis',
                      tone: empty ? Tone.danger : Tone.warning,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    qtyText(level),
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    i.unit,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (ratio != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: isLow ? AppColors.danger : AppColors.success,
                    backgroundColor: isLow
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFD1FAE5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Minimum ${qtyText(i.minStock)} ${i.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ] else
                Text(
                  'Tanpa minimum',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext c, String m) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

Future<void> _menu(BuildContext context, WidgetRef ref, Ingredient i) async {
  final isOwner =
      ref.read(appUserProvider).value?.can('stock.purchase_direct') ?? false;
  final level = ref.read(stockLevelsProvider)[i.id] ?? 0;
  final a = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              i.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text('Stok saat ini ${qtyText(level)} ${i.unit}'),
          ),
          const Divider(height: 1),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Stok masuk manual (tanpa PO)'),
              onTap: () => Navigator.pop(ctx, 'in'),
            )
          else
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'Pembelian bahan dilakukan lewat PO (menu Pembelian)',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Waste / rusak'),
            onTap: () => Navigator.pop(ctx, 'waste'),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Stok opname'),
            onTap: () => Navigator.pop(ctx, 'opname'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Riwayat mutasi'),
            onTap: () => Navigator.pop(ctx, 'history'),
          ),
        ],
      ),
    ),
  );
  if (a == null || !context.mounted) return;
  switch (a) {
    case 'in':
      await _purchase(context, ref, i);
    case 'waste':
      await _waste(context, ref, i);
    case 'opname':
      await _opname(context, ref, i);
    case 'history':
      await _history(context, ref, i);
  }
}

Future<void> _purchase(
  BuildContext context,
  WidgetRef ref,
  Ingredient i,
) async {
  final unit = i.buyUnit.isEmpty ? i.unit : i.buyUnit;
  final factor = i.buyUnit.isEmpty ? 1.0 : i.buyFactor;
  final r = await formDialog(
    context,
    'Stok masuk: ${i.name}',
    ['Jumlah ($unit)', 'Total harga (Rp)'],
    numeric: {0, 1},
    hint: 'Isi angka tanpa pemisah ribuan. Desimal pakai koma atau titik.',
  );
  if (r == null) return;
  final q = parseNum(r[0]), total = parseNum(r[1]);
  if (q == null || q <= 0 || total == null || total < 0) {
    _toast(context, 'Jumlah dan total harga harus diisi');
    return;
  }
  final base = q * factor;
  await ref
      .read(stockRepositoryProvider)
      .record(
        ingredientId: i.id,
        type: StockMoveType.purchase,
        qty: base,
        unitCost: total / base,
        note: '${qtyText(q)} $unit',
      );
  _toast(context, 'Stok masuk ${qtyText(base)} ${i.unit}');
}

Future<void> _waste(BuildContext context, WidgetRef ref, Ingredient i) async {
  final r = await formDialog(
    context,
    'Waste: ${i.name}',
    ['Jumlah (${i.unit})', 'Alasan'],
    numeric: {0},
  );
  if (r == null) return;
  final q = parseNum(r[0]);
  if (q == null || q <= 0 || r[1].length < 3) {
    _toast(context, 'Jumlah dan alasan (min. 3 huruf) wajib diisi');
    return;
  }
  await ref
      .read(stockRepositoryProvider)
      .record(
        ingredientId: i.id,
        type: StockMoveType.waste,
        qty: -q,
        note: r[1],
      );
}

Future<void> _opname(BuildContext context, WidgetRef ref, Ingredient i) async {
  final current = ref.read(stockLevelsProvider)[i.id] ?? 0;
  final r = await formDialog(
    context,
    'Opname: ${i.name}',
    ['Stok fisik (${i.unit})'],
    numeric: {0},
    hint: 'Stok di sistem: ${qtyText(current)} ${i.unit}',
  );
  if (r == null) return;
  final counted = parseNum(r[0]);
  if (counted == null || counted < 0) {
    _toast(context, 'Isi stok fisik');
    return;
  }
  final diff = counted - current;
  if (diff.abs() < 0.0001) {
    _toast(context, 'Stok sudah sesuai');
    return;
  }
  await ref
      .read(stockRepositoryProvider)
      .record(
        ingredientId: i.id,
        type: StockMoveType.opname,
        qty: diff,
        note: 'Sistem ${qtyText(current)} → fisik ${qtyText(counted)}',
      );
  _toast(context, 'Selisih ${qtyText(diff)} ${i.unit} dicatat');
}

Tone _moveTone(StockMoveType t) => switch (t.name) {
  'purchase' => Tone.success,
  'sale' => Tone.info,
  'waste' => Tone.danger,
  'opname' => Tone.warning,
  _ => Tone.neutral,
};

Future<void> _history(BuildContext context, WidgetRef ref, Ingredient i) async {
  final fmt = DateFormat('d MMM HH:mm');
  final moves = await loadStockMoves(
    ref.read(databaseProvider),
    ingredientId: i.id,
    limit: 40,
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Riwayat ${i.name}',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (moves.isEmpty)
            const EmptyState(icon: Icons.history, title: 'Belum ada mutasi'),
          for (final m in moves)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(m.type.label, tone: _moveTone(m.type)),
                        const SizedBox(height: 6),
                        Text(
                          '${fmt.format(DateTime.fromMillisecondsSinceEpoch(m.at))}'
                          '${m.userName.isEmpty ? '' : ' • ${m.userName}'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (m.note.isNotEmpty)
                          Text(
                            m.note,
                            style: GoogleFonts.inter(fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${m.qty > 0 ? '+' : ''}${qtyText(m.qty)} ${i.unit}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: m.qty >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
