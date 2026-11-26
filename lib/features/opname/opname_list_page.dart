import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../../shell/app_bar.dart';
import '../auth/auth_providers.dart';
import '../help/help_page.dart';
import '../inventory/inventory_providers.dart';
import 'opname_detail_page.dart';
import 'opname_models.dart';
import 'opname_providers.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');
final _isoFmt = DateFormat('yyyy-MM-dd');

String opnameDateText(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : _dateFmt.format(d);
}

Tone opnameTone(OpnameStatus s) => switch (s) {
  OpnameStatus.open => Tone.warning,
  OpnameStatus.submitted => Tone.success,
  OpnameStatus.cancelled => Tone.neutral,
};

enum _Filter { all, open, submitted, cancelled }

/// Daftar tiket stok opname untuk outlet yang sedang dibuka.
class StockOpnamePage extends ConsumerStatefulWidget {
  const StockOpnamePage({super.key});
  @override
  ConsumerState<StockOpnamePage> createState() => _StockOpnamePageState();
}

class _StockOpnamePageState extends ConsumerState<StockOpnamePage> {
  _Filter _filter = _Filter.all;
  String _query = '';

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _openDetail(String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => OpnameDetailPage(opnameId: id)),
  );

  Future<void> _create(List<StockOpname> all) async {
    final running = all.where((o) => o.isOpen).firstOrNull;
    if (running != null) {
      _toast('Selesaikan atau batalkan ${running.number} dulu');
      _openDetail(running.id);
      return;
    }
    final outlet = ref.read(activeOutletProvider);
    final user = ref.read(appUserProvider).value;
    if (outlet == null || user == null) {
      _toast('Pilih outlet terlebih dahulu');
      return;
    }
    final note = TextEditingController();
    var date = DateTime.now();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Opname baru'),
          content: SingleChildScrollView(
            // HP kecil / keyboard terbuka: isi dialog bisa digulir, tidak overflow
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Semua bahan beserta stok sistemnya masuk ke tiket ini. '
                    'Isi stok fisik tiap bahan, lalu kirim.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Outlet'),
                    child: Text(
                      outlet.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: now.subtract(const Duration(days: 60)),
                        lastDate: now,
                      );
                      if (d != null) setS(() => date = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal opname',
                        suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        _dateFmt.format(date),
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      hintText: 'mis. Opname akhir bulan',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buat tiket')),
          ],
        ),
      ),
    );
    final noteText = note.text.trim();
    note.dispose();
    if (ok != true) return;

    final id = const Uuid().v4();
    final iso = _isoFmt.format(date);
    final o = StockOpname(
      id: id,
      number: 'OPN-${iso.replaceAll('-', '')}-${id.substring(0, 4).toUpperCase()}',
      date: iso,
      status: OpnameStatus.open,
      createdBy: user.uid,
      createdByName: user.name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      note: noteText,
    );
    await ref.read(opnameRepositoryProvider).save(o);
    if (mounted) _openDetail(id);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final outlet = ref.watch(activeOutletProvider);
    final async = ref.watch(opnamesProvider);
    final all = async.value ?? const <StockOpname>[];
    final totalIngredients = ref.watch(ingredientsProvider).value?.length ?? 0;
    final canCreate = user?.can('stock_opname.create') ?? false;

    int count(_Filter f) => all.where((o) => _match(o, f)).length;
    final shown = all
        .where((o) => _match(o, _filter))
        .where((o) => _query.isEmpty || o.number.toLowerCase().contains(_query))
        .toList();

    return Scaffold(
      appBar: RmsAppBar(
        title: const Text('Stok opname'),
        pageActions: [
          PageAction(
            icon: Icons.menu_book_outlined,
            label: 'Panduan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const HelpPage(initialTopic: 'opname')),
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _create(all),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Opname baru'),
            )
          : null,
      body: async.isLoading && all.isEmpty
          ? const SkeletonList()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 18, color: AppColors.faint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        outlet?.name ?? '-',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      '${all.length} tiket',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (f, label) in const [
                        (_Filter.all, 'Semua'),
                        (_Filter.open, 'Berjalan'),
                        (_Filter.submitted, 'Selesai'),
                        (_Filter.cancelled, 'Dibatalkan'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$label · ${count(f)}'),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Cari nomor opname',
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: all.isEmpty ? 'Belum ada opname' : 'Tidak ada yang cocok',
                    message: all.isEmpty && canCreate
                        ? 'Buat tiket opname untuk menghitung stok fisik semua bahan.'
                        : null,
                  )
                else
                  AdaptiveGrid(
                    minTileWidth: 380,
                    maxColumns: 3,
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Entrance(
                          index: i,
                          child: _OpnameCard(
                            opname: shown[i],
                            totalIngredients: totalIngredients,
                            onTap: () => _openDetail(shown[i].id),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }

  bool _match(StockOpname o, _Filter f) => switch (f) {
    _Filter.all => true,
    _Filter.open => o.status == OpnameStatus.open,
    _Filter.submitted => o.status == OpnameStatus.submitted,
    _Filter.cancelled => o.status == OpnameStatus.cancelled,
  };
}

class _OpnameCard extends ConsumerWidget {
  const _OpnameCard({required this.opname, required this.totalIngredients, required this.onTap});
  final StockOpname opname;
  final int totalIngredients;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = opname;
    // progres: tiket berjalan dari draf di perangkat; tiket selesai dari hasil terkirim
    final filled = o.isOpen
        ? (ref.watch(opnameDraftFilledProvider(o.id)).value ?? 0)
        : o.items.length;
    final total = o.isOpen ? totalIngredients : o.items.length;
    final pct = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);
    final done = pct >= 1;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: o.isOpen ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                StatusPill(o.status.label, tone: opnameTone(o.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${opnameDateText(o.date)} · ${o.createdByName}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
            ),
            if (o.note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                o.note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.faint),
              ),
            ],
            const SizedBox(height: 12),
            if (o.status == OpnameStatus.cancelled)
              Text(
                'Dibatalkan${o.cancelledByName.isEmpty ? '' : ' oleh ${o.cancelledByName}'}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.faint),
              )
            else ...[
              Row(
                children: [
                  Text(
                    o.isOpen ? '$filled/$total bahan terisi' : '${o.items.length} bahan · ${o.diffCount} selisih',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (o.isOpen)
                    Text(
                      '${(pct * 100).round()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: done ? AppColors.sageInk : AppColors.primary,
                      ),
                    )
                  else if (o.awaitingServer)
                    Text(
                      'Menunggu server',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: o.isOpen ? pct : 1),
                  duration: Motion.slow,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: AppColors.sunken,
                    color: done || !o.isOpen ? AppColors.sage : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
