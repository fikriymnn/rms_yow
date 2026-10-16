import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../auth/auth_providers.dart';
import '../shifts/shift_providers.dart';
import 'po_pages.dart';
import 'purchasing_models.dart';
import 'purchasing_providers.dart';

class PurchasingPage extends StatelessWidget {
  const PurchasingPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Pembelian'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'PO'),
            Tab(text: 'Supplier'),
            Tab(text: 'Hutang'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [PoTab(), SuppliersTab(), PayablesTab()],
      ),
    ),
  );
}

class SuppliersTab extends ConsumerWidget {
  const SuppliersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(suppliersProvider).value ?? <Supplier>[];
    final bal = ref.watch(supplierBalanceProvider);
    final isOwner = ref.watch(appUserProvider).value?.role == AppRole.owner;
    return Scaffold(
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Supplier'),
            )
          : null,
      body: list.isEmpty
          ? const Center(child: Text('Belum ada supplier'))
          : ListView(
              children: [
                for (final s in list)
                  ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      [s.phone, s.note].where((e) => e.isNotEmpty).join(' • '),
                    ),
                    trailing: (bal[s.id] ?? 0) > 0
                        ? Text(
                            'Hutang ${rupiah.format(bal[s.id])}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        : null,
                    onTap: isOwner ? () => _edit(context, ref, s) : null,
                    onLongPress: isOwner
                        ? () => _delete(context, ref, s)
                        : null,
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Supplier? s) async {
    final r = await formDialog(
      context,
      s == null ? 'Supplier baru' : 'Edit supplier',
      ['Nama', 'Telepon', 'Catatan'],
      initial: [s?.name ?? '', s?.phone ?? '', s?.note ?? ''],
    );
    if (r == null || r[0].isEmpty) return;
    await ref
        .read(supplierRepositoryProvider)
        .save(
          Supplier(
            id: s?.id ?? const Uuid().v4(),
            name: r[0],
            phone: r[1],
            note: r[2],
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Supplier s) async {
    final used =
        (ref.read(purchaseOrdersProvider).value ?? <PurchaseOrder>[]).any(
          (p) => p.supplierId == s.id,
        ) ||
        (ref.read(receiptsProvider).value ?? <GoodsReceipt>[]).any(
          (p) => p.supplierId == s.id,
        ) ||
        (ref.read(supplierPaymentsProvider).value ?? <SupplierPayment>[]).any(
          (p) => p.supplierId == s.id,
        );
    if (used) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Supplier sudah dipakai (PO/hutang), tidak bisa dihapus',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${s.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(supplierRepositoryProvider).remove(s.id);
  }
}

class PayablesTab extends ConsumerWidget {
  const PayablesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider).value ?? <Supplier>[];
    final bal = ref.watch(supplierBalanceProvider);
    final shown = suppliers.where((s) => (bal[s.id] ?? 0) != 0).toList()
      ..sort((a, b) => (bal[b.id] ?? 0).compareTo(bal[a.id] ?? 0));
    final total = shown.fold<int>(0, (s, e) => s + (bal[e.id] ?? 0));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total hutang'),
              Text(
                rupiah.format(total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('Tidak ada hutang'))
              : ListView(
                  children: [
                    for (final s in shown)
                      ListTile(
                        title: Text(s.name),
                        trailing: Text(
                          rupiah.format(bal[s.id] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierLedgerPage(supplier: s),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class SupplierLedgerPage extends ConsumerWidget {
  const SupplierLedgerPage({super.key, required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM yyyy HH:mm');
    final receipts = (ref.watch(receiptsProvider).value ?? <GoodsReceipt>[])
        .where((r) => r.supplierId == supplier.id);
    final payments =
        (ref.watch(supplierPaymentsProvider).value ?? <SupplierPayment>[])
            .where((p) => p.supplierId == supplier.id);
    final balance = ref.watch(supplierBalanceProvider)[supplier.id] ?? 0;

    final entries = <({int at, String title, String sub, int amount})>[
      for (final r in receipts)
        (
          at: r.at,
          title: 'Penerimaan ${r.number}',
          sub: r.invoiceNo.isEmpty ? '' : 'Faktur ${r.invoiceNo}',
          amount: r.total,
        ),
      for (final p in payments)
        (
          at: p.at,
          title: 'Pembayaran${p.fromDrawer ? ' (kas laci)' : ''}',
          sub: p.note,
          amount: -p.amount,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return Scaffold(
      appBar: AppBar(title: Text(supplier.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sisa hutang'),
                Text(
                  rupiah.format(balance),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          if (balance > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      showPaymentDialog(context, ref, supplier, balance),
                  child: const Text('Bayar hutang'),
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                for (final e in entries)
                  ListTile(
                    dense: true,
                    title: Text(e.title),
                    subtitle: Text(
                      '${fmt.format(DateTime.fromMillisecondsSinceEpoch(e.at))}'
                      '${e.sub.isEmpty ? '' : ' • ${e.sub}'}',
                    ),
                    trailing: Text(
                      '${e.amount < 0 ? '-' : '+'}${rupiah.format(e.amount.abs())}',
                      style: TextStyle(
                        color: e.amount < 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
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

Future<void> showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  Supplier s,
  int balance,
) async {
  final user = ref.read(appUserProvider).value;
  final shift = await resolveCurrentShift(ref);
  final canDrawer = shift != null && (user?.canPay ?? false);
  final amount = TextEditingController(text: '$balance');
  final note = TextEditingController();
  var fromDrawer = false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final amt = int.tryParse(amount.text) ?? 0;
        final valid = amt > 0 && amt <= balance && (!fromDrawer || canDrawer);
        return AlertDialog(
          title: Text('Bayar ${s.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sisa hutang: ${rupiah.format(balance)}'),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah dibayar (Rp)',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dibayar dari kas laci'),
                  subtitle: Text(
                    canDrawer
                        ? 'Mengurangi kas shift berjalan'
                        : 'Butuh shift aktif milik Anda',
                  ),
                  value: fromDrawer,
                  onChanged: canDrawer
                      ? (v) => setS(() => fromDrawer = v)
                      : null,
                ),
                if (amt > balance)
                  Text(
                    'Melebihi sisa hutang',
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
              child: const Text('Bayar'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  await recordSupplierPayment(
    ref,
    supplierId: s.id,
    supplierName: s.name,
    amount: int.parse(amount.text),
    note: note.text.trim(),
    fromDrawer: fromDrawer,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pembayaran dicatat')));
  }
}
