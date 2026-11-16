import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../orders/order_models.dart';
import 'printer_service.dart';
import 'printer_settings.dart';

enum _Job { receipt, kitchen }

enum _State { idle, busy, done, failed }

/// Popup setelah pembayaran (semua tipe outlet): ringkasan + tombol cetak struk pelanggan dan
/// struk dapur (semua item).
/// Tidak ada cetak otomatis; kasir memilih sendiri yang dicetak (bisa diulang).
Future<void> showPrintAfterPayDialog(
  BuildContext context, {
  required Order order,
  required PrinterSettings? settings,
  String? tableName,
  String? cashier,
  int change = 0,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PrintAfterPayDialog(
    title: 'Pembayaran berhasil',
    order: order,
    settings: settings,
    tableName: tableName,
    cashier: cashier,
    change: change,
  ),
);

/// Popup setelah Open Bill (outlet restoran): cetak struk dapur untuk item baru/tambahan.
/// [newItems] kosong = tidak ada yang perlu dikirim ke dapur (popup tidak ditampilkan).
Future<void> showPrintAfterSaveDialog(
  BuildContext context, {
  required Order order,
  required PrinterSettings? settings,
  required List<OrderItem> newItems,
  bool addition = false,
  String? tableName,
  String? cashier,
}) async {
  if (newItems.isEmpty) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PrintAfterPayDialog(
      title: addition ? 'Pesanan tambahan disimpan' : 'Order disimpan',
      order: order,
      settings: settings,
      tableName: tableName,
      cashier: cashier,
      showReceipt: false,
      kitchenItems: newItems,
      kitchenAddition: addition,
    ),
  );
}

class _PrintAfterPayDialog extends StatefulWidget {
  const _PrintAfterPayDialog({
    required this.title,
    required this.order,
    required this.settings,
    this.tableName,
    this.cashier,
    this.change = 0,
    this.showReceipt = true,
    this.kitchenItems,
    this.kitchenAddition = false,
  });

  final String title;
  final bool showReceipt;
  final List<OrderItem>? kitchenItems; // null = semua item order
  final bool kitchenAddition;
  final Order order;
  final PrinterSettings? settings;
  final String? tableName;
  final String? cashier;
  final int change;

  @override
  State<_PrintAfterPayDialog> createState() => _PrintAfterPayDialogState();
}

class _PrintAfterPayDialogState extends State<_PrintAfterPayDialog> {
  final _state = {_Job.receipt: _State.idle, _Job.kitchen: _State.idle};
  String? _error;

  bool get _busy => _state.values.contains(_State.busy);

  Future<void> _print(_Job job) async {
    final s = widget.settings;
    if (s == null) {
      setState(() => _error = 'Pengaturan printer belum dimuat. Coba lagi.');
      return;
    }
    setState(() {
      _state[job] = _State.busy;
      _error = null;
    });
    try {
      final f = job == _Job.receipt
          ? printOrderReceipt(
              settings: s,
              order: widget.order,
              tableName: widget.tableName,
              cashier: widget.cashier,
            )
          : printKitchenSlip(
              settings: s,
              order: widget.order,
              cashier: widget.cashier,
              tableName: widget.tableName,
              items: widget.kitchenItems,
              addition: widget.kitchenAddition,
            );
      await f.timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _state[job] = _State.done);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state[job] = _State.failed;
        _error = 'Gagal mencetak: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Widget _button(_Job job, IconData icon, String label) {
    final st = _state[job]!;
    final text = switch (st) {
      _State.busy => 'Mencetak…',
      _State.done => '$label (cetak lagi)',
      _ => label,
    };
    final leading = switch (st) {
      _State.busy => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      ),
      _State.done => const Icon(Icons.check_circle, color: AppColors.success),
      _State.failed => const Icon(Icons.error_outline, color: AppColors.danger),
      _State.idle => Icon(icon),
    };
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: _busy ? null : () => _print(job),
      icon: leading,
      label: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final queue = o.queueNo;
    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 32, color: AppColors.success),
      ),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                o.number,
                if (queue != null && queue.isNotEmpty) 'Antrean $queue',
                if (widget.tableName != null && widget.tableName!.isNotEmpty)
                  widget.tableName!,
                if (widget.showReceipt) 'Total ${rupiah.format(o.total)}',
                if (!widget.showReceipt)
                  '${(widget.kitchenItems ?? o.items).fold<int>(0, (n, i) => n + i.qty)} item '
                      '${widget.kitchenAddition ? 'tambahan' : 'ke dapur'}',
              ].join(' • '),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
            ),
            if (widget.change > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('Kembalian', style: GoogleFonts.inter(fontSize: 12.5)),
                    Text(
                      rupiah.format(widget.change),
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (widget.showReceipt) ...[
              _button(_Job.receipt, Icons.receipt_long_outlined, 'Cetak struk order'),
              const SizedBox(height: 10),
            ],
            _button(
              _Job.kitchen,
              Icons.soup_kitchen_outlined,
              widget.kitchenAddition ? 'Cetak struk dapur (tambahan)' : 'Cetak struk dapur',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Selesai'),
        ),
      ],
    );
  }
}
