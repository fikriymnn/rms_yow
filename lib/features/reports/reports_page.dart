import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/reason_dialog.dart';
import 'package:rms_yow/features/audit/audit_log.dart';
import 'package:rms_yow/features/audit/audit_providers.dart';
import 'package:rms_yow/features/auth/auth_providers.dart';
import 'package:rms_yow/features/shifts/shift_providers.dart';

import '../../core/format.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime _day = DateTime.now();
  static final _dateFmt = DateFormat('EEE, d MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  void _move(int days) =>
      setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _day = d);
  }

  Future<void> _detail(Order o) async {
    final isManager = ref.read(appUserProvider).value?.isManager ?? false;
    final doRefund = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(o.number),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in o.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${it.qty}× ${it.name}')),
                      Text(rupiah.format(it.total)),
                    ],
                  ),
                ),
              const Divider(),
              Text('Total: ${rupiah.format(o.total)}'),
              Text('Bayar: ${o.payMethod?.name.toUpperCase() ?? '-'}'),
              if (o.status == OrderStatus.refunded)
                Text('Refund: ${o.refundReason ?? '-'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (isManager && o.status == OrderStatus.paid)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Refund'),
            ),
        ],
      ),
    );
    if (doRefund == true && mounted) await _refund(o);
  }

  Future<void> _refund(Order o) async {
    final shift = ref.read(currentShiftProvider);
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buka shift dulu di tab Kas untuk melakukan refund'),
        ),
      );
      return;
    }
    final reason = await askReason(context, 'Refund ${o.number}');
    if (reason == null) return;
    await ref
        .read(orderRepositoryProvider)
        .save(
          o.copyWith(
            status: OrderStatus.refunded,
            refundedAt: DateTime.now().millisecondsSinceEpoch,
            refundShiftId: shift.id,
            refundReason: reason,
          ),
        );
    await ref
        .read(auditRepositoryProvider)
        .record(
          AuditAction.refund,
          reason: reason,
          order: o,
          detail: o.payMethod?.name.toUpperCase() ?? '',
          amount: o.total,
        );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? <Order>[];
    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      _day.year,
      _day.month,
      _day.day + 1,
    ).millisecondsSinceEpoch;

    final paid =
        orders
            .where(
              (o) =>
                  (o.status == OrderStatus.paid ||
                      o.status == OrderStatus.refunded) &&
                  (o.paidAt ?? 0) >= start &&
                  (o.paidAt ?? 0) < end,
            )
            .toList()
          ..sort((a, b) => (b.paidAt ?? 0).compareTo(a.paidAt ?? 0));

    final total = paid.fold<int>(0, (s, o) => s + o.total);
    final sub = paid.fold<int>(0, (s, o) => s + o.subtotal);
    final disc = paid.fold<int>(0, (s, o) => s + o.discount);
    final tax = paid.fold<int>(0, (s, o) => s + o.tax);
    final svc = paid.fold<int>(0, (s, o) => s + o.service);
    final avg = paid.isEmpty ? 0 : (total / paid.length).round();
    final refunds = orders
        .where(
          (o) =>
              o.status == OrderStatus.refunded &&
              (o.refundedAt ?? 0) >= start &&
              (o.refundedAt ?? 0) < end,
        )
        .toList();
    final refundTotal = refunds.fold<int>(0, (s, o) => s + o.total);
    final net = total - refundTotal;
    final logs = (ref.watch(auditLogsProvider).value ?? <AuditLog>[])
        .where((l) => l.at >= start && l.at < end)
        .toList();

    final byMethod = <PayMethod, int>{};
    final qty = <String, int>{};
    final rev = <String, int>{};
    for (final o in paid) {
      final m = o.payMethod ?? PayMethod.other;
      byMethod[m] = (byMethod[m] ?? 0) + o.total;
      for (final it in o.items) {
        qty[it.name] = (qty[it.name] ?? 0) + it.qty;
        rev[it.name] = (rev[it.name] ?? 0) + it.total;
      }
    }
    final top =
        (rev.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(10)
            .toList();
    final maxRev = max(1, top.isEmpty ? 1 : top.first.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _move(-1),
          ),
          TextButton(onPressed: _pick, child: Text(_dateFmt.format(_day))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isToday ? null : () => _move(1),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat('Penjualan bersih', rupiah.format(net)),
              _stat('Jumlah order', '${paid.length}'),
              _stat('Rata-rata/order', rupiah.format(avg)),
            ],
          ),
          if (paid.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada transaksi pada tanggal ini'),
              ),
            ),
          _section('Rincian'),
          _row('Subtotal', rupiah.format(sub)),
          if (disc > 0) _row('Diskon', '-${rupiah.format(disc)}'),
          _row('Pajak', rupiah.format(tax)),
          if (svc > 0) _row('Service', rupiah.format(svc)),
          _row('Total penjualan', rupiah.format(total)),
          if (refundTotal > 0) _row('Refund', '-${rupiah.format(refundTotal)}'),
          _row('Penjualan bersih', rupiah.format(net), bold: true),
          if (byMethod.isNotEmpty) _section('Metode pembayaran'),
          for (final e in byMethod.entries)
            _row(e.key.name.toUpperCase(), rupiah.format(e.value)),
          if (top.isNotEmpty) _section('Menu terlaris'),
          for (final e in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.key)),
                      Text('${qty[e.key]}× • ${rupiah.format(e.value)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: e.value / maxRev),
                ],
              ),
            ),
          if (paid.isNotEmpty) _section('Transaksi'),
          for (final o in paid)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () => _detail(o),
              title: Text(o.number),
              subtitle: Text(
                '${_timeFmt.format(DateTime.fromMillisecondsSinceEpoch(o.paidAt ?? 0))}'
                ' • ${o.payMethod?.name.toUpperCase() ?? '-'}'
                '${o.status == OrderStatus.refunded ? ' • REFUND' : ''}',
              ),
              trailing: Text(
                rupiah.format(o.total),
                style: TextStyle(
                  decoration: o.status == OrderStatus.refunded
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          if (logs.isNotEmpty) _section('Void, refund & diskon'),
          for (final l in logs)
            ListTile(
              dense: true,
              isThreeLine: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${l.action.label} • ${rupiah.format(l.amount)}'),
              subtitle: Text(
                '${_timeFmt.format(DateTime.fromMillisecondsSinceEpoch(l.at))} • ${l.userName} • ${l.orderNumber}\n'
                '${l.detail.isEmpty ? '' : '${l.detail} • '}${l.reason}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => SizedBox(
    width: 180,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(t, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _row(String k, String v, {bool bold = false}) {
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
