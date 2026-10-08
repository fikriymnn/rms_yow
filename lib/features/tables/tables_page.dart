import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/features/pos/pos_page.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import 'dining_table.dart';
import 'table_providers.dart';

class TablesPage extends ConsumerWidget {
  const TablesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider).value ?? [];
    final open = ref.watch(openOrdersProvider);
    final canManage = ref.watch(appUserProvider).value?.canManageMenu ?? false;
    final repo = ref.read(tableRepositoryProvider);
    final takeaways = open.where((o) => o.type == OrderType.takeaway).toList();
    final cs = Theme.of(context).colorScheme;

    Order? orderOf(String tableId) =>
        open.where((o) => o.tableId == tableId).firstOrNull;

    void openPos({DiningTable? table, Order? order}) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosPage(table: table, order: order),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meja'),
        actions: [
          TextButton.icon(
            onPressed: () => openPos(),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Takeaway'),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, repo, null, false),
              icon: const Icon(Icons.add),
              label: const Text('Meja'),
            )
          : null,
      body: Column(
        children: [
          if (takeaways.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final o in takeaways)
                      ActionChip(
                        avatar: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                        ),
                        label: Text('${o.number} • ${rupiah.format(o.total)}'),
                        onPressed: () => openPos(order: o),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: tables.isEmpty
                ? const Center(child: Text('Belum ada meja'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisExtent: 110,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: tables.length,
                    itemBuilder: (_, i) {
                      final t = tables[i];
                      final o = orderOf(t.id);
                      return Card(
                        color: o != null ? cs.primaryContainer : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => openPos(table: t, order: o),
                          onLongPress: canManage
                              ? () => _edit(context, repo, t, o != null)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${t.capacity} kursi',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  o == null ? 'Kosong' : rupiah.format(o.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    TableRepository repo,
    DiningTable? existing,
    bool occupied,
  ) async {
    final name = TextEditingController(text: existing?.name);
    final cap = TextEditingController(
      text: (existing?.capacity ?? 4).toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Meja baru' : 'Edit meja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama (mis. T1)'),
            ),
            TextField(
              controller: cap,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kapasitas'),
            ),
          ],
        ),
        actions: [
          if (existing != null && !occupied)
            TextButton(
              onPressed: () {
                repo.remove(existing.id);
                Navigator.pop(ctx);
              },
              child: const Text('Hapus'),
            ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              repo.save(
                (existing ?? DiningTable(id: const Uuid().v4(), name: ''))
                    .copyWith(
                      name: name.text.trim(),
                      capacity: int.tryParse(cap.text) ?? 4,
                    ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
