import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/sync/sync_controller.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class StockTab extends ConsumerWidget {
  const StockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ings = ref.watch(ingredientsProvider).value ?? <Ingredient>[];
    final levels = ref.watch(stockLevelsProvider);
    bool low(Ingredient i) =>
        i.minStock > 0 && (levels[i.id] ?? 0) <= i.minStock;

    if (ings.isEmpty) {
      return const Center(
        child: Text('Belum ada bahan. Tambahkan di tab Bahan.'),
      );
    }
    final sorted = [...ings]
      ..sort((a, b) {
        final la = low(a) ? 0 : 1, lb = low(b) ? 0 : 1;
        return la != lb
            ? la.compareTo(lb)
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final lowCount = ings.where(low).length;
    final err = Theme.of(context).colorScheme.error;

    return ListView(
      children: [
        if (lowCount > 0)
          Container(
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(12),
            child: Text('$lowCount bahan di bawah stok minimum'),
          ),
        for (final i in sorted)
          ListTile(
            leading: low(i) ? Icon(Icons.warning_amber, color: err) : null,
            title: Text(i.name),
            subtitle: Text(
              i.minStock > 0
                  ? 'Minimum ${qtyText(i.minStock)} ${i.unit}'
                  : 'Tanpa minimum',
            ),
            trailing: Text(
              '${qtyText(levels[i.id] ?? 0)} ${i.unit}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: low(i) ? err : null,
              ),
            ),
            onTap: () => _menu(context, ref, i),
          ),
      ],
    );
  }
}

void _toast(BuildContext c, String m) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

Future<void> _menu(BuildContext context, WidgetRef ref, Ingredient i) async {
  final a = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(i.name), subtitle: const Text('Pilih aksi')),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Stok masuk (pembelian)'),
            onTap: () => Navigator.pop(ctx, 'in'),
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
      initialChildSize: 0.6,
      builder: (_, sc) => ListView(
        controller: sc,
        children: [
          ListTile(title: Text('Riwayat ${i.name}')),
          if (moves.isEmpty) const ListTile(title: Text('Belum ada mutasi')),
          for (final m in moves)
            ListTile(
              dense: true,
              title: Text(
                '${m.type.label} • ${m.qty > 0 ? '+' : ''}${qtyText(m.qty)} ${i.unit}',
              ),
              subtitle: Text(
                '${fmt.format(DateTime.fromMillisecondsSinceEpoch(m.at))}'
                '${m.userName.isEmpty ? '' : ' • ${m.userName}'}'
                '${m.note.isEmpty ? '' : '\n${m.note}'}',
              ),
            ),
        ],
      ),
    ),
  );
}
