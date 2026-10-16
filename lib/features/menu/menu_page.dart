import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../auth/auth_providers.dart';
import 'menu_availability.dart';
import 'menu_item.dart';
import 'menu_providers.dart';

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(menuMasterProvider);
    final avail = ref.watch(availabilityProvider);
    final role = ref.watch(appUserProvider).value?.role;
    final isOwner = role == AppRole.owner;
    final canToggle =
        isOwner || role == AppRole.manager || role == AppRole.cashier;
    final repo = ref.read(menuRepositoryProvider);
    final availRepo = ref.read(availabilityRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, repo, null),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            )
          : null,
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => Column(
          children: [
            if (!isOwner)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(10),
                child: const Text(
                  'Menu dikelola owner. Anda bisa menandai item habis/tersedia di outlet ini.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Belum ada menu'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final on = avail[m.id] ?? true;
                        return ListTile(
                          title: Text(m.name),
                          subtitle: Text(
                            '${m.category} • ${rupiah.format(m.price)}${on ? '' : ' • habis di outlet ini'}',
                          ),
                          onTap: isOwner ? () => _edit(context, repo, m) : null,
                          trailing: Switch(
                            value: on,
                            onChanged: canToggle
                                ? (v) => availRepo.save(
                                    MenuAvailability(id: m.id, available: v),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    MenuRepository repo,
    MenuItem? existing,
  ) async {
    final name = TextEditingController(text: existing?.name);
    final cat = TextEditingController(text: existing?.category);
    final price = TextEditingController(text: existing?.price.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Menu baru' : 'Edit menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: cat,
              decoration: const InputDecoration(labelText: 'Kategori'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga (Rp)'),
            ),
          ],
        ),
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
              if (name.text.trim().isEmpty) return;
              final item =
                  (existing ??
                          MenuItem(
                            id: const Uuid().v4(),
                            name: '',
                            category: '',
                            price: 0,
                          ))
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
