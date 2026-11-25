import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/db/meta_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../orders/items_status.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/dining_table.dart';
import '../tables/tables_providers.dart';
import '../voice/order_announcer.dart';
import 'kitchen_kpi.dart';

enum _Range {
  today('Hari ini'),
  yesterday('Kemarin'),
  week('7 hari'),
  month('30 hari'),
  quarter('90 hari');

  const _Range(this.label);
  final String label;
}

final _hm = DateFormat('HH.mm');
final _day = DateFormat('d MMM', 'id_ID');

/// Riwayat & KPI dapur: seberapa cepat pesanan disiapkan, dari data status item di perangkat.
class KitchenKpiPage extends ConsumerStatefulWidget {
  const KitchenKpiPage({super.key});
  @override
  ConsumerState<KitchenKpiPage> createState() => _KitchenKpiPageState();
}

class _KitchenKpiPageState extends ConsumerState<KitchenKpiPage> {
  _Range _range = _Range.today;
  int _target = 15; // menit
  int _historyLimit = 30;

  static const _targetKey = 'kitchen_kpi_target';

  @override
  void initState() {
    super.initState();
    ref.read(metaDbProvider).getMeta(_targetKey).then((m) {
      final v = (m?['minutes'] as num?)?.toInt();
      if (v != null && mounted) setState(() => _target = v);
    });
  }

  void _setTarget(int v) {
    setState(() => _target = v);
    ref.read(metaDbProvider).putMeta(_targetKey, {'minutes': v});
  }

