import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class IngredientsTab extends ConsumerWidget {
  const IngredientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ings = ref.watch(ingredientsProvider).value ?? <Ingredient>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Bahan'),
      ),
      body: ings.isEmpty
          ? const Center(child: Text('Belum ada bahan'))
          : ListView(
              children: [
                for (final i in ings)
                  ListTile(
                    title: Text(i.name),
                    subtitle: Text(
                      'Satuan ${i.unit}'
                      '${i.buyUnit.isEmpty ? '' : ' • beli per ${i.buyUnit} (= ${qtyText(i.buyFactor)} ${i.unit})'}',
                    ),
                    onTap: () => _edit(context, ref, i),
                    onLongPress: () => _delete(context, ref, i),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Ingredient? ing,
  ) async {
    final r = await formDialog(
      context,
      ing == null ? 'Bahan baru' : 'Edit bahan',
      [
        'Nama',
        'Satuan dasar (g / ml / pcs)',
        'Stok minimum',
        'Satuan beli (mis. kg; kosongkan jika sama)',
        '1 satuan beli = ... satuan dasar',
      ],
      initial: ing == null
          ? ['', 'g', '0', '', '1']
          : [
              ing.name,
              ing.unit,
              qtyPlain(ing.minStock),
              ing.buyUnit,
              qtyPlain(ing.buyFactor),
            ],
      numeric: {2, 4},
    );
    if (r == null) return;
    if (r[0].isEmpty || r[1].isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama dan satuan wajib diisi')),
        );
      }
      return;
    }
    await ref
        .read(ingredientRepositoryProvider)
        .save(
          Ingredient(
            id: ing?.id ?? const Uuid().v4(),
            name: r[0],
            unit: r[1],
            minStock: parseNum(r[2]) ?? 0,
            buyUnit: r[3],
            buyFactor: (parseNum(r[4]) ?? 1) > 0 ? parseNum(r[4])! : 1,
          ),
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Ingredient i,
  ) async {
    final used =
        (ref.read(stockMovesProvider).value ?? <StockMove>[]).any(
          (m) => m.ingredientId == i.id,
        ) ||
        (ref.read(recipesProvider).value ?? <String, Recipe>{}).values.any(
          (r) => r.lines.any((l) => l.ingredientId == i.id),
        );
    if (used) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bahan sudah dipakai (stok/resep), tidak bisa dihapus'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${i.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(ingredientRepositoryProvider).remove(i.id);
  }
}
