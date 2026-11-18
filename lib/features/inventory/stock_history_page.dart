import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../../shell/app_bar.dart';
import '../export/period_chips.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

Tone stockKindTone(StockMoveKind k) => switch (k) {
  StockMoveKind.manual => Tone.success,
  StockMoveKind.po => Tone.info,
  StockMoveKind.sale => Tone.neutral,
  StockMoveKind.waste => Tone.danger,
  StockMoveKind.opname => Tone.warning,
  StockMoveKind.adjust => Tone.neutral,
};

/// Satu baris mutasi stok: jenis, waktu & pencatat, catatan, jumlah, dan total harga (barang masuk).
class StockMoveTile extends StatelessWidget {
  const StockMoveTile({super.key, required this.move, required this.unit, this.ingredientName});
  final StockMove move;
  final String unit;
  final String? ingredientName; // diisi di riwayat semua bahan

  @override
  Widget build(BuildContext context) {
    final m = move;
    final fmt = DateFormat('d MMM yyyy HH:mm');
    final total = m.totalCost;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(m.kind.label, tone: stockKindTone(m.kind)),
                    if (ingredientName != null)
                      Text(
                        ingredientName!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${fmt.format(DateTime.fromMillisecondsSinceEpoch(m.at))}'
                  '${m.userName.isEmpty ? '' : ' • ${m.userName}'}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                ),
                if (m.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(m.note, style: GoogleFonts.plusJakartaSans(fontSize: 12.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${m.qty > 0 ? '+' : ''}${qtyText(m.qty)} $unit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: m.qty >= 0 ? AppColors.success : AppColors.danger,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (total != null)
                Text(
                  rupiah.format(total.round()),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Riwayat stok semua bahan: filter jenis, bahan, dan periode; ringkasan total barang masuk.
class StockHistoryPage extends ConsumerStatefulWidget {
  const StockHistoryPage({super.key, this.initialKind});
  final StockMoveKind? initialKind;

  @override
  ConsumerState<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends ConsumerState<StockHistoryPage> {
  late StockMoveKind? _kind = widget.initialKind; // null = semua
  String? _ingredientId; // null = semua bahan
  DateTimeRange _range = PeriodChips.thisMonth();
  late Future<List<StockMove>> _future = _load();

  Future<List<StockMove>> _load() => loadStockMoves(
    ref.read(databaseProvider),
    ingredientId: _ingredientId,
    start: _range.start.millisecondsSinceEpoch,
    end: DateTime(_range.end.year, _range.end.month, _range.end.day + 1).millisecondsSinceEpoch,
  );

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    ref.listen(stockVersionProvider, (_, _) => _reload()); // mutasi baru masuk
    final ingredients = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final byId = {for (final i in ingredients) i.id: i};

    return Scaffold(
      appBar: const RmsAppBar(title: Text('Riwayat stok')),
      body: FutureBuilder<List<StockMove>>(
        future: _future,
        builder: (context, snap) {
          final all = snap.data;
          final list = all == null
              ? null
              : [for (final m in all) if (_kind == null || m.kind == _kind) m];
          final manualTotal = (all ?? const <StockMove>[])
              .where((m) => m.kind == StockMoveKind.manual)
              .fold<double>(0, (s, m) => s + (m.totalCost ?? 0));
          final poTotal = (all ?? const <StockMove>[])
              .where((m) => m.kind == StockMoveKind.po)
              .fold<double>(0, (s, m) => s + (m.totalCost ?? 0));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              PeriodChips(
                range: _range,
                onChanged: (r) {
                  _range = r;
                  _reload();
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _ingredientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bahan', isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Semua bahan')),
                  for (final i in ingredients)
                    DropdownMenuItem<String?>(value: i.id, child: Text(i.name)),
                ],
                onChanged: (v) {
                  _ingredientId = v;
                  _reload();
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final k in <StockMoveKind?>[null, ...StockMoveKind.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k?.label ?? 'Semua'),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (all != null)
                Row(
                  children: [
                    Expanded(
                      child: _SumCard(
                        label: 'Belanja masuk manual',
                        value: rupiah.format(manualTotal.round()),
                        onTap: () => setState(() => _kind = StockMoveKind.manual),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SumCard(
                        label: 'Penerimaan PO',
                        value: rupiah.format(poTotal.round()),
                        onTap: () => setState(() => _kind = StockMoveKind.po),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (snap.hasError)
                EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', message: '${snap.error}')
              else if (list == null)
                const SizedBox(height: 300, child: SkeletonList(count: 5, padding: EdgeInsets.zero))
              else if (list.isEmpty)
                const EmptyState(icon: Icons.history, title: 'Tidak ada mutasi pada filter ini')
              else
                for (var n = 0; n < list.length; n++)
                  Entrance(
                    index: n,
                    child: StockMoveTile(
                      move: list[n],
                      unit: byId[list[n].ingredientId]?.unit ?? '',
                      ingredientName: _ingredientId == null
                          ? (byId[list[n].ingredientId]?.name ?? 'Bahan terhapus')
                          : null,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  const _SumCard({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
