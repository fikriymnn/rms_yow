import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/features/printing/printer_settings_page.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../finance/expense.dart';
import '../finance/expenses_tab.dart';
import '../finance/finance_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import 'shift.dart';
import 'shift_providers.dart';

typedef ShiftTotals = ({
  int cash,
  int other,
  int count,
  Map<String, int> byMethod,
  int refundCash,
  int refundOther,
});

ShiftTotals shiftTotals(Shift s, List<Order> orders) {
  var cash = 0, other = 0, count = 0, refundCash = 0, refundOther = 0;
  final by = <String, int>{};
  for (final o in orders) {
    final sold =
        o.shiftId == s.id &&
        (o.status == OrderStatus.paid || o.status == OrderStatus.refunded);
    if (sold) {
      count++;
      final m = (o.payMethod ?? PayMethod.other).name;
      by[m] = (by[m] ?? 0) + o.total;
      if (o.payMethod == PayMethod.cash) {
        cash += o.total;
      } else {
        other += o.total;
      }
    }
    // refund dicatat di shift tempat refund dilakukan
    if (o.status == OrderStatus.refunded && o.refundShiftId == s.id) {
      if (o.payMethod == PayMethod.cash) {
        refundCash += o.total;
      } else {
        refundOther += o.total;
      }
    }
  }
  return (
    cash: cash,
    other: other,
    count: count,
    byMethod: by,
    refundCash: refundCash,
    refundOther: refundOther,
  );
}

int shiftCashExpense(Shift s, List<Expense> ex) => ex
    .where((e) => e.fromDrawer && e.shiftId == s.id)
    .fold<int>(0, (a, e) => a + e.amount);

