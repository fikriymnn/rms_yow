import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import 'shift.dart';
import 'shift_providers.dart';

({int cash, int other, int count}) shiftTotals(Shift s, List<Order> orders) {
  var cash = 0, other = 0, count = 0;
  for (final o in orders) {
    if (o.shiftId != s.id || o.status != OrderStatus.paid) continue;
    count++;
    if (o.payMethod == PayMethod.cash) {
      cash += o.total; // kembalian sudah keluar dari laci, jadi pakai total
    } else {
      other += o.total;
    }
  }
  return (cash: cash, other: other, count: count);
}

class ShiftPage extends ConsumerStatefulWidget {
  const ShiftPage({super.key});
  @override
  ConsumerState<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends ConsumerState<ShiftPage> {
  final _opening = TextEditingController();
  static final _fmt = DateFormat('d MMM HH:mm');

  String _t(int ms) => _fmt.format(DateTime.fromMillisecondsSinceEpoch(ms));

  Future<void> _open() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref
        .read(shiftRepositoryProvider)
        .save(
          Shift(
            id: const Uuid().v4(),
            cashierId: user.uid,
            cashierName: user.name,
            openedAt: DateTime.now().millisecondsSinceEpoch,
            openingCash: int.tryParse(_opening.text) ?? 0,
          ),
        );
    _opening.clear();
  }

  Future<void> _close(
    Shift s,
    int expected,
    ({int cash, int other, int count}) t,
  ) async {
    final c = TextEditingController();
    final counted = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final v = int.tryParse(c.text);
          return AlertDialog(
            title: const Text('Tutup shift'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kas seharusnya: ${rupiah.format(expected)}'),
                TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Uang fisik di laci',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                if (v != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Selisih: ${rupiah.format(v - expected)}'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: v == null ? null : () => Navigator.pop(ctx, v),
                child: const Text('Tutup shift'),
              ),
            ],
          );
        },
      ),
    );
    if (counted == null) return;
    await ref
        .read(shiftRepositoryProvider)
        .save(
          s.copyWith(
            status: ShiftStatus.closed,
            closedAt: DateTime.now().millisecondsSinceEpoch,
            closingCash: counted,
            expectedCash: expected,
            cashSales: t.cash,
            otherSales: t.other,
            orderCount: t.count,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final shift = ref.watch(currentShiftProvider);
    final orders = ref.watch(ordersProvider).value ?? <Order>[];
    final shifts = ref.watch(shiftsProvider).value ?? <Shift>[];
    final user = ref.watch(appUserProvider).value;
    final history = shifts
        .where(
          (s) =>
              s.status == ShiftStatus.closed &&
              ((user?.canManageMenu ?? false) || s.cashierId == user?.uid),
        )
        .take(30)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kas & Shift')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (shift == null) _openCard() else _activeCard(shift, orders),
          const SizedBox(height: 24),
          Text('Riwayat shift', style: Theme.of(context).textTheme.titleMedium),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Belum ada riwayat'),
            ),
          for (final s in history) _historyTile(s, orders),
        ],
      ),
    );
  }

  Widget _historyTile(Shift s, List<Order> orders) {
    // shift lama (ditutup sebelum update ini) belum punya snapshot -> hitung dari order
    final t = s.cashSales != null
        ? (
            cash: s.cashSales!,
            other: s.otherSales ?? 0,
            count: s.orderCount ?? 0,
          )
        : shiftTotals(s, orders);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text('${s.cashierName} • ${_t(s.openedAt)}'),
      subtitle: Text('Selisih: ${rupiah.format(s.difference ?? 0)}'),
      children: [
        _kv('Dibuka', _t(s.openedAt)),
        if (s.closedAt != null) _kv('Ditutup', _t(s.closedAt!)),
        _kv('Modal awal', rupiah.format(s.openingCash)),
        _kv('Penjualan tunai', rupiah.format(t.cash)),
        _kv('Penjualan non-tunai', rupiah.format(t.other)),
        _kv('Total penjualan', rupiah.format(t.cash + t.other), bold: true),
        _kv('Jumlah order', '${t.count}'),
        const Divider(),
        _kv('Kas seharusnya', rupiah.format(s.expectedCash ?? 0)),
        _kv('Uang fisik', rupiah.format(s.closingCash ?? 0)),
        _kv('Selisih', rupiah.format(s.difference ?? 0), bold: true),
      ],
    );
  }

  Widget _openCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Belum ada shift aktif',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _opening,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Modal awal laci (Rp)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _open, child: const Text('Buka shift')),
        ],
      ),
    ),
  );

  Widget _activeCard(Shift s, List<Order> orders) {
    final t = shiftTotals(s, orders);
    final expected = s.openingCash + t.cash;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shift aktif', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Dibuka ${_t(s.openedAt)} oleh ${s.cashierName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            _kv('Modal awal', rupiah.format(s.openingCash)),
            _kv('Penjualan tunai', rupiah.format(t.cash)),
            _kv('Penjualan non-tunai', rupiah.format(t.other)),
            _kv('Jumlah order', '${t.count}'),
            const Divider(height: 24),
            _kv('Kas seharusnya', rupiah.format(expected), bold: true),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _close(s, expected, t),
              child: const Text('Tutup shift'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final st = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: st),
          Text(v, style: st),
        ],
      ),
    );
  }
}
