import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/data_window.dart';
import 'package:rms_yow/core/reason_dialog.dart';
import 'package:rms_yow/features/audit/audit_log.dart';
import 'package:rms_yow/features/audit/audit_providers.dart';
import 'package:rms_yow/features/auth/auth_providers.dart';
import 'package:rms_yow/features/export/export_builders.dart';
import 'package:rms_yow/features/export/export_pdf.dart';
import 'package:rms_yow/features/export/export_service.dart';
import 'package:rms_yow/features/export/export_tab.dart';
import 'package:rms_yow/features/export/xlsx_writer.dart';
import 'package:rms_yow/features/printing/printer_service.dart';
import 'package:rms_yow/features/printing/printer_settings.dart';
import 'package:rms_yow/features/printing/receipt_template.dart';
import 'package:rms_yow/features/shifts/shift_providers.dart';
import 'package:rms_yow/features/tables/dining_table.dart';
import 'package:rms_yow/features/tables/tables_providers.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime _day = DateTime.now();
  OrderSource? _source; // null = semua sumber
  String _search = ''; // cari no. order / no. pesanan online / nomor antrean
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

  /// Unduh laporan tanggal yang dipilih, mengikuti filter sumber pesanan.
  Future<void> _download(String kind) async {
    final start = DateTime(_day.year, _day.month, _day.day);
    final end = DateTime(_day.year, _day.month, _day.day + 1);
    final stamp = DateFormat('yyyyMMdd').format(start);
    final tag = _source == null ? '' : '_${_source!.name}';
    final label = DateFormat('d MMM yyyy', 'id_ID').format(start);
    try {
      final d = await loadExportData(ref, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, _source);
      if (d.soldOrders.isEmpty && kind != 'pdf') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada transaksi pada tanggal ini')));
        }
        return;
      }
      switch (kind) {
        case 'xlsx':
          XlsxSheet sheet(String n, List<List<Object?>> rows) => XlsxSheet(
            n,
            rows,
            boldRows: {if (rows.length > 1 && rows.last.first == 'TOTAL') rows.length - 1},
          );
          await shareBytes(
            'rms_laporan${tag}_$stamp.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            buildXlsx([
              XlsxSheet('Info', [
                ['Laporan RMS'],
                ['Tanggal', label],
                ['Sumber pesanan', d.sourceLabel],
              ], headerRows: 0, boldRows: {0}),
              sheet('Sumber pesanan', sourceRows(d)),
              sheet('Penjualan per order', ordersRows(d)),
              sheet('Penjualan per item', itemsRows(d)),
            ], headerArgb: AppColors.primaryHex),
          );
        case 'pdf':
          await shareBytes('rms_ringkasan${tag}_$stamp.pdf', 'application/pdf', await buildSummaryPdf(d, label));
        case 'trx':
          await shareBytes('rms_transaksi${tag}_$stamp.pdf', 'application/pdf', await buildTransactionsPdf(d, label));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunduh: $e')));
    }
  }

  Future<void> _detail(Order o) async {
    final isManager =
        ref.read(appUserProvider).value?.can('orders.refund') ?? false;
    final refunded = o.status == OrderStatus.refunded;
    final action = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(o.number),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      o.payMethod?.label ?? '-',
                      tone: Tone.info,
                    ),
                    if (o.source.isOnline) ...[
                      const SizedBox(width: 6),
                      StatusPill(o.source.label, tone: Tone.success),
                    ],
                    if (refunded) ...[
                      const SizedBox(width: 6),
                      const StatusPill('Refund', tone: Tone.danger),
                    ],
                    const Spacer(),
                    Text(
                      _timeFmt.format(
                        DateTime.fromMillisecondsSinceEpoch(o.paidAt ?? 0),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (o.externalNo != null || o.callLabel != null) ...[
                  const SizedBox(height: 10),
                  if (o.externalNo != null)
                    Text(
                      'No. pesanan ${o.source.label}: ${o.externalNo}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  if (o.callLabel != null)
                    Text(
                      '${o.queueNo != null ? 'Nomor antrean ${o.queueNo}' : 'Atas nama ${o.customerName}'}'
                      ' · ${o.type == OrderType.takeaway ? 'Takeaway' : 'Makan di sini'}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted),
                    ),
                ],
                const SizedBox(height: 14),
                for (final it in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${it.qty}× ${it.name}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          rupiah.format(it.total),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                KvRow('Subtotal', rupiah.format(o.subtotal)),
                if (o.discount > 0)
                  KvRow('Diskon', '-${rupiah.format(o.discount)}'),
                if (o.tax > 0) KvRow('Pajak', rupiah.format(o.tax)),
                if (o.service > 0) KvRow('Service', rupiah.format(o.service)),
                KvRow(
                  'Total',
                  rupiah.format(o.total),
                  bold: true,
                  color: AppColors.primary,
                ),
                if (refunded)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.roseSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Alasan refund: ${o.refundReason ?? '-'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'print'),
            child: const Text('Cetak struk'),
          ),
          if (isManager && o.status == OrderStatus.paid)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, 'refund'),
              child: const Text('Refund'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'refund') await _refund(o);
    if (action == 'print') await _printReceipt(o);
  }

  Future<void> _printReceipt(Order o) async {
    final messenger = ScaffoldMessenger.of(context);
    final cfg =
        ref.read(effectivePrinterSettingsProvider) ?? const PrinterSettings();
    final tables = ref.read(tablesProvider).value ?? <DiningTable>[];
    final t = tables.where((e) => e.id == o.tableId).firstOrNull;
    try {
      await printOrderReceipt(
        settings: cfg,
        order: o,
        tableName: t?.name,
        copy: true,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
    }
  }

  Future<void> _refund(Order o) async {
    final shift = await resolveCurrentShift(ref);
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
          detail: o.payMethod?.label ?? '',
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

    final dayPaid =
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
    // semua angka di bawah mengikuti filter sumber pesanan
    final paid = _source == null ? dayPaid : dayPaid.where((o) => o.source == _source).toList();
    final bySource = <OrderSource, ({int n, int total})>{};
    for (final o in dayPaid) {
      final cur = bySource[o.source] ?? (n: 0, total: 0);
      bySource[o.source] = (n: cur.n + 1, total: cur.total + o.total);
    }
    final q = _search.trim().toLowerCase();
    final shownTrx = q.isEmpty
        ? paid
        : paid
              .where(
                (o) =>
                    o.number.toLowerCase().contains(q) ||
                    (o.externalNo ?? '').toLowerCase().contains(q) ||
                    (o.queueNo ?? '').toLowerCase() == q ||
                    (o.customerName ?? '').toLowerCase().contains(q),
              )
              .toList();

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
              (_source == null || o.source == _source) &&
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
    final methods = byMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final methodTotal = max(1, methods.fold<int>(0, (s, e) => s + e.value));

    final tiles = <Widget>[
      StatTile(
        icon: Icons.payments_outlined,
        label: 'Penjualan bersih',
        value: rupiah.format(net),
        caption: refundTotal > 0
            ? 'Setelah refund ${rupiah.format(refundTotal)}'
            : null,
        captionTone: Tone.danger,
      ),
      StatTile(
        icon: Icons.receipt_long_outlined,
        label: 'Jumlah order',
        value: '${paid.length}',
      ),
      StatTile(
        icon: Icons.analytics_outlined,
        label: 'Rata-rata/order',
        value: rupiah.format(avg),
      ),
      if (disc > 0)
        StatTile(
          icon: Icons.sell_outlined,
          label: 'Total diskon',
          value: rupiah.format(disc),
          tone: Tone.warning,
        ),
    ];

    final rincian = SectionCard(
      title: 'Rincian',
      child: Column(
        children: [
          KvRow('Subtotal', rupiah.format(sub)),
          if (disc > 0) KvRow('Diskon', '-${rupiah.format(disc)}'),
          KvRow('Pajak', rupiah.format(tax)),
          if (svc > 0) KvRow('Service', rupiah.format(svc)),
          KvRow('Total penjualan', rupiah.format(total)),
          if (refundTotal > 0)
            KvRow(
              'Refund',
              '-${rupiah.format(refundTotal)}',
              color: AppColors.danger,
            ),
          const Divider(height: 20),
          KvRow(
            'Penjualan bersih',
            rupiah.format(net),
            bold: true,
            color: AppColors.primary,
          ),
        ],
      ),
    );

    final metodeCard = SectionCard(
      title: 'Metode pembayaran',
      child: Column(
        children: [
          for (final e in methods)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(e.value * 100 / methodTotal).round()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        rupiah.format(e.value),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / methodTotal,
                      minHeight: 6,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primarySoft,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final topCard = SectionCard(
      title: 'Menu terlaris',
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${i + 1}.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          top[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${qty[top[i].key]}× • ${rupiah.format(top[i].value)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: top[i].value / maxRev,
                      minHeight: 6,
                      color: AppColors.rose,
                      backgroundColor: AppColors.roseSoft,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final trxCard = SectionCard(
      title: 'Transaksi (${paid.length})',
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Cari no. order / no. online / atas nama',
              isDense: true,
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 6),
          for (final o in shownTrx)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _detail(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    StatusPill(
                      _timeFmt.format(
                        DateTime.fromMillisecondsSinceEpoch(o.paidAt ?? 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.number,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${o.payMethod?.label ?? '-'}'
                            '${o.source.isOnline ? ' • ${o.source.label} ${o.externalNo ?? ''}' : ''}'
                            '${o.callLabel != null ? ' • ${o.callLabel}' : ''}'
                            '${o.status == OrderStatus.refunded ? ' • REFUND' : ''}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: o.status == OrderStatus.refunded
                                  ? AppColors.danger
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      rupiah.format(o.total),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: o.status == OrderStatus.refunded
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final logCard = SectionCard(
      title: 'Void, refund & diskon',
      child: Column(
        children: [
          for (final l in logs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusPill(l.action.label, tone: Tone.warning),
                      const Spacer(),
                      Text(
                        rupiah.format(l.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_timeFmt.format(DateTime.fromMillisecondsSinceEpoch(l.at))} • ${l.userName} • ${l.orderNumber}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '${l.detail.isEmpty ? '' : '${l.detail} • '}${l.reason}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final sources = bySource.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));
    final sourceTotal = max(1, sources.fold<int>(0, (s, e) => s + e.value.total));
    final sourceCard = SectionCard(
      title: 'Sumber pesanan',
      child: Column(
        children: [
          for (final e in sources)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.key.label} · ${e.value.n} order',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        rupiah.format(e.value.total),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value.total / sourceTotal,
                      minHeight: 6,
                      color: e.key.isOnline ? AppColors.sage : AppColors.ink,
                      backgroundColor: AppColors.sunken,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final left = <Widget>[
      if (_source == null && sources.length > 1) sourceCard,
      if (paid.isNotEmpty) rincian,
      if (methods.isNotEmpty) metodeCard,
      if (top.isNotEmpty) topCard,
    ];
    final right = <Widget>[
      if (paid.isNotEmpty) trxCard,
      if (logs.isNotEmpty) logCard,
    ];
    Widget stack(List<Widget> cards) => Column(
      children: [
        for (final c in cards)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
      ],
    );

    return Scaffold(
      appBar: RmsAppBar(
        title: const Text('Laporan'),
        pageActions: [
          PageAction(
            icon: Icons.download_rounded,
            label: 'Unduh laporan',
            shortLabel: 'Unduh',
            onPressed: () async {
              final kind = await showChoiceSheet<String>(
                context: context,
                title: 'Unduh laporan',
                subtitle: _dateFmt.format(_day),
                choices: const [
                  SheetChoice(
                    value: 'xlsx',
                    icon: Icons.table_chart_outlined,
                    label: 'Excel (.xlsx)',
                    subtitle: 'Semua data tanggal ini, bisa diolah lagi',
                  ),
                  SheetChoice(
                    value: 'pdf',
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF ringkasan',
                    subtitle: 'Ringkasan penjualan untuk dicetak/dibagikan',
                  ),
                  SheetChoice(
                    value: 'trx',
                    icon: Icons.receipt_long_outlined,
                    label: 'PDF daftar transaksi',
                    subtitle: 'Setiap transaksi beserta sumber pesanannya',
                  ),
                ],
              );
              if (kind != null) _download(kind);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DateBar(
                label: _dateFmt.format(_day),
                onPrev: () => _move(-1),
                onNext: _isToday ? null : () => _move(1),
                onPick: _pick,
                onToday: _isToday
                    ? null
                    : () => setState(() => _day = DateTime.now()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final src in <OrderSource?>[null, ...OrderSource.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            src == null
                                ? 'Semua sumber'
                                : '${src.label}${bySource[src] == null ? '' : ' · ${bySource[src]!.n}'}',
                          ),
                          selected: _source == src,
                          onSelected: (_) => setState(() => _source = src),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              WindowNotice(rangeStart: _day),
              AdaptiveGrid(children: tiles),
              const SizedBox(height: 12),
              if (paid.isEmpty && logs.isEmpty)
                const SectionCard(
                  title: 'Transaksi',
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada transaksi pada tanggal ini',
                  ),
                )
              else if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stack(left)),
                    const SizedBox(width: 12),
                    Expanded(child: stack(right)),
                  ],
                )
              else
                stack([...left, ...right]),
            ],
          );
        },
      ),
    );
  }
}
