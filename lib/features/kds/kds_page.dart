import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/features/tables/dining_table.dart';

import '../orders/items_status.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/table_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? [];
    final status = ref.watch(itemStatusProvider).value ?? {};
    final tables = <String, String>{
      for (final t in ref.watch(tablesProvider).value ?? <DiningTable>[])
        t.id: t.name,
    };

    KitchenStatus st(OrderItem i) => status[i.id] ?? KitchenStatus.newItem;
    bool visible(KitchenStatus s) => _showReady
        ? s == KitchenStatus.ready
        : (s == KitchenStatus.newItem || s == KitchenStatus.preparing);

    // hanya order 24 jam terakhir agar data lama tidak menumpuk di layar
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;

    final tickets =
        [
          for (final o in orders)
            if (o.status != OrderStatus.voided && o.createdAt >= cutoff)
              (order: o, items: o.items.where((i) => visible(st(i))).toList()),
        ].where((t) => t.items.isNotEmpty).toList()..sort(
          (a, b) => a.order.createdAt.compareTo(b.order.createdAt),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('KDS'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Antrian')),
                ButtonSegment(value: true, label: Text('Siap antar')),
              ],
              selected: {_showReady},
              onSelectionChanged: (s) => setState(() => _showReady = s.first),
            ),
          ),
        ],
      ),
      body: tickets.isEmpty
          ? Center(
              child: Text(
                _showReady
                    ? 'Tidak ada yang siap diantar'
                    : 'Tidak ada antrian',
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in tickets)
                    SizedBox(
                      width: 300,
                      child: _ticket(t.order, t.items, tables, st),
                    ),
                ],
              ),
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
    final cs = Theme.of(context).colorScheme;
    final title = o.tableId == null
        ? 'Takeaway'
        : (tables[o.tableId] ?? 'Meja');

    return Card(
      color: late ? cs.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '$mins mnt',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(o.number, style: Theme.of(context).textTheme.bodySmall),
            const Divider(),
            for (final it in items) _row(o, it, st(it)),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _setStatus(
                o,
                items,
                _showReady ? KitchenStatus.served : KitchenStatus.ready,
              ),
              child: Text(_showReady ? 'Semua diantar' : 'Semua siap'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Order o, OrderItem it, KitchenStatus s) {
    final (label, next) = switch (s) {
      KitchenStatus.newItem => ('Mulai', KitchenStatus.preparing),
      KitchenStatus.preparing => ('Siap', KitchenStatus.ready),
      _ => ('Antar', KitchenStatus.served),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '${it.qty}×',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name),
                if (it.note.isNotEmpty)
                  Text(
                    it.note,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (s == KitchenStatus.preparing)
                  Text(s.label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _setStatus(o, [it], next),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
