import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../shifts/shift_providers.dart';
import 'purchasing_models.dart';
import 'purchasing_providers.dart';

String poStatusText(PurchaseOrder po, Map<String, double>? received) =>
    (po.status == PoStatus.ordered && received != null && received.isNotEmpty)
    ? 'Diterima sebagian'
    : po.status.label;

class PoTab extends ConsumerWidget {
  const PoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(purchaseOrdersProvider).value ?? <PurchaseOrder>[];
    final received = ref.watch(receivedByPoProvider);
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PoEditorPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('PO baru'),
      ),
      body: pos.isEmpty
          ? const Center(child: Text('Belum ada PO'))
          : ListView(
              children: [
                for (final po in pos)
                  ListTile(
                    title: Text('${po.number} • ${po.supplierName}'),
                    subtitle: Text(
                      '${fmt.format(DateTime.fromMillisecondsSinceEpoch(po.createdAt))} • ${rupiah.format(po.total)}',
                    ),
                    trailing: Chip(
                      label: Text(poStatusText(po, received[po.id])),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PoDetailPage(poId: po.id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class PoEditorPage extends ConsumerStatefulWidget {
  const PoEditorPage({super.key, this.po});
  final PurchaseOrder? po;
  @override
  ConsumerState<PoEditorPage> createState() => _PoEditorPageState();
}

class _PoEditorPageState extends ConsumerState<PoEditorPage> {
  late final String _id = widget.po?.id ?? const Uuid().v4();
  late final String _number = widget.po?.number ?? newNumber('PO');
  late String? _supplierId = widget.po?.supplierId;
  late final List<PoLine> _lines = [...?widget.po?.lines];
  late final TextEditingController _note = TextEditingController(
    text: widget.po?.note,
  );

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _addLine() async {
    final ings = (ref.read(ingredientsProvider).value ?? <Ingredient>[])
        .where((i) => !_lines.any((l) => l.ingredientId == i.id))
        .toList();
    if (ings.isEmpty) {
      _toast('Tidak ada bahan lain. Tambahkan di Stok → Bahan.');
      return;
    }
    final ing = await showDialog<Ingredient>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih bahan'),
        children: [
          for (final i in ings)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(i.name),
            ),
        ],
      ),
    );
    if (ing == null || !mounted) return;
    final unit = ing.buyUnit.isEmpty ? ing.unit : ing.buyUnit;
    final factor = ing.buyUnit.isEmpty ? 1.0 : ing.buyFactor;
    final avg = ref.read(avgCostProvider)[ing.id];
    final r = await formDialog(
      context,
      ing.name,
      ['Jumlah ($unit)', 'Harga per $unit (Rp)'],
      initial: ['', avg == null ? '' : '${(avg * factor).round()}'],
      numeric: {0, 1},
    );
    if (r == null) return;
    final q = parseNum(r[0]), p = parseNum(r[1]);
    if (q == null || q <= 0 || p == null || p < 0) {
      _toast('Jumlah dan harga harus diisi');
      return;
    }
    setState(
      () => _lines.add(
        PoLine(
          ingredientId: ing.id,
          name: ing.name,
          unitLabel: unit,
          factor: factor,
          qty: q,
          unitPrice: p.round(),
        ),
      ),
    );
  }

  Future<void> _editLine(int i) async {
    final l = _lines[i];
    final r = await formDialog(
      context,
      l.name,
      ['Jumlah (${l.unitLabel})', 'Harga per ${l.unitLabel} (Rp)'],
      initial: [qtyPlain(l.qty), '${l.unitPrice}'],
      numeric: {0, 1},
    );
    if (r == null) return;
    final q = parseNum(r[0]), p = parseNum(r[1]);
    if (q == null || q <= 0 || p == null || p < 0) return;
    setState(() => _lines[i] = l.copyWith(qty: q, unitPrice: p.round()));
  }

  Future<void> _save({required bool order}) async {
    final suppliers = ref.read(suppliersProvider).value ?? <Supplier>[];
    final sup = suppliers.where((s) => s.id == _supplierId).firstOrNull;
    if (sup == null || _lines.isEmpty) {
      _toast('Pilih supplier dan tambahkan minimal satu bahan');
      return;
    }
    await ref
        .read(poRepositoryProvider)
        .save(
          PurchaseOrder(
            id: _id,
            number: _number,
            supplierId: sup.id,
            supplierName: sup.name,
            createdAt:
                widget.po?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
            status: order ? PoStatus.ordered : PoStatus.draft,
            lines: _lines,
            note: _note.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider).value ?? <Supplier>[];
    final total = _lines.fold<int>(0, (s, l) => s + l.total);

    return Scaffold(
      appBar: AppBar(title: Text(widget.po == null ? 'PO baru' : _number)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (suppliers.isEmpty)
            const Text('Tambahkan supplier dulu di tab Supplier.')
          else
            DropdownButtonFormField<String>(
              initialValue: _supplierId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Supplier'),
              items: [
                for (final s in suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
          const SizedBox(height: 16),
          Text('Item', style: Theme.of(context).textTheme.titleMedium),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Belum ada item'),
            ),
          for (var i = 0; i < _lines.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_lines[i].name),
              subtitle: Text(
                '${qtyText(_lines[i].qty)} ${_lines[i].unitLabel} × ${rupiah.format(_lines[i].unitPrice)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rupiah.format(_lines[i].total)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _lines.removeAt(i)),
                  ),
                ],
              ),
              onTap: () => _editLine(i),
            ),
          TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text('Tambah bahan'),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Catatan'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total PO'),
              Text(
                rupiah.format(total),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _save(order: false),
                  child: const Text('Simpan draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _save(order: true),
                  child: const Text('Pesan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PoDetailPage extends ConsumerWidget {
  const PoDetailPage({super.key, required this.poId});
  final String poId;

  Future<bool> _confirm(BuildContext c, String title) async =>
      await showDialog<bool>(
        context: c,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final po = (ref.watch(purchaseOrdersProvider).value ?? <PurchaseOrder>[])
        .where((p) => p.id == poId)
        .firstOrNull;
    if (po == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final fmt = DateFormat('d MMM yyyy HH:mm');
    final received =
        ref.watch(receivedByPoProvider)[po.id] ?? <String, double>{};
    final receipts = (ref.watch(receiptsProvider).value ?? <GoodsReceipt>[])
        .where((r) => r.poId == po.id)
        .toList();
    final repo = ref.read(poRepositoryProvider);

    Widget kv(String k, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(po.number)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          kv('Supplier', po.supplierName),
          kv('Status', poStatusText(po, received)),
          kv(
            'Tanggal',
            fmt.format(DateTime.fromMillisecondsSinceEpoch(po.createdAt)),
          ),
          kv('Total PO', rupiah.format(po.total), bold: true),
          if (po.note.isNotEmpty) Text('Catatan: ${po.note}'),
          const Divider(height: 24),
          Text('Item', style: Theme.of(context).textTheme.titleMedium),
          for (final l in po.lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.name),
              subtitle: Text(
                '${qtyText(l.qty)} ${l.unitLabel} × ${rupiah.format(l.unitPrice)}',
              ),
              trailing: Text(
                'Diterima ${qtyText(received[l.ingredientId] ?? 0)}/${qtyText(l.qty)}',
              ),
            ),
          if (receipts.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Penerimaan', style: Theme.of(context).textTheme.titleMedium),
            for (final r in receipts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${r.number} • ${rupiah.format(r.total)}'),
                subtitle: Text(
                  '${fmt.format(DateTime.fromMillisecondsSinceEpoch(r.at))}'
                  '${r.invoiceNo.isEmpty ? '' : ' • Faktur ${r.invoiceNo}'}',
                ),
              ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (po.status == PoStatus.draft) ...[
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PoEditorPage(po: po)),
                  ),
                  child: const Text('Edit'),
                ),
                FilledButton(
                  onPressed: () =>
                      repo.save(po.copyWith(status: PoStatus.ordered)),
                  child: const Text('Pesan'),
                ),
              ],
              if (po.status == PoStatus.ordered) ...[
                FilledButton(
                  onPressed: () =>
                      showReceiveDialog(context, ref, po, received),
                  child: const Text('Terima barang'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    if (await _confirm(
                      context,
                      'Tutup PO ini (sisa tidak dikirim)?',
                    )) {
                      await repo.save(po.copyWith(status: PoStatus.closed));
                    }
                  },
                  child: const Text('Tutup PO'),
                ),
              ],
              if ((po.status == PoStatus.draft ||
                      po.status == PoStatus.ordered) &&
                  receipts.isEmpty)
                TextButton(
                  onPressed: () async {
                    if (await _confirm(context, 'Batalkan PO ini?')) {
                      await repo.save(po.copyWith(status: PoStatus.cancelled));
                    }
                  },
                  child: const Text('Batalkan'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showReceiveDialog(
  BuildContext context,
  WidgetRef ref,
  PurchaseOrder po,
  Map<String, double> before,
) async {
  final user = ref.read(appUserProvider).value;
  final shift = await resolveCurrentShift(ref);
  final canDrawer = shift != null && (user?.canPay ?? false);
  final qty = [
    for (final l in po.lines)
      TextEditingController(
        text: qtyPlain(math.max(0, l.qty - (before[l.ingredientId] ?? 0))),
      ),
  ];
  final price = [
    for (final l in po.lines) TextEditingController(text: '${l.unitPrice}'),
  ];
  final invoice = TextEditingController();
  final paid = TextEditingController(text: '0');
  var fromDrawer = false;

  int lineTotal(int i) =>
      ((parseNum(qty[i].text) ?? 0) * (int.tryParse(price[i].text) ?? 0))
          .round();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final total = [
          for (var i = 0; i < po.lines.length; i++) lineTotal(i),
        ].fold<int>(0, (a, b) => a + b);
        final paidNow = int.tryParse(paid.text) ?? 0;
        final drawerOn = fromDrawer && paidNow > 0;
        final valid =
            total > 0 &&
            paidNow >= 0 &&
            paidNow <= total &&
            (!drawerOn || canDrawer);
        return AlertDialog(
          title: const Text('Terima barang'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < po.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${po.lines[i].name} (${po.lines[i].unitLabel})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qty[i],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Diterima',
                                ),
                                onChanged: (_) => setS(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: price[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Harga/satuan',
                                ),
                                onChanged: (_) => setS(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                TextField(
                  controller: invoice,
                  decoration: const InputDecoration(
                    labelText: 'No. faktur / nota (opsional)',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Total: ${rupiah.format(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextField(
                  controller: paid,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dibayar sekarang (Rp)',
                  ),
                  onChanged: (_) => setS(() {}),
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
                  onChanged: (canDrawer && paidNow > 0)
                      ? (v) => setS(() => fromDrawer = v)
                      : null,
                ),
                if (paidNow > total)
                  Text(
                    'Pembayaran melebihi total',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  )
                else if (total > paidNow)
                  Text(
                    'Sisa menjadi hutang: ${rupiah.format(total - paidNow)}',
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
              child: const Text('Terima'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;

  final received = <PoLine>[];
  for (var i = 0; i < po.lines.length; i++) {
    final q = parseNum(qty[i].text) ?? 0;
    if (q <= 0) continue;
    received.add(
      po.lines[i].copyWith(
        qty: q,
        unitPrice: int.tryParse(price[i].text) ?? po.lines[i].unitPrice,
      ),
    );
  }
  if (received.isEmpty) return;
  final paidNow = int.tryParse(paid.text) ?? 0;
  await receiveGoods(
    ref,
    po: po,
    received: received,
    receivedBefore: before,
    invoiceNo: invoice.text.trim(),
    paidNow: paidNow,
    fromDrawer: fromDrawer && paidNow > 0,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barang diterima, stok diperbarui')),
    );
  }
}