class ShiftPage extends ConsumerStatefulWidget {
  const ShiftPage({super.key});
  @override
  ConsumerState<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends ConsumerState<ShiftPage> {
  final _opening = TextEditingController();
  static final _fmt = DateFormat('d MMM HH:mm');

  String _t(int ms) => _fmt.format(DateTime.fromMillisecondsSinceEpoch(ms));

  @override
  void dispose() {
    _opening.dispose();
    super.dispose();
  }

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
    ShiftTotals t,
    int cashExpense,
  ) async {
    final c = TextEditingController();
    final counted = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final v = int.tryParse(c.text);
          final diff = v == null ? 0 : v - expected;
          return AlertDialog(
            title: const Text('Tutup shift'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Kas seharusnya',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          rupiah.format(expected),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: c,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Uang fisik di laci',
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  if (v != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: diff == 0
                            ? const Color(0xFFD1FAE5)
                            : diff < 0
                            ? AppColors.roseSoft
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            diff == 0 ? 'Pas' : (diff < 0 ? 'Kurang' : 'Lebih'),
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            rupiah.format(diff.abs()),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
            salesByMethod: t.byMethod,
            refundCash: t.refundCash,
            refundOther: t.refundOther,
            cashExpense: cashExpense,
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
              ((user?.can('shifts.manage_all') ?? false) ||
                  s.cashierId == user?.uid),
        )
        .take(30)
        .toList();
    final multipleOpen =
        shifts.where((s) => s.status == ShiftStatus.open).length > 1;

    final main = shift == null ? _openCard() : _activeCard(shift, orders);
    final historyCard = SectionCard(
      title: 'Riwayat shift',
      child: history.isEmpty
          ? const EmptyState(icon: Icons.history, title: 'Belum ada riwayat')
          : Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [for (final s in history) _historyTile(s, orders)],
              ),
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kas & Shift'),
        actions: [
          IconButton(
            tooltip: 'Printer & struk',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (multipleOpen)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.roseSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF9F1239),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ada lebih dari satu shift terbuka di outlet ini (kemungkinan '
                          'dibuka bersamaan saat offline). Tutup satu per satu, mulai dari yang tertua.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF9F1239),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: main),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: historyCard),
                  ],
                )
              else ...[
                main,
                const SizedBox(height: 16),
                historyCard,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _historyTile(Shift s, List<Order> orders) {
    // shift lama (belum punya snapshot per metode) dihitung dari order
    final ShiftTotals t = s.salesByMethod != null
        ? (
            cash: s.cashSales ?? 0,
            other: s.otherSales ?? 0,
            count: s.orderCount ?? 0,
            byMethod: s.salesByMethod!,
            refundCash: s.refundCash ?? 0,
            refundOther: s.refundOther ?? 0,
          )
        : shiftTotals(s, orders);
    final d = s.difference ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        title: Text(
          s.cashierName,
          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _t(s.openedAt),
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
        ),
        trailing: d == 0
            ? const StatusPill('Pas', tone: Tone.success)
            : d < 0
            ? StatusPill('Kurang ${rupiah.format(-d)}', tone: Tone.danger)
            : StatusPill('Lebih ${rupiah.format(d)}', tone: Tone.warning),
        children: [
          KvRow('Dibuka', _t(s.openedAt)),
          if (s.closedAt != null) KvRow('Ditutup', _t(s.closedAt!)),
          KvRow('Modal awal', rupiah.format(s.openingCash)),
          KvRow('Penjualan tunai', rupiah.format(t.cash)),
          KvRow('Penjualan non-tunai', rupiah.format(t.other)),
          ..._methodRows(t.byMethod),
          KvRow('Total penjualan', rupiah.format(t.cash + t.other), bold: true),
          if (t.refundCash + t.refundOther > 0)
            KvRow(
              'Refund',
              '-${rupiah.format(t.refundCash + t.refundOther)}',
              color: AppColors.danger,
            ),
          if ((s.cashExpense ?? 0) > 0)
            KvRow('Pengeluaran kas', '-${rupiah.format(s.cashExpense!)}'),
          KvRow('Jumlah order', '${t.count}'),
          const Divider(height: 20),
          KvRow('Kas seharusnya', rupiah.format(s.expectedCash ?? 0)),
          KvRow('Uang fisik', rupiah.format(s.closingCash ?? 0)),
          KvRow('Selisih', rupiah.format(d), bold: true),
        ],
      ),
    );
  }

  Widget _openCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_open_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada shift aktif',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Buka shift untuk mulai menerima pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _opening,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Modal awal laci (Rp)',
            prefixText: 'Rp ',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _open, child: const Text('Buka shift')),
      ],
    ),
  );

  Widget _activeCard(Shift s, List<Order> orders) {
    final me = ref.watch(appUserProvider).value;
    final canClose =
        (me?.can('shifts.manage_all') ?? false) || s.cashierId == me?.uid;
    final t = shiftTotals(s, orders);
    final out = shiftCashExpense(
      s,
      ref.watch(expensesProvider).value ?? <Expense>[],
    );
    final expected = s.openingCash + t.cash - t.refundCash - out;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const StatusPill('Shift aktif', tone: Tone.success),
              const Spacer(),
              Flexible(
                child: Text(
                  '${_t(s.openedAt)} • ${s.cashierName}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'Kas seharusnya',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rupiah.format(expected),
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KvRow('Modal awal', rupiah.format(s.openingCash)),
          KvRow('Penjualan tunai', rupiah.format(t.cash)),
          KvRow('Penjualan non-tunai', rupiah.format(t.other)),
          ..._methodRows(t.byMethod),
          if (t.refundCash + t.refundOther > 0)
            KvRow(
              'Refund',
              '-${rupiah.format(t.refundCash + t.refundOther)}',
              color: AppColors.danger,
            ),
          if (out > 0) KvRow('Pengeluaran kas', '-${rupiah.format(out)}'),
          KvRow('Jumlah order', '${t.count}'),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showExpenseDialog(context, ref, drawerOnly: true),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Catat pengeluaran kas'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: canClose ? () => _close(s, expected, t, out) : null,
            child: const Text('Tutup shift'),
          ),
          if (!canClose)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Hanya ${s.cashierName} (pembuka shift) atau manager yang dapat menutup shift ini.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _methodRows(Map<String, int> by) => [
    for (final m in PayMethod.values)
      if (m != PayMethod.cash && (by[m.name] ?? 0) > 0)
        KvRow(m.name.toUpperCase(), rupiah.format(by[m.name]!), indent: 16),
  ];
}
