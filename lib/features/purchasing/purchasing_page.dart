import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../approvals/approval_providers.dart';
import '../auth/auth_providers.dart';
import '../shifts/shift_providers.dart';
import 'po_pages.dart';
import 'purchasing_models.dart';
import 'purchasing_providers.dart';
import '../approvals/approvals_page.dart';
import '../approvals/pending_requests_card.dart';

class PurchasingPage extends ConsumerWidget {
  const PurchasingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDebt =
        ref.watch(appUserProvider).value?.can('supplier_payments.read') ??
        false;
    return DefaultTabController(
      length: showDebt ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembelian'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'PO'),
              const Tab(text: 'Supplier'),
              if (showDebt) const Tab(text: 'Hutang'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const PoTab(),
            const SuppliersTab(),
            if (showDebt) const PayablesTab(),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== supplier

class SuppliersTab extends ConsumerWidget {
  const SuppliersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(suppliersProvider).value ?? <Supplier>[];
    final bal = ref.watch(supplierBalanceProvider);
    final user = ref.watch(appUserProvider).value;
    final isOwner = user?.can('suppliers.create') ?? false;
    final showDebt = user?.can('supplier_payments.read') ?? false;
    final canRequest = user?.can('approvals.create') ?? false;

    Widget card(Supplier s) {
      final debt = bal[s.id] ?? 0;
      final sub = [s.phone, s.note].where((e) => e.isNotEmpty).join(' • ');
      final initial = s.name.trim().isEmpty
          ? '?'
          : s.name.trim()[0].toUpperCase();
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isOwner
              ? () => _edit(context, ref, s)
              : canRequest
              ? () => _request(context, ref, s)
              : null,
          onLongPress: isOwner ? () => _delete(context, ref, s) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    initial,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showDebt && debt > 0)
                  StatusPill(
                    'Hutang ${rupiah.format(debt)}',
                    tone: Tone.danger,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Supplier'),
            )
          : canRequest
          ? FloatingActionButton.extended(
              onPressed: () => _request(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Ajukan supplier'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const PendingRequestsCard(type: 'supplier'),
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Belum ada supplier',
            )
          else
            AdaptiveGrid(
              minTileWidth: 380,
              maxColumns: 3,
              children: [for (final s in list) card(s)],
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

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    Supplier? s,
  ) async {
    final r = await formDialog(
      context,
      s == null ? 'Ajukan supplier baru' : 'Ajukan perubahan: ${s.name}',
      ['Nama', 'Telepon', 'Catatan'],
      initial: [s?.name ?? '', s?.phone ?? '', s?.note ?? ''],
      okLabel: 'Ajukan',
      hint: 'Supplier aktif setelah disetujui.',
    );
    if (r == null || r[0].isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await submitSupplier(
        ref,
        action: s == null ? 'create' : 'update',
        supplierId: s?.id,
        name: r[0],
        phone: r[1],
        note: r[2],
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Diajukan untuk persetujuan'),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApprovalsPage()),
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }
}

// ===================================================================== hutang

class PayablesTab extends ConsumerWidget {
  const PayablesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider).value ?? <Supplier>[];
    final bal = ref.watch(supplierBalanceProvider);
    final shown = suppliers.where((s) => (bal[s.id] ?? 0) != 0).toList()
      ..sort((a, b) => (bal[b.id] ?? 0).compareTo(bal[a.id] ?? 0));
    final total = shown.fold<int>(0, (s, e) => s + (bal[e.id] ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [AppColors.ink, AppColors.inkSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total hutang supplier',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rupiah.format(total),
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${shown.length} supplier',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: .9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Tidak ada hutang',
          )
        else
          AdaptiveGrid(
            minTileWidth: 380,
            maxColumns: 3,
            children: [
              for (final s in shown)
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierLedgerPage(supplier: s),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            rupiah.format(bal[s.id] ?? 0),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sisa hutang',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rupiah.format(balance),
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: balance > 0 ? AppColors.danger : AppColors.success,
                  ),
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () =>
                        showPaymentDialog(context, ref, supplier, balance),
                    child: const Text('Bayar hutang'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Riwayat (${entries.length})',
            child: entries.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada transaksi',
                  )
                : Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: e.amount < 0
                                      ? const Color(0xFFD1FAE5)
                                      : AppColors.roseSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  e.amount < 0
                                      ? Icons.payments_outlined
                                      : Icons.inventory_2_outlined,
                                  size: 18,
                                  color: e.amount < 0
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF9F1239),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${fmt.format(DateTime.fromMillisecondsSinceEpoch(e.at))}'
                                      '${e.sub.isEmpty ? '' : ' • ${e.sub}'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${e.amount < 0 ? '−' : '+'}${rupiah.format(e.amount.abs())}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: e.amount < 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ],
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
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
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
                          'Sisa hutang',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          rupiah.format(balance),
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amount,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah dibayar (Rp)',
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 10),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.roseSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Melebihi sisa hutang',
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