  (int, int) _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 1));
    return switch (_range) {
      _Range.today => (today.millisecondsSinceEpoch, end.millisecondsSinceEpoch),
      _Range.yesterday => (
        today.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        today.millisecondsSinceEpoch,
      ),
      _Range.week => (today.subtract(const Duration(days: 6)).millisecondsSinceEpoch, end.millisecondsSinceEpoch),
      _Range.month => (today.subtract(const Duration(days: 29)).millisecondsSinceEpoch, end.millisecondsSinceEpoch),
      _Range.quarter => (today.subtract(const Duration(days: 89)).millisecondsSinceEpoch, end.millisecondsSinceEpoch),
    };
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? const <Order>[];
    final status = ref.watch(itemStatusDocsProvider).value ?? const <String, ItemStatus>{};
    final tables = {for (final t in ref.watch(tablesProvider).value ?? const <DiningTable>[]) t.id: t.name};
    final (from, to) = _bounds();
    final kpi = KitchenKpi.build(
      orders: orders,
      status: status,
      from: from,
      to: to,
      targetMs: _target * 60000,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat & KPI dapur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in _Range.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) => setState(() {
                        _range = r;
                        _historyLimit = 30;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Target siap', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted)),
              const SizedBox(width: 10),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [for (final m in const [10, 15, 20, 30]) ButtonSegment(value: m, label: Text('$m mnt'))],
                selected: {_target},
                onSelectionChanged: (v) => _setTarget(v.first),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (kpi.records.isEmpty)
            const EmptyState(
              icon: Icons.soup_kitchen_outlined,
              title: 'Belum ada item selesai di periode ini',
              message: 'Data terisi saat dapur menekan Mulai / Siap di layar Dapur, atau kasir menekan Panggil di Antrean.',
            )
          else ...[
            _summary(kpi),
            const SizedBox(height: 12),
            _stages(kpi),
            const SizedBox(height: 12),
            _hours(kpi),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final a = _groups('Menu paling lama', kpi.slowestMenus.take(5).toList(), 'Belum cukup data (min. 2 per menu)');
                final b = _groups('Per petugas dapur', kpi.byCook, 'Belum ada nama petugas');
                return c.maxWidth >= 760
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
                      )
                    : Column(children: [a, const SizedBox(height: 12), b]);
              },
            ),
            const SizedBox(height: 12),
            _history(kpi, tables),
          ],
        ],
      ),
    );
  }

  Widget _summary(KitchenKpi k) {
    final pct = k.onTime == null ? '—' : '${(k.onTime! * 100).round()}%';
    final tiles = [
      StatTile(
        icon: Icons.restaurant_rounded,
        label: 'Porsi selesai',
        value: '${k.portions}',
        caption: '${k.records.length} item',
      ),
      StatTile(
        icon: Icons.timer_outlined,
        label: 'Rata-rata sampai siap',
        value: minutesText(k.total.avg),
        caption: '90% ≤ ${minutesText(k.total.p90)}',
      ),
      StatTile(
        icon: Icons.verified_outlined,
        label: 'Tepat waktu (≤ $_target mnt)',
        value: pct,
        tone: Tone.success,
        caption: k.lateCount == 0 ? 'Tidak ada yang telat' : '${k.lateCount} item telat',
        captionTone: k.lateCount == 0 ? Tone.success : Tone.danger,
      ),
      StatTile(
        icon: Icons.room_service_outlined,
        label: 'Rata-rata antar / ambil',
        value: minutesText(k.deliver.avg),
        caption: 'Siap → diantar',
      ),
    ];
    return AdaptiveGrid(minTileWidth: 200, maxColumns: 4, children: tiles);
  }

  Widget _stages(KitchenKpi k) {
    final rows = [
      ('Antre', 'Masuk → mulai dimasak', k.wait),
      ('Masak', 'Mulai → siap', k.cook),
      ('Total', 'Masuk → siap', k.total),
      ('Antar', 'Siap → diantar / diambil', k.deliver),
    ];
    final maxAvg = rows.map((r) => r.$3.avg ?? 0).fold(1, (a, b) => a > b ? a : b);
    return SectionCard(
      title: 'Waktu tiap tahap',
      child: Column(
        children: [
          for (final (name, sub, s) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.faint)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (s.avg ?? 0) / maxAvg),
                        duration: Motion.slow,
                        curve: Motion.curve,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          backgroundColor: AppColors.sunken,
                          color: name == 'Total' ? AppColors.primary : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      s.count == 0 ? 'belum ada' : minutesText(s.avg),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: s.count == 0 ? AppColors.faint : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (k.wait.count == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tahap Antre & Masak butuh tombol Mulai di layar Dapur. Tanpa layar Dapur hanya Total & Antar yang terukur.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.faint, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hours(KitchenKpi k) {
    final h = k.perHour;
    final first = h.indexWhere((v) => v > 0);
    final last = h.lastIndexWhere((v) => v > 0);
    if (first < 0) return const SizedBox.shrink();
    final maxV = h.fold(1, (a, b) => a > b ? a : b);
    final peak = h.indexOf(maxV);
    return SectionCard(
      title: 'Jam sibuk',
      trailing: Text(
        'Puncak ${peak.toString().padLeft(2, '0')}.00 · $maxV porsi',
        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
      ),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = first; i <= last; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (h[i] > 0)
                        Text('${h[i]}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: h[i] / maxV),
                        duration: Motion.slow,
                        curve: Motion.curve,
                        builder: (_, v, _) => Container(
                          height: 100 * v + 2,
                          decoration: BoxDecoration(
                            color: i == peak ? AppColors.primary : AppColors.ink.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$i',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.faint),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _groups(String title, List<GroupStats> groups, String empty) => SectionCard(
    title: title,
    child: groups.isEmpty
        ? Text(empty, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.faint))
        : Column(
            children: [
              for (final g in groups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${g.portions} porsi · masak ${minutesText(g.cook.avg)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            minutesText(g.total.avg),
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          if (g.onTime != null)
                            Text(
                              '${(g.onTime! * 100).round()}% tepat',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: g.onTime! >= 0.9 ? AppColors.sageInk : AppColors.danger,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _history(KitchenKpi k, Map<String, String> tables) {
    // satu baris per pesanan, urut item siap terbaru
    final byOrder = <String, List<KitchenRecord>>{};
    for (final r in k.records) {
      (byOrder[r.order.id] ??= []).add(r);
    }
    final orders = byOrder.values.toList();
    final shown = orders.take(_historyLimit).toList();
    String t(int? ms) => ms == null ? '—' : _hm.format(DateTime.fromMillisecondsSinceEpoch(ms));

    return SectionCard(
      title: 'Riwayat (${orders.length} pesanan)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final rs in shown)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_cap(spokenWhere(rs.first.order, tables))} · ${rs.first.order.number}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        _day.format(DateTime.fromMillisecondsSinceEpoch(rs.first.status.readyAt!)),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.faint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final r in rs)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.item.qty}× ${r.item.name}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'masuk ${t(r.enteredAt)} · mulai ${t(r.status.preparingAt)} · siap ${t(r.status.readyAt)}'
                                  ' · diantar ${t(r.status.servedAt)}'
                                  '${r.cookName.isEmpty ? '' : ' · ${r.cookName}'}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            minutesText(r.total),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: (r.total ?? 0) > k.targetMs ? AppColors.danger : AppColors.sageInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (orders.length > shown.length)
            TextButton(
              onPressed: () => setState(() => _historyLimit += 30),
              child: Text('Tampilkan lagi (${orders.length - shown.length})'),
            ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
