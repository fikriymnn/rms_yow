import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
import '../approvals/approval_providers.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../shifts/shift_providers.dart';
import 'purchasing_models.dart';
import 'purchasing_providers.dart';
import '../approvals/pending_requests_card.dart';

String poStatusText(PurchaseOrder po, Map<String, double>? received) =>
    (po.status == PoStatus.ordered && received != null && received.isNotEmpty)
    ? 'Diterima sebagian'
    : po.status.label;

Tone poTone(PurchaseOrder po, Map<String, double>? received) =>
    switch (po.status) {
      PoStatus.draft => Tone.neutral,
      PoStatus.pending => Tone.warning,
      PoStatus.ordered =>
        (received != null && received.isNotEmpty) ? Tone.warning : Tone.info,
      PoStatus.closed => Tone.success,
      PoStatus.cancelled => Tone.neutral,
      PoStatus.rejected => Tone.danger,
    };

/// Rata-rata persentase penerimaan per baris (0..1).
double poReceivedFraction(PurchaseOrder po, Map<String, double> rec) {
  if (po.lines.isEmpty) return 0;
  var sum = 0.0;
  for (final l in po.lines) {
    if (l.qty > 0) sum += math.min(1.0, (rec[l.ingredientId] ?? 0) / l.qty);
  }
  return sum / po.lines.length;
}

// ===================================================================== daftar PO

class PoTab extends ConsumerStatefulWidget {
  const PoTab({super.key});
  @override
  ConsumerState<PoTab> createState() => _PoTabState();
}

class _PoTabState extends ConsumerState<PoTab> {
  PoStatus? _filter;
  String? _selected;
  static final _fmt = DateFormat('d MMM yyyy');

  void _open(PurchaseOrder po, bool wide) {
    if (wide) {
      setState(() => _selected = po.id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoDetailPage(poId: po.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(purchaseOrdersProvider).value ?? <PurchaseOrder>[];
    final received = ref.watch(receivedByPoProvider);
    final pos = _filter == null
        ? all
        : all.where((p) => p.status == _filter).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final master = Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PoEditorPage()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('PO baru'),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  children: [
                    for (final s in <PoStatus?>[null, ...PoStatus.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s?.label ?? 'Semua'),
                          selected: _filter == s,
                          onSelected: (_) => setState(() => _filter = s),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: PendingRequestsCard(type: 'purchase_order', maxItems: 3),
              ),
              Expanded(
                child: pos.isEmpty
                    ? EmptyState(
                        icon: Icons.shopping_cart_outlined,
                        title: all.isEmpty
                            ? 'Belum ada PO'
                            : 'Tidak ada PO pada filter ini',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        itemCount: pos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final po = pos[i];
                          final rec = received[po.id];
                          final selected = wide && po.id == _selected;
                          return Material(
                            color: selected
                                ? AppColors.primarySoft
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _open(po, wide),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            po.number,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        StatusPill(
                                          poStatusText(po, rec),
                                          tone: poTone(po, rec),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      po.supplierName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_fmt.format(DateTime.fromMillisecondsSinceEpoch(po.createdAt))} • ${po.lines.length} item',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          rupiah.format(po.total),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (po.status == PoStatus.ordered &&
                                        rec != null &&
                                        rec.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: poReceivedFraction(po, rec),
                                          minHeight: 5,
                                          color: AppColors.warning,
                                          backgroundColor: const Color(
                                            0xFFFEF3C7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
        if (!wide) return master;
        return Row(
          children: [
            SizedBox(width: 420, child: master),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selected == null
                  ? const EmptyState(
                      icon: Icons.touch_app_outlined,
                      title: 'Pilih PO',
                      message: 'Rinciannya tampil di sini',
                    )
                  : PoDetailView(key: ValueKey(_selected), poId: _selected!),
            ),
          ],
        );
      },
    );
  }
}

// ===================================================================== editor PO

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

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

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

  Future<bool> _save({required bool order, bool pop = true}) async {
    final me = ref.read(appUserProvider).value;
    if (me == null) return false;
    final suppliers = ref.read(suppliersProvider).value ?? <Supplier>[];
    final sup = suppliers.where((s) => s.id == _supplierId).firstOrNull;
    if (sup == null || _lines.isEmpty) {
      _toast('Pilih supplier dan tambahkan minimal satu bahan');
      return false;
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
            createdBy: (widget.po?.createdBy.isNotEmpty ?? false)
                ? widget.po!.createdBy
                : me.uid,
            createdByName: (widget.po?.createdBy.isNotEmpty ?? false)
                ? widget.po!.createdByName
                : me.name,
          ),
        );
    if (pop && mounted) Navigator.pop(context);
    return true;
  }

  Future<void> _submit() async {
    if (!await _save(order: false, pop: false)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await submitPurchaseOrder(ref, _id);
      messenger.showSnackBar(
        const SnackBar(content: Text('PO diajukan untuk persetujuan')),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  String? _chainNote(AppUser? u) {
    if (u == null || u.can('purchase_orders.direct_order')) return null;
    return u.can('approvals.approve_l1')
        ? 'Pengajuan diteruskan langsung ke owner.'
        : 'Pengajuan diteruskan ke manager atau head chef, lalu ke owner.';
  }

  Widget _lineTile(int i) {
    final l = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editLine(i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${qtyText(l.qty)} ${l.unitLabel} × ${rupiah.format(l.unitPrice)}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                rupiah.format(l.total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _lines.removeAt(i)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary({
    required bool isOwner,
    required int total,
    required bool card,
  }) {
    final chain = _chainNote(ref.watch(appUserProvider).value);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Total PO',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const Spacer(),
            Text(
              rupiah.format(total),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (chain != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  chain,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _save(order: false),
                child: const Text('Simpan draft'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => isOwner ? _save(order: true) : _submit(),
                child: Text(isOwner ? 'Pesan' : 'Ajukan'),
              ),
            ),
          ],
        ),
      ],
    );
    if (card) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(top: false, child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        ref.watch(appUserProvider).value?.can('purchase_orders.direct_order') ??
        false;
    final suppliers = ref.watch(suppliersProvider).value ?? <Supplier>[];
    final total = _lines.fold<int>(0, (s, l) => s + l.total);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final supplierCard = SectionCard(
      title: 'Supplier',
      child: suppliers.isEmpty
          ? Text(
              'Tambahkan supplier dulu di tab Supplier.',
              style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.muted),
            )
          : DropdownButtonFormField<String>(
              initialValue: _supplierId,
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Pilih supplier'),
              items: [
                for (final s in suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
    );

    final itemsCard = SectionCard(
      title: 'Item (${_lines.length})',
      trailing: TextButton.icon(
        onPressed: _addLine,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Tambah bahan'),
      ),
      child: _lines.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Belum ada item',
              message: 'Ketuk "Tambah bahan"',
            )
          : Column(
              children: [for (var i = 0; i < _lines.length; i++) _lineTile(i)],
            ),
    );

    final noteCard = SectionCard(
      title: 'Catatan',
      child: TextField(
        controller: _note,
        maxLines: 2,
        decoration: const InputDecoration(hintText: 'Opsional'),
      ),
    );

    final form = ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, wide ? 16 : 24),
      children: [
        supplierCard,
        const SizedBox(height: 12),
        itemsCard,
        const SizedBox(height: 12),
        noteCard,
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.po == null ? 'PO baru' : _number)),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                SizedBox(
                  width: 380,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: _summary(isOwner: isOwner, total: total, card: true),
                  ),
                ),
              ],
            )
          : form,
      bottomNavigationBar: wide
          ? null
          : _summary(isOwner: isOwner, total: total, card: false),
    );
  }
}

// ===================================================================== detail PO

/// Halaman penuh (HP). Di layar lebar, PoDetailView dipakai langsung di panel kanan.
class PoDetailPage extends StatelessWidget {
  const PoDetailPage({super.key, required this.poId});
  final String poId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail PO')),
    body: PoDetailView(poId: poId),
  );
}

class _PoSteps extends StatelessWidget {
  const _PoSteps(this.po);
  final PurchaseOrder po;

