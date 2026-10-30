import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/core/sync/sync_controller.dart';
import 'package:rms_yow/features/auth/auth_providers.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../approvals/approval_providers.dart';
import '../approvals/approvals_page.dart';
import '../approvals/pending_requests_card.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class IngredientsTab extends ConsumerStatefulWidget {
  const IngredientsTab({super.key});
  @override
  ConsumerState<IngredientsTab> createState() => _IngredientsTabState();
}

class _IngredientsTabState extends ConsumerState<IngredientsTab> {
  String _query = '';

  static const _labels = [
    'Nama',
    'Satuan dasar (g / ml / pcs)',
    'Stok minimum',
    'Satuan beli (mis. kg; kosongkan jika sama)',
    '1 satuan beli = ... satuan dasar',
  ];

  @override
  Widget build(BuildContext context) {
    final ings = ref.watch(ingredientsProvider).value ?? <Ingredient>[];
    final user = ref.watch(appUserProvider).value;
    final isOwner = user?.can('ingredients.update') ?? false; // tulis langsung
    final canRequest = user?.can('approvals.create') ?? false;
    final shown = ings
        .where((i) => _query.isEmpty || i.name.toLowerCase().contains(_query))
        .toList();

    Widget card(Ingredient i) {
      final sub = [
        if (i.buyUnit.isNotEmpty)
          'Beli per ${i.buyUnit} (= ${qtyText(i.buyFactor)} ${i.unit})',
        if (i.minStock > 0) 'Minimum ${qtyText(i.minStock)} ${i.unit}',
      ].join(' • ');
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isOwner
              ? () => _edit(context, ref, i)
              : canRequest
              ? () => _request(context, ref, i)
              : null,
          onLongPress: isOwner ? () => _delete(context, ref, i) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    i.name.trim().isEmpty
                        ? '?'
                        : i.name.trim()[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusPill(i.unit),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Bahan'),
            )
          : canRequest
          ? FloatingActionButton.extended(
              onPressed: () => _request(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Ajukan bahan'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const PendingRequestsCard(type: 'ingredient'),
          if (ings.isEmpty)
            const EmptyState(
              icon: Icons.egg_alt_outlined,
              title: 'Belum ada bahan',
            )
          else ...[
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari bahan',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
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
                children: [for (final i in shown) card(i)],
              ),
            if (isOwner || canRequest)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  isOwner
                      ? 'Ketuk untuk mengedit • tekan lama untuk menghapus'
                      : 'Ketuk bahan untuk mengajukan perubahan (perlu persetujuan)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<String> _initial(Ingredient? ing) => ing == null
      ? ['', 'g', '0', '', '1']
      : [
          ing.name,
          ing.unit,
          qtyPlain(ing.minStock),
          ing.buyUnit,
          qtyPlain(ing.buyFactor),
        ];

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Ingredient? ing,
  ) async {
    final r = await formDialog(
      context,
      ing == null ? 'Bahan baru' : 'Edit bahan',
      _labels,
      initial: _initial(ing),
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

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    Ingredient? ing,
  ) async {
    final r = await formDialog(
      context,
      ing == null ? 'Ajukan bahan baru' : 'Ajukan perubahan: ${ing.name}',
      _labels,
      initial: _initial(ing),
      numeric: {2, 4},
      okLabel: 'Ajukan',
      hint: ing == null
          ? 'Bahan aktif setelah disetujui.'
          : 'Satuan dasar tidak bisa diubah. Buat bahan baru bila perlu.',
    );
    if (r == null || r[0].isEmpty || r[1].isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final factor = parseNum(r[4]) ?? 1;
      await submitIngredient(
        ref,
        action: ing == null ? 'create' : 'update',
        ingredientId: ing?.id,
        name: r[0],
        unit: r[1],
        minStock: parseNum(r[2]) ?? 0,
        buyUnit: r[3],
        buyFactor: factor > 0 ? factor : 1,
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Diajukan untuk persetujuan'),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApprovalsPage()),
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Ingredient i,
  ) async {
    final hasMoves = await ref.read(databaseProvider).ingredientHasMoves(i.id);
    final used =
        hasMoves ||
        (ref.read(recipesProvider).value ?? <String, Recipe>{}).values.any(
          (r) => r.lines.any((l) => l.ingredientId == i.id),
        );
    if (used) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bahan sudah dipakai (stok/resep), tidak bisa dihapus'),
        ),
      );
      return;
    }
    if (!context.mounted) return;
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
