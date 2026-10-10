import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/reason_dialog.dart';
import '../audit/audit_log.dart';
import '../audit/audit_providers.dart';
import '../auth/auth_providers.dart';
import '../shifts/shift_providers.dart';
import 'expense.dart';
import 'finance_providers.dart';

/// Dialog catat biaya. [drawerOnly] = khusus pengeluaran kas laci (dari tab Kas).
Future<void> showExpenseDialog(
  BuildContext context,
  WidgetRef ref, {
  bool drawerOnly = false,
}) async {
  final shift = ref.read(currentShiftProvider);
  final user = ref.read(appUserProvider).value;
  var category = kExpenseCategories.first;
  var date = DateTime.now();
  var fromDrawer = drawerOnly;
  final amount = TextEditingController();
  final note = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final canDrawer = shift != null && isToday;
        final amt = int.tryParse(amount.text) ?? 0;
        final valid = amt > 0 && (!fromDrawer || canDrawer);
        return AlertDialog(
          title: Text(drawerOnly ? 'Pengeluaran kas laci' : 'Catat biaya'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    for (final c in kExpenseCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setS(() => category = v ?? category),
                ),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
                  onChanged: (_) => setS(() {}),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                if (!drawerOnly) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal'),
                    subtitle: Text(DateFormat('d MMM yyyy').format(date)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setS(() {
                          date = d;
                          if (!DateUtils.isSameDay(d, DateTime.now())) {
                            fromDrawer = false;
                          }
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dibayar dari kas laci'),
                    subtitle: Text(
                      shift == null
                          ? 'Tidak ada shift aktif'
                          : 'Mengurangi kas shift berjalan',
                    ),
                    value: fromDrawer,
                    onChanged: canDrawer
                        ? (v) => setS(() => fromDrawer = v)
                        : null,
                  ),
                ],
                if (drawerOnly && shift == null)
                  Text(
                    'Buka shift dulu di tab Kas.',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: valid ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;

  final now = DateTime.now();
  final at = DateUtils.isSameDay(date, now)
      ? now.millisecondsSinceEpoch
      : DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch;
  await ref
      .read(expenseRepositoryProvider)
      .save(
        Expense(
          id: const Uuid().v4(),
          category: category,
          amount: int.parse(amount.text),
          at: at,
          note: note.text.trim(),
          fromDrawer: fromDrawer,
          shiftId: fromDrawer ? shift?.id : null,
          userName: user?.name ?? '',
        ),
      );
}

class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key});
  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  static final _dayFmt = DateFormat('d MMM');
  static final _monthFmt = DateFormat('MMM yyyy');

  void _move(int d) =>
      setState(() => _month = DateTime(_month.year, _month.month + d));

  Future<void> _delete(Expense e) async {
    final user = ref.read(appUserProvider).value;
    if (!(user?.isManager ?? false)) return;
    final reason = await askReason(context, 'Hapus biaya ${e.category}');
    if (reason == null) return;
    await ref.read(expenseRepositoryProvider).remove(e.id);
    await ref
        .read(auditRepositoryProvider)
        .record(
          AuditAction.expenseDelete,
          reason: reason,
          detail: '${e.category}${e.note.isEmpty ? '' : ' • ${e.note}'}',
          amount: e.amount,
        );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expensesProvider).value ?? <Expense>[];
    final start = _month.millisecondsSinceEpoch;
    final end = DateTime(_month.year, _month.month + 1).millisecondsSinceEpoch;
    final list = all.where((e) => e.at >= start && e.at < end).toList();
    final total = list.fold<int>(0, (s, e) => s + e.amount);
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final th = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Biaya'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _move(-1),
              ),
              Text(_monthFmt.format(_month), style: th.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrent ? null : () => _move(1),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total'),
                Text(
                  rupiah.format(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Belum ada biaya'))
                : ListView(
                    children: [
                      for (final e in list)
                        ListTile(
                          isThreeLine: e.note.isNotEmpty,
                          title: Text(
                            '${e.category} • ${rupiah.format(e.amount)}',
                          ),
                          subtitle: Text(
                            '${_dayFmt.format(DateTime.fromMillisecondsSinceEpoch(e.at))}'
                            '${e.fromDrawer ? ' • kas laci' : ''}'
                            '${e.userName.isEmpty ? '' : ' • ${e.userName}'}'
                            '${e.note.isEmpty ? '' : '\n${e.note}'}',
                          ),
                          onLongPress: () => _delete(e),
                        ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Tekan lama untuk menghapus (manager, alasan wajib). '
                          'Kategori "Pembelian bahan (sudah di Stok)" tidak masuk laba rugi '
                          'karena biayanya sudah dihitung lewat HPP.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
