import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'menu_availability.dart';
import 'menu_item.dart';
import 'menu_providers.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});
  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  String _query = '';
  String _category = 'Semua';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(menuMasterProvider);
    final avail = ref.watch(availabilityProvider);
    final user = ref.watch(appUserProvider).value;
    final isOwner =
        user?.can('menu.update') ?? false; // boleh ubah menu langsung
    final canToggle = user?.can('menu.availability') ?? false;
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
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'Belum ada menu',
            );
          }
          final cats = [
            'Semua',
            ...{for (final m in list) m.category},
          ];
          final shown = list
              .where(
                (m) =>
                    (_category == 'Semua' || m.category == _category) &&
                    (_query.isEmpty || m.name.toLowerCase().contains(_query)),
              )
              .toList();
          final off = list.where((m) => !(avail[m.id] ?? true)).length;

          Widget card(MenuItem m) {
            final on = avail[m.id] ?? true;
            return Material(
              color: on ? AppColors.surface : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isOwner ? () => _edit(context, repo, m) : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: on ? AppColors.ink : AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.category,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  rupiah.format(m.price),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: on
                                        ? AppColors.primary
                                        : AppColors.muted,
                                  ),
                                ),
                                if (!on) ...[
                                  const SizedBox(width: 8),
                                  const StatusPill(
                                    'Habis di outlet ini',
                                    tone: Tone.danger,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: on,
                        onChanged: canToggle
                            ? (v) => availRepo.save(
                                MenuAvailability(id: m.id, available: v),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (!isOwner)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (user?.can('proposals.create') ?? false)
                              ? 'Menu aktif hanya diubah owner. Untuk menu baru atau perubahan harga, ajukan lewat tab Usulan. Anda bisa menandai item habis/tersedia (86) di outlet ini.'
                              : 'Menu dikelola owner. Anda bisa menandai item habis/tersedia di outlet ini.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  StatusPill('${list.length} menu', tone: Tone.info),
                  const SizedBox(width: 8),
                  if (off > 0) StatusPill('$off habis', tone: Tone.danger),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Cari menu',
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              if (shown.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: 'Menu tidak ditemukan',
                )
              else
                AdaptiveGrid(
                  minTileWidth: 340,
                  maxColumns: 3,
                  children: [for (final m in shown) card(m)],
                ),
            ],
          );
        },
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
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cat,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
