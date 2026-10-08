import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'menu_item.dart';
import 'menu_providers.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(menuItemsProvider);
    final repo = ref.read(menuRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, repo, null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Belum ada menu'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = list[i];
                  return ListTile(
                    title: Text(m.name),
                    subtitle: Text('${m.category} • ${_rp.format(m.price)}'),
                    onTap: () => _edit(context, repo, m),
                    trailing: Switch(
                      value: m.available,
                      onChanged: (v) => repo.save(m.copyWith(available: v)),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, MenuRepository repo, MenuItem? existing) async {
    final name = TextEditingController(text: existing?.name);
    final cat = TextEditingController(text: existing?.category);
    final price = TextEditingController(text: existing?.price.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Menu baru' : 'Edit menu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama')),
          TextField(controller: cat, decoration: const InputDecoration(labelText: 'Kategori')),
          TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga (Rp)')),
        ]),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                repo.remove(existing.id);
                Navigator.pop(ctx);
              },
              child: const Text('Hapus'),
            ),
          FilledButton(
            onPressed: () {
              final item = (existing ??
                      MenuItem(
                          id: const Uuid().v4(),
                          name: '',
                          category: '',
                          price: 0))
                  .copyWith(
                name: name.text.trim(),
                category: cat.text.trim(),
                price: int.tryParse(price.text) ?? 0,
              );
              repo.save(item);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