  @override
  Widget build(BuildContext context) {
    if (po.status == PoStatus.rejected || po.status == PoStatus.cancelled) {
      return const SizedBox.shrink();
    }
    const labels = ['Draft', 'Diajukan', 'Dipesan', 'Selesai'];
    final current = switch (po.status) {
      PoStatus.draft => 0,
      PoStatus.pending => 1,
      PoStatus.ordered => 2,
      _ => 3,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Container(
                  height: 2,
                  color: i <= current ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.primary : AppColors.surface,
                  border: Border.all(
                    color: i <= current ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                ),
                child: i < current
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : i == current
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                  color: i <= current ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class PoDetailView extends ConsumerWidget {
  const PoDetailView({super.key, required this.poId});
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

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrder po,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await submitPurchaseOrder(ref, po.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('PO diajukan untuk persetujuan')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final isOwner = user?.can('purchase_orders.direct_order') ?? false;
    final canReceive = user?.can('goods_receipts.create') ?? false;
    final po = (ref.watch(purchaseOrdersProvider).value ?? <PurchaseOrder>[])
        .where((p) => p.id == poId)
        .firstOrNull;
    if (po == null) return const Center(child: CircularProgressIndicator());

    final fmt = DateFormat('d MMM yyyy HH:mm');
    final received =
        ref.watch(receivedByPoProvider)[po.id] ?? <String, double>{};
    final receipts = (ref.watch(receiptsProvider).value ?? <GoodsReceipt>[])
        .where((r) => r.poId == po.id)
        .toList();
    final repo = ref.read(poRepositoryProvider);
    final showProgress =
        po.status == PoStatus.ordered || po.status == PoStatus.closed;

    final canCancel =
        (po.status == PoStatus.draft || po.status == PoStatus.ordered) &&
        receipts.isEmpty;
    final actions = <Widget>[
      if (canCancel)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () async {
            if (await _confirm(context, 'Batalkan PO ini?')) {
              await repo.save(po.copyWith(status: PoStatus.cancelled));
            }
          },
          child: const Text('Batalkan'),
        ),
      if (po.status == PoStatus.draft) ...[
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PoEditorPage(po: po)),
          ),
          child: const Text('Edit'),
        ),
        if (isOwner)
          FilledButton(
            onPressed: () => repo.save(po.copyWith(status: PoStatus.ordered)),
            child: const Text('Pesan'),
          )
        else
          FilledButton(
            onPressed: () => _submit(context, ref, po),
            child: const Text('Ajukan'),
          ),
      ],
      if (po.status == PoStatus.ordered) ...[
        OutlinedButton(
          onPressed: () async {
            if (await _confirm(context, 'Tutup PO ini (sisa tidak dikirim)?')) {
              await repo.save(po.copyWith(status: PoStatus.closed));
            }
          },
          child: const Text('Tutup PO'),
        ),
        if (canReceive)
          FilledButton(
            onPressed: () => showReceiveDialog(context, ref, po, received),
            child: const Text('Terima barang'),
          ),
      ],
    ];

    Widget banner(IconData icon, String text, Color bg, Color fg) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: fg),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (po.status == PoStatus.pending)
                banner(
                  Icons.hourglass_top,
                  'Menunggu persetujuan. Pantau di tab Persetujuan.',
                  const Color(0xFFFEF3C7),
                  const Color(0xFF92400E),
                ),
              if (po.status == PoStatus.rejected)
                banner(
                  Icons.cancel_outlined,
                  'Ditolak. Alasannya ada di Persetujuan → Pengajuan saya. Buat PO baru bila perlu.',
                  AppColors.roseSoft,
                  const Color(0xFF9F1239),
                ),
              if (po.status == PoStatus.cancelled)
                banner(
                  Icons.block,
                  'PO ini dibatalkan.',
                  const Color(0xFFF3F4F6),
                  AppColors.muted,
                ),
              Container(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                po.number,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                po.supplierName,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          poStatusText(po, received),
                          tone: poTone(po, received),
                        ),
                      ],
                    ),
                    if (po.status != PoStatus.rejected &&
                        po.status != PoStatus.cancelled) ...[
                      const SizedBox(height: 16),
                      _PoSteps(po),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    KvRow(
                      'Tanggal',
                      fmt.format(
                        DateTime.fromMillisecondsSinceEpoch(po.createdAt),
                      ),
                    ),
                    if (po.createdByName.isNotEmpty)
                      KvRow('Dibuat oleh', po.createdByName),
                    KvRow(
                      'Total PO',
                      rupiah.format(po.total),
                      bold: true,
                      color: AppColors.primary,
                    ),
                    if (po.note.isNotEmpty) KvRow('Catatan', po.note),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Item (${po.lines.length})',
                child: Column(
                  children: [
                    for (final l in po.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${qtyText(l.qty)} ${l.unitLabel} × ${rupiah.format(l.unitPrice)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      rupiah.format(l.total),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (showProgress)
                                      Text(
                                        'Diterima ${qtyText(received[l.ingredientId] ?? 0)}/${qtyText(l.qty)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (showProgress && l.qty > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: math.min(
                                    1.0,
                                    (received[l.ingredientId] ?? 0) / l.qty,
                                  ),
                                  minHeight: 5,
                                  color: AppColors.success,
                                  backgroundColor: const Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (receipts.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Penerimaan (${receipts.length})',
                  child: Column(
                    children: [
                      for (final r in receipts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.number,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${fmt.format(DateTime.fromMillisecondsSinceEpoch(r.at))}'
                                      '${r.invoiceNo.isEmpty ? '' : ' • Faktur ${r.invoiceNo}'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                rupiah.format(r.total),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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
          ),
        ),
        if (actions.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ),
          ),
      ],
    );
  }
}

// ===================================================================== terima barang

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
  final canPay = user?.can('supplier_payments.create') ?? false;

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
            width: 460,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < po.lines.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${po.lines[i].name} (${po.lines[i].unitLabel})',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Dipesan ${qtyText(po.lines[i].qty)} • sudah ${qtyText(before[po.lines[i].ingredientId] ?? 0)}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                  isDense: true,
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
                                  isDense: true,
                                ),
                                onChanged: (_) => setS(() {}),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              rupiah.format(lineTotal(i)),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: invoice,
                  decoration: const InputDecoration(
                    labelText: 'No. faktur / nota (opsional)',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Total diterima',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        rupiah.format(total),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canPay) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: paid,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dibayar sekarang (Rp)',
                      prefixText: 'Rp ',
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.roseSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Pembayaran melebihi total',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF9F1239),
                        ),
                      ),
                    )
                  else if (total > paidNow)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Sisa menjadi hutang: ${rupiah.format(total - paidNow)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                ],
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
