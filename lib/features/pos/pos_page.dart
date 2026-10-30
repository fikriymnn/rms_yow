import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/reason_dialog.dart';
import 'package:rms_yow/features/audit/audit_log.dart';
import 'package:rms_yow/features/audit/audit_providers.dart';
import 'package:rms_yow/features/printing/printer_service.dart';
import 'package:rms_yow/features/printing/printer_settings.dart';
import 'package:rms_yow/features/shifts/shift_providers.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../menu/menu_item.dart';
import '../menu/menu_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/dining_table.dart';
import '../tables/table_hold.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key, this.table, this.order, this.onOrderSaved});
  final DiningTable? table; // null = takeaway
  final Order? order; // null = order baru
  final VoidCallback?
  onOrderSaved; // dipanggil setelah pesanan tersimpan/dibayar

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage>
    with SingleTickerProviderStateMixin {
  late Order _order;
  String _category = 'Semua';
  String _query = '';
  final _search = TextEditingController();
  late final TabController _tab;

  late final Set<String> _savedIds = {
    for (final i in widget.order?.items ?? <OrderItem>[]) i.id,
  };
  final _audits =
      <({AuditAction action, String reason, String detail, int amount})>[];

  bool get _isManager =>
      ref.read(appUserProvider).value?.can('orders.void_processed') ?? false;

  Future<void> _flushAudits() async {
    final repo = ref.read(auditRepositoryProvider);
    for (final a in _audits) {
      await repo.record(
        a.action,
        reason: a.reason,
        order: _order,
        detail: a.detail,
        amount: a.amount,
      );
    }
    _audits.clear();
  }

  List<Widget> _actions() => [
    if (widget.order != null)
      IconButton(
        tooltip: 'Batalkan order',
        icon: const Icon(Icons.delete_outline),
        onPressed: _cancel,
      ),
  ];

  Future<void> _cancel() async {
    final o = widget.order;
    if (o == null) return;
    final processed = o.items.any((e) => _st(e) != KitchenStatus.newItem);
    if (processed && !_isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sebagian item sudah diproses dapur, butuh manager'),
        ),
      );
      return;
    }
    final reason = await askReason(context, 'Batalkan order ${o.number}');
    if (reason == null) return;
    _audits.clear();
    _audits.add((
      action: AuditAction.cancelOrder,
      reason: reason,
      detail: '${o.items.length} item',
      amount: o.total,
    ));
    _order = o.copyWith(status: OrderStatus.voided);
    await ref.read(orderRepositoryProvider).save(_order);
    await _flushAudits();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _discount() async {
    final sub = _order.subtotal;
    final c = TextEditingController();
    var pct = false;
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final n = int.tryParse(c.text) ?? 0;
          final amount = (pct ? (sub * n / 100).round() : n)
              .clamp(0, sub)
              .toInt();
          return AlertDialog(
            title: const Text('Diskon manual'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Rp')),
                    ButtonSegment(value: true, label: Text('%')),
                  ],
                  selected: {pct},
                  onSelectionChanged: (s) => setS(() => pct = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: pct ? 'Persen' : 'Nominal (Rp)',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 8),
                Text('Potongan: ${rupiah.format(amount)}'),
              ],
            ),
            actions: [
              if (_order.discount > 0)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 0),
                  child: const Text('Hapus diskon'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: amount > 0 ? () => Navigator.pop(ctx, amount) : null,
                child: const Text('Terapkan'),
              ),
            ],
          );
        },
      ),
    );
    if (v == null || !mounted) return;
    final reason = await askReason(
      context,
      v == 0 ? 'Alasan hapus diskon' : 'Alasan diskon',
    );
    if (reason == null) return;
    setState(() => _order = _order.copyWith(discount: v));
    _audits.add((
      action: AuditAction.discount,
      reason: reason,
      detail: v == 0 ? 'Diskon dihapus' : 'Diskon ${rupiah.format(v)}',
      amount: v,
    ));
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _order =
        widget.order ??
        Order(
          id: const Uuid().v4(),
          number:
              'INV-${DateFormat('yyMMdd').format(now)}-${const Uuid().v4().substring(0, 4).toUpperCase()}',
          type: widget.table == null ? OrderType.takeaway : OrderType.dineIn,
          tableId: widget.table?.id,
          createdAt: now.millisecondsSinceEpoch,
          createdBy: ref.read(appUserProvider).value?.uid ?? '',
        );
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  void _setItems(List<OrderItem> items) =>
      setState(() => _order = _order.copyWith(items: items));

  KitchenStatus _st(OrderItem it) =>
      ref.read(itemStatusProvider).value?[it.id] ?? KitchenStatus.newItem;

  Future<void> _note(int i) async {
    final c = TextEditingController(text: _order.items[i].note);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'mis. tidak pedas'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (v == null) return;
    final items = [..._order.items];
    items[i] = items[i].copyWith(note: v);
    _setItems(items);
  }

  void _add(MenuItem m) {
    final items = [..._order.items];
    final i = items.indexWhere(
      (e) =>
          e.menuItemId == m.id &&
          _st(e) == KitchenStatus.newItem &&
          e.note.isEmpty,
    );
    if (i >= 0) {
      items[i] = items[i].copyWith(qty: items[i].qty + 1);
    } else {
      items.add(
        OrderItem(
          id: const Uuid().v4(),
          menuItemId: m.id,
          name: m.name,
          price: m.price,
        ),
      );
    }
    _setItems(items);
  }

  void _inc(int i) {
    final items = [..._order.items];
    final it = items[i];
    if (_st(it) == KitchenStatus.newItem) {
      items[i] = it.copyWith(qty: it.qty + 1);
    } else {
      // sudah diproses dapur -> baris baru agar muncul sebagai tiket tambahan
      items.add(
        OrderItem(
          id: const Uuid().v4(),
          menuItemId: it.menuItemId,
          name: it.name,
          price: it.price,
        ),
      );
    }
    _setItems(items);
  }

  Future<void> _dec(int i) async {
    final it = _order.items[i];
    if (_savedIds.contains(it.id)) {
      // item sudah pernah disimpan/dikirim ke dapur -> wajib alasan + audit
      if (_st(it) != KitchenStatus.newItem && !_isManager) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item sudah diproses dapur, butuh manager'),
          ),
        );
        return;
      }
      final reason = await askReason(context, 'Void ${it.name}');
      if (reason == null) return;
      _audits.add((
        action: AuditAction.voidItem,
        reason: reason,
        detail: '${it.name} ×1',
        amount: it.price,
      ));
    }
    final items = [..._order.items];
    final k = items.indexWhere((e) => e.id == it.id);
    if (k < 0) return;
    if (items[k].qty > 1) {
      items[k] = items[k].copyWith(qty: items[k].qty - 1);
    } else {
      items.removeAt(k);
    }
    _setItems(items);
  }

  Future<void> _save() async {
    if (_order.items.isEmpty) return;
    await ref.read(orderRepositoryProvider).save(_order);
    widget.onOrderSaved?.call();
    await _flushAudits();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order disimpan')));
    Navigator.pop(context);
  }

  bool _paying = false;

  Future<void> _pay() async {
    if (_paying || _order.items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    void say(String m, {int sec = 4}) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(m),
          duration: Duration(seconds: sec),
        ),
      );
    }

    final shift = await resolveCurrentShift(ref);
    if (shift == null) {
      say('Buka shift dulu di tab Kas');
      return;
    }
    final r = await showDialog<({PayMethod method, int paid, bool hold})>(
      context: context,
      builder: (_) =>
          _PayDialog(total: _order.total, canHold: widget.table != null),
    );
    if (r == null || !mounted) return;

    _paying = true;
    final me = ref.read(appUserProvider).value;
    final paid = _order.copyWith(
      shiftId: shift.id,
      status: OrderStatus.paid,
      payMethod: r.method,
      paidAmount: r.paid,
      paidAt: DateTime.now().millisecondsSinceEpoch,
      paidBy: me?.uid,
      paidByName: me?.name,
    );
    try {
      await ref.read(orderRepositoryProvider).save(paid);
      await _flushAudits();
      if (widget.table != null) {
        try {
          await applyTableHold(
            ref,
            tableId: widget.table!.id,
            orderId: paid.id,
            orderNumber: paid.number,
            hold: r.hold, // pelanggan masih di meja
          );
        } catch (e) {
          debugPrint(
            'Status meja gagal diperbarui: $e',
          ); // tidak menggagalkan pembayaran
        }
      }
    } catch (e, st) {
      debugPrint('Pembayaran gagal: $e\n$st');
      _paying = false;
      say('Pembayaran gagal disimpan: $e', sec: 8);
      return;
    }
    widget.onOrderSaved?.call();

    // // potong stok sesuai resep; kegagalan di sini tidak boleh menggagalkan pembayaran
    // try {
    //   await ref.read(stockRepositoryProvider).deductForOrder(paid);
    // } catch (e, st) {
    //   logStockError(e, st);
    // }

    // ambil semua yang dibutuhkan SEBELUM halaman ditutup (ref tidak aman sesudahnya)
    final cfg = ref.read(printerSettingsProvider).value;
    final tableName = widget.table?.name;
    final cashier = ref.read(appUserProvider).value?.name;
    final change = r.method == PayMethod.cash ? r.paid - paid.total : 0;

    nav.pop();
    say(
      change > 0
          ? 'Pembayaran berhasil • Kembalian ${rupiah.format(change)}'
          : 'Pembayaran berhasil',
    );

    if (cfg != null && cfg.autoPrint) {
      await Future<void>.delayed(const Duration(seconds: 2));
      say('Mencetak struk...', sec: 30);
      try {
        await printOrderReceipt(
          settings: cfg,
          order: paid,
          tableName: tableName,
          cashier: cashier,
        ).timeout(const Duration(seconds: 20));
        say('Struk tercetak', sec: 3);
      } catch (e) {
        say('Struk gagal dicetak: $e', sec: 8);
      }
    }
  }

  // ------------------------------------------------------------------ tampilan

  @override
  Widget build(BuildContext context) {
    ref.watch(itemStatusProvider);
    final menu = ref.watch(menuItemsProvider).value ?? [];
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 720;
    final title = widget.table?.name ?? 'Takeaway';
    final qtyAll = _order.items.fold<int>(0, (s, i) => s + i.qty);

    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Text(
          _order.number,
          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );

    if (wide) {
      final cartW = w >= 1100 ? 420.0 : 360.0;
      return Scaffold(
        appBar: AppBar(title: titleWidget, actions: _actions()),
        body: Row(
          children: [
            Expanded(child: _menuPane(menu, extent: w >= 1100 ? 210 : 190)),
            Container(
              width: cartW,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              child: _cartPane(header: true),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
        actions: _actions(),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            const Tab(text: 'Menu'),
            Tab(text: 'Pesanan ($qtyAll)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Column(
            children: [
              Expanded(child: _menuPane(menu, extent: 200)),
              _cartBar(),
            ],
          ),
          _cartPane(),
        ],
      ),
    );
  }

  /// HP: ringkasan pesanan menempel di dasar tab Menu.
  Widget _cartBar() {
    final o = _order;
    if (o.items.isEmpty) return const SizedBox.shrink();
    final qty = o.items.fold<int>(0, (s, i) => s + i.qty);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          child: InkWell(
            onTap: () => _tab.animateTo(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$qty item',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Lihat pesanan',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rupiah.format(o.total),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _palette = <({Color bg, Color fg})>[
    (bg: AppColors.primarySoft, fg: AppColors.primary),
    (bg: AppColors.roseSoft, fg: AppColors.rose),
    (bg: Color(0xFFFEF3C7), fg: Color(0xFFB45309)),
    (bg: Color(0xFFD1FAE5), fg: Color(0xFF047857)),
    (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8)),
  ];

  Widget _menuCard(MenuItem m) {
    final inCart = _order.items
        .where((e) => e.menuItemId == m.id)
        .fold<int>(0, (s, e) => s + e.qty);
    final tone =
        _palette[m.category.codeUnits.fold<int>(0, (a, b) => a + b) %
            _palette.length];
    final initial = m.name.trim().isEmpty
        ? '?'
        : m.name.trim()[0].toUpperCase();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _add(m),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inCart > 0 ? AppColors.primary : AppColors.border,
              width: inCart > 0 ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone.bg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tone.fg,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (inCart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rose,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '×$inCart',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  m.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              Text(
                rupiah.format(m.price),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuPane(List<MenuItem> menu, {required double extent}) {
    final cats = [
      'Semua',
      ...{for (final m in menu) m.category},
    ];
    final shown = menu
        .where(
          (m) =>
              m.available &&
              (_category == 'Semua' || m.category == _category) &&
              (_query.isEmpty || m.name.toLowerCase().contains(_query)),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Cari menu',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: menu.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'Belum ada menu',
                )
              : shown.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Menu tidak ditemukan',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: extent,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _menuCard(shown[i]),
                ),
        ),
      ],
    );
  }

  Widget _cartItem(int i) {
    final it = _order.items[i];
    final s = _st(it);
    return GestureDetector(
      onLongPress: () => _note(i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.name,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rupiah.format(it.price)} × ${it.qty}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  rupiah.format(it.total),
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (it.note.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 14,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        it.note,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (s != KitchenStatus.newItem)
                  StatusPill(
                    s.label,
                    tone: s == KitchenStatus.ready
                        ? Tone.success
                        : s == KitchenStatus.preparing
                        ? Tone.warning
                        : Tone.neutral,
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Catatan',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_note),
                  onPressed: () => _note(i),
                ),
                _Stepper(
                  qty: it.qty,
                  onDec: () => _dec(i),
                  onInc: () => _inc(i),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartPane({bool header = false}) {
    final o = _order;
    final user = ref.watch(appUserProvider).value;
    final canPay = user?.canPay ?? false;
    final isManager = user?.can('orders.discount') ?? false;
    final noShift = ref.watch(currentShiftProvider) == null;
    final qty = o.items.fold<int>(0, (s, i) => s + i.qty);

    return Column(
      children: [
        if (header)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pesanan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (qty > 0) StatusPill('$qty item', tone: Tone.info),
              ],
            ),
          ),
        Expanded(
          child: o.items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Belum ada item',
                  message: 'Ketuk menu untuk menambahkan',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: o.items.length,
                  itemBuilder: (_, i) => _cartItem(i),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (noShift)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.roseSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Belum ada shift aktif. Pesanan tetap bisa disimpan; '
                      'buka shift di tab Kas sebelum membayar.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                _line('Subtotal', o.subtotal),
                if (o.discount > 0) _line('Diskon', -o.discount),
                if (kTaxPercent > 0) _line('Pajak $kTaxPercent%', o.tax),
                if (kServicePercent > 0)
                  _line('Service $kServicePercent%', o.service),
                const Divider(height: 20),
                _line('Total', o.total, bold: true),
                const SizedBox(height: 6),
                if (isManager && o.items.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _discount,
                      icon: const Icon(Icons.sell_outlined, size: 18),
                      label: Text(o.discount > 0 ? 'Ubah diskon' : 'Diskon'),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: o.items.isEmpty ? null : _save,
                        child: const Text('Open Bill'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: (o.items.isEmpty || !canPay) ? null : _pay,
                        child: Text(
                          o.items.isEmpty
                              ? 'Bayar'
                              : 'Bayar ${rupiah.format(o.total)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(String label, int value, {bool bold = false}) {
    final label0 = GoogleFonts.inter(
      fontSize: bold ? 16 : 13.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: bold ? AppColors.ink : AppColors.muted,
    );
    final value0 = GoogleFonts.inter(
      fontSize: bold ? 20 : 13.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: bold ? AppColors.primary : AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: label0),
          Text(rupiah.format(value), style: value0),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onDec, required this.onInc});
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 20),
          onPressed: onDec,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 20, color: AppColors.primary),
          onPressed: onInc,
        ),
      ],
    ),
  );
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.total, this.canHold = false});
  final int total;
  final bool canHold; // pesanan makan di tempat (punya meja)
  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  PayMethod _method = PayMethod.cash;
  late final TextEditingController _cash = TextEditingController(
    text: '${widget.total}',
  );
  bool _hold = false;

  int get _paid => _method == PayMethod.cash
      ? (int.tryParse(_cash.text) ?? 0)
      : widget.total;
  bool get _ok => _paid >= widget.total;

  List<int> get _quick {
    final t = widget.total;
    final s = <int>{t};
    for (final step in [5000, 10000, 50000, 100000]) {
      s.add(((t + step - 1) ~/ step) * step);
    }
    return (s.toList()..sort()).take(4).toList();
  }

  IconData _icon(PayMethod m) => switch (m.name) {
    'cash' => Icons.payments_outlined,
    'qris' => Icons.qr_code_2,
    _ => Icons.credit_card,
  };

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ok;
    return AlertDialog(
      title: const Text('Pembayaran'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total tagihan',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rupiah.format(widget.total),
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in PayMethod.values)
                    ChoiceChip(
                      avatar: Icon(_icon(m), size: 18),
                      label: Text(m.name.toUpperCase()),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              if (_method == PayMethod.cash) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _cash,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Uang diterima',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final v in _quick)
                      ActionChip(
                        label: Text(
                          v == widget.total ? 'Uang pas' : rupiah.format(v),
                        ),
                        onPressed: () => setState(() => _cash.text = '$v'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ok ? const Color(0xFFD1FAE5) : AppColors.roseSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        ok ? 'Kembalian' : 'Uang kurang',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ok
                              ? const Color(0xFF047857)
                              : const Color(0xFF9F1239),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        rupiah.format(
                          ok
                              ? max(0, _paid - widget.total)
                              : widget.total - _paid,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ok
                              ? const Color(0xFF047857)
                              : const Color(0xFF9F1239),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.canHold) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    title: const Text('Pelanggan masih di meja'),
                    subtitle: const Text(
                      'Meja tetap terisi setelah dibayar sampai dikosongkan',
                    ),
                    value: _hold,
                    onChanged: (v) => setState(() => _hold = v),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: ok
              ? () => Navigator.pop(context, (
                  method: _method,
                  paid: _paid,
                  hold: _hold,
                ))
              : null,
          child: const Text('Konfirmasi'),
        ),
      ],
    );
  }
}
