import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/features/tables/dining_table.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../orders/items_status.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/tables_providers.dart';

typedef _Ticket = ({Order order, List<OrderItem> items});

class KdsPage extends ConsumerStatefulWidget {
  const KdsPage({super.key});
  @override
  ConsumerState<KdsPage> createState() => _KdsPageState();
}

class _KdsPageState extends ConsumerState<KdsPage> {
  bool _showReady = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // refresh timer "x mnt" di tiket
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _setStatus(
    Order o,
    Iterable<OrderItem> items,
    KitchenStatus s,
  ) async {
    final repo = ref.read(itemStatusRepositoryProvider);
    for (final it in items) {
      await repo.save(ItemStatus(id: it.id, orderId: o.id, status: s));
    }
  }

  String _where(Order o, Map<String, String> tables) {
    if (o.tableId == null) return 'Takeaway';
    final name = tables[o.tableId] ?? '';
    if (name.isEmpty) return 'Meja';
    return name.toLowerCase().startsWith('meja') ? name : 'Meja $name';
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? [];
    final status = ref.watch(itemStatusProvider).value ?? {};
    final tables = <String, String>{
      for (final t in ref.watch(tablesProvider).value ?? <DiningTable>[])
        t.id: t.name,
    };

    KitchenStatus st(OrderItem i) => status[i.id] ?? KitchenStatus.newItem;

    // hanya order 24 jam terakhir agar data lama tidak menumpuk di layar
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;

    List<_Ticket> ticketsFor(bool ready) {
      bool visible(KitchenStatus s) => ready
          ? s == KitchenStatus.ready
          : (s == KitchenStatus.newItem || s == KitchenStatus.preparing);
      return [
          for (final o in orders)
            if (o.status != OrderStatus.voided && o.createdAt >= cutoff)
              (order: o, items: o.items.where((i) => visible(st(i))).toList()),
        ].where((t) => t.items.isNotEmpty).toList()
        ..sort((a, b) => a.order.createdAt.compareTo(b.order.createdAt));
    }

    final queue = ticketsFor(false);
    final readyList = ticketsFor(true);
    final tickets = _showReady ? readyList : queue;

    return Scaffold(
      appBar: AppBar(title: const Text('Dapur')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(0, 48)),
              ),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('Antrian  ${queue.length}'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Siap antar  ${readyList.length}'),
                ),
              ],
              selected: {_showReady},
              onSelectionChanged: (s) => setState(() => _showReady = s.first),
            ),
          ),
          Expanded(
            child: tickets.isEmpty
                ? EmptyState(
                    icon: _showReady
                        ? Icons.room_service_outlined
                        : Icons.soup_kitchen_outlined,
                    title: _showReady
                        ? 'Tidak ada yang siap diantar'
                        : 'Tidak ada antrian',
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      const gap = 12.0;
                      const minW = 320.0;
                      final avail = c.maxWidth - 24;
                      final cols = ((avail + gap) / (minW + gap))
                          .floor()
                          .clamp(1, 6)
                          .toInt();
                      final w = (avail - gap * (cols - 1)) / cols;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final t in tickets)
                              SizedBox(
                                width: w,
                                child: _ticket(t.order, t.items, tables, st),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ticket(
    Order o,
    List<OrderItem> items,
    Map<String, String> tables,
    KitchenStatus Function(OrderItem) st,
  ) {
    final mins = ((DateTime.now().millisecondsSinceEpoch - o.createdAt) / 60000)
        .floor();
    final late = mins >= 15;
    final warn = mins >= 10 && !late;
    final headColor = late
        ? AppColors.danger
        : warn
        ? AppColors.warning
        : AppColors.ink;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: late ? AppColors.danger : AppColors.border,
          width: late ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headColor,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _where(o, tables),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        o.number,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$mins mnt',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 14),
                  _row(o, items[i], st(items[i])),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _setStatus(
                o,
                items,
                _showReady ? KitchenStatus.served : KitchenStatus.ready,
              ),
              icon: const Icon(Icons.done_all),
              label: Text(_showReady ? 'Semua diantar' : 'Semua siap'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Order o, OrderItem it, KitchenStatus s) {
    final (label, next) = switch (s) {
      KitchenStatus.newItem => ('Mulai', KitchenStatus.preparing),
      KitchenStatus.preparing => ('Siap', KitchenStatus.ready),
      _ => ('Antar', KitchenStatus.served),
    };
    const btnSize = Size(84, 46);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            '${it.qty}×',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.name,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (s == KitchenStatus.preparing)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: StatusPill('Diproses', tone: Tone.warning),
                ),
              if (it.note.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.roseSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.priority_high,
                        size: 14,
                        color: Color(0xFFBE123C),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          it.note,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        s == KitchenStatus.newItem
            ? FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: btnSize),
                onPressed: () => _setStatus(o, [it], next),
                child: Text(label),
              )
            : FilledButton(
                style: FilledButton.styleFrom(minimumSize: btnSize),
                onPressed: () => _setStatus(o, [it], next),
                child: Text(label),
              ),
      ],
    );
  }
}
