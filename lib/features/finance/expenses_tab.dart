import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/reason_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
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
  final shift = await resolveCurrentShift(ref);
  final user = ref.read(appUserProvider).value;
  var category = kExpenseCategories.first;
  var date = DateTime.now();
  var fromDrawer = drawerOnly;
  final amount = TextEditingController();
  final note = TextEditingController();

  if (!context.mounted) return;
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
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (Rp)',
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Catatan'),
                  ),
                  if (!drawerOnly) ...[
                    const SizedBox(height: 4),
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
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.roseSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Buka shift dulu di tab Kas.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF9F1239),
                        ),
                      ),
                    ),
                ],
              ),
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

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal di bulan yang diinginkan',
    );
    if (d != null) setState(() => _month = DateTime(d.year, d.month));
  }

  Future<void> _delete(Expense e) async {
    final user = ref.read(appUserProvider).value;
    if (!(user?.can('expenses.manage_all') ?? false)) return;
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
    final isManager =
        ref.watch(appUserProvider).value?.can('expenses.manage_all') ?? false;
    final start = _month.millisecondsSinceEpoch;
    final end = DateTime(_month.year, _month.month + 1).millisecondsSinceEpoch;
    final list = all.where((e) => e.at >= start && e.at < end).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final total = list.fold<int>(0, (s, e) => s + e.amount);
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;

    final byCat = <String, int>{};
    for (final e in list) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final cats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final denom = total == 0 ? 1 : total;

    final summary = Column(
      children: [
        AdaptiveGrid(
          minTileWidth: 150,
          maxColumns: 2,
          children: [
            StatTile(
              icon: Icons.payments_outlined,
              label: 'Total biaya',
              value: rupiah.format(total),
              tone: Tone.danger,
            ),
            StatTile(
              icon: Icons.receipt_long_outlined,
              label: 'Jumlah catatan',
              value: '${list.length}',
            ),
          ],
        ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Per kategori',
            child: Column(
              children: [
                for (final e in cats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(e.value * 100 / denom).round()}%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rupiah.format(e.value),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.value / denom,
                            minHeight: 5,
                            color: AppColors.rose,
                            backgroundColor: AppColors.roseSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    Widget tile(Expense e) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: isManager ? () => _delete(e) : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, isManager ? 4 : 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.roseSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: Color(0xFF9F1239),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (e.fromDrawer) ...[
                          const SizedBox(width: 6),
                          const StatusPill('Kas laci', tone: Tone.info),
                        ],
                      ],
                    ),
                    Text(
                      '${_dayFmt.format(DateTime.fromMillisecondsSinceEpoch(e.at))}'
                      '${e.userName.isEmpty ? '' : ' • ${e.userName}'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    if (e.note.isNotEmpty)
                      Text(e.note, style: GoogleFonts.inter(fontSize: 12.5)),
                  ],
                ),
              ),
              Text(
                rupiah.format(e.amount),
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isManager)
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _delete(e),
                ),
            ],
          ),
        ),
      ),
    );

    final listView = list.isEmpty
        ? const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada biaya',
          )
        : Column(children: [for (final e in list) tile(e)]);

    final footnote = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Hapus biaya: manager, alasan wajib. Kategori "Pembelian bahan (sudah di Stok)" '
        'tidak masuk laba rugi karena biayanya sudah dihitung lewat HPP.',
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Biaya'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              DateBar(
                label: _monthFmt.format(_month),
                onPrev: () => _move(-1),
                onNext: isCurrent ? null : () => _move(1),
                onPick: _pickMonth,
              ),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: [listView, footnote])),
                    const SizedBox(width: 16),
                    SizedBox(width: 340, child: summary),
                  ],
                )
              else ...[
                summary,
                const SizedBox(height: 12),
                listView,
                footnote,
              ],
            ],
          );
        },
      ),
    );
  }
}
