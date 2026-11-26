import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/reason_dialog.dart';
import 'package:rms_yow/features/audit/audit_log.dart';
import 'package:rms_yow/features/audit/audit_providers.dart';
import 'package:rms_yow/features/printing/print_after_pay_dialog.dart';
import 'package:rms_yow/features/printing/receipt_template.dart';
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
import '../charges/charge_providers.dart';
import '../orders/queue_board_page.dart';
import '../orders/queue_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({
    super.key,
    this.table,
    this.order,
    this.onOrderSaved,
    this.foodcourt = false,
  });
  final DiningTable? table; // null = takeaway
  final Order? order; // null = order baru
  final VoidCallback?
  onOrderSaved; // dipanggil setelah pesanan tersimpan/dibayar

  /// Outlet foodcourt: halaman ini tampil sebagai tab (bukan route). Tanpa meja dan
  /// open bill; pembayaran wajib bernomor antrian dan sesudahnya keranjang dikosongkan.
  final bool foodcourt;

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

  /// Takeaway restoran: pesanan dipanggil "atas nama ..." (wajib diisi).
  late final _name = TextEditingController(text: widget.order?.customerName ?? '');
  bool get _needsName => widget.table == null && !widget.foodcourt;
  bool get _nameOk => !_needsName || _name.text.trim().isNotEmpty;

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
    // foodcourt: panggil nomor antrean saat pesanan siap (berlaku walau modul KDS mati)
    if (widget.foodcourt) const QueueBoardButton(),
  ];

  /// Aksi berlabel di AppBar (bukan ikon saja).
  List<PageAction> _pageActions() => [
    if (widget.order != null)
      PageAction(
        icon: Icons.delete_outline,
        label: 'Batalkan order',
        shortLabel: 'Batalkan',
        destructive: true,
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
    final v = await showAppDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final n = int.tryParse(c.text) ?? 0;
          final amount = (pct ? (sub * n / 100).round() : n)
              .clamp(0, sub)
              .toInt();
          return AlertDialog(
            title: const Text('Diskon manual'),
            content: SingleChildScrollView(
              // HP kecil / keyboard terbuka: isi dialog bisa digulir, tidak overflow
              child: Column(
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

  Order _newOrder() {
    final now = DateTime.now();
    return Order(
      id: const Uuid().v4(),
      number:
          'INV-${DateFormat('yyMMdd').format(now)}-${const Uuid().v4().substring(0, 4).toUpperCase()}',
      type: widget.table == null ? OrderType.takeaway : OrderType.dineIn,
      tableId: widget.table?.id,
      createdAt: now.millisecondsSinceEpoch,
      createdBy: ref.read(appUserProvider).value?.uid ?? '',
    );
  }

  /// Foodcourt: siapkan keranjang kosong untuk pelanggan berikutnya.
  void _resetForNext() {
    setState(() {
      _order = _newOrder().copyWith(charges: ref.read(chargeLinesProvider));
      _savedIds.clear();
      _audits.clear();
      _category = 'Semua';
      _query = '';
      _search.clear();
      _paying = false;
    });
    _tab.animateTo(0);
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // pajak & biaya layanan dari master; mengikuti tarif terbaru sampai dibayar
    _order = (widget.order ?? _newOrder()).copyWith(
      charges: ref.read(chargeLinesProvider),
    );
    ref.listenManual(chargeLinesProvider, (_, next) {
      if (mounted) setState(() => _order = _order.copyWith(charges: next));
    });
  }

  @override
  void dispose() {
    _name.dispose();
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
    final v = await showAppDialog<String>(
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
          addedAt: DateTime.now().millisecondsSinceEpoch,
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
          addedAt: DateTime.now().millisecondsSinceEpoch,
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

  /// Item yang belum pernah dikirim ke dapur: item baru, atau tambahan qty dari item lama.
  List<OrderItem> _newForKitchen() {
    final before = {
      for (final i in widget.order?.items ?? <OrderItem>[]) i.id: i.qty,
    };
    return [
      for (final it in _order.items)
        if (it.qty > (before[it.id] ?? 0))
          it.copyWith(qty: it.qty - (before[it.id] ?? 0)),
    ];
  }

  /// Salin "atas nama" dari kolom isian ke pesanan.
  void _applyName() {
    if (!_needsName) return;
    final n = _name.text.trim();
    _order = n.isEmpty ? _order.copyWith(clearCustomerName: true) : _order.copyWith(customerName: n);
  }

  Future<void> _save() async {
    if (_order.items.isEmpty) return;
    if (!_nameOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi atas nama pelanggan dulu')));
      return;
    }
    _applyName();
    final newItems = _newForKitchen();
    final saved = _order;
    await ref.read(orderRepositoryProvider).save(saved);
    widget.onOrderSaved?.call();
    await _flushAudits();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    // popup cetak struk dapur untuk item baru / tambahan (tidak tampil bila tidak ada)
    await showPrintAfterSaveDialog(
      context,
      order: saved,
      settings: ref.read(effectivePrinterSettingsProvider),
      newItems: newItems,
      addition: widget.order != null,
      tableName: widget.table?.name,
      cashier: ref.read(appUserProvider).value?.name,
    );
    messenger.showSnackBar(const SnackBar(content: Text('Order disimpan')));
    nav.pop();
  }

  bool _paying = false;

  Future<void> _pay() async {
    if (_paying || _order.items.isEmpty) return;
    if (!_nameOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi atas nama pelanggan dulu')));
      return;
    }
    _applyName();
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
    final foodcourt = widget.foodcourt;
    // nomor pesanan online 2 hari terakhir: peringatan bila tercatat dua kali
    final since = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    final recentExternal = <String, String>{
      for (final o in ref.read(ordersProvider).value ?? const <Order>[])
        if (o.externalNo != null && o.createdAt >= since && o.id != _order.id)
          '${o.source.name}:${o.externalNo!.toLowerCase()}': o.number,
    };
    final r = await showAppDialog<PayResult>(
      context: context,
      builder: (_) => _PayDialog(
        total: _order.total,
        canHold: widget.table != null,
        queueMode: foodcourt,
        sourceMode: widget.table == null,
        activeQueues: foodcourt ? ref.read(activeQueueNumbersProvider) : const {},
        recentExternal: recentExternal,
      ),
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
      queueNo: r.queueNo,
      customerName: r.customerName,
      source: r.source,
      externalNo: r.externalNo,
      type: r.takeaway == null
          ? null
          : (r.takeaway! ? OrderType.takeaway : OrderType.dineIn),
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
    final cfg = ref.read(effectivePrinterSettingsProvider);
    final tableName = widget.table?.name;
    final cashier = ref.read(appUserProvider).value?.name;
    final change = r.method == PayMethod.cash ? r.paid - paid.total : 0;

    // popup: kasir memilih cetak struk order dan/atau struk dapur (tidak ada cetak otomatis)
    if (mounted) {
      await showPrintAfterPayDialog(
      context,
      order: paid,
      settings: cfg,
      tableName: tableName,
      cashier: cashier,
      change: change,
    );
    }
    if (foodcourt) {
      if (mounted) _resetForNext(); // layar kasir tetap terbuka untuk pelanggan berikutnya
    } else {
      nav.pop();
    }
    final queueText = paid.queueNo != null
        ? ' • Nomor ${paid.queueNo}'
        : (paid.customerName != null ? ' • a.n. ${paid.customerName}' : '');
    say('Pembayaran berhasil$queueText');
  }

  // ------------------------------------------------------------------ tampilan

  @override
  Widget build(BuildContext context) {
    ref.watch(itemStatusProvider);
    final menu = ref.watch(menuItemsProvider).value ?? [];
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 720;
    final title =
        widget.table?.name ?? (widget.foodcourt ? 'Order' : 'Takeaway');
    final qtyAll = _order.items.fold<int>(0, (s, i) => s + i.qty);

    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Text(
          _order.number,
          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );

    if (wide) {
      final cartW = w >= 1100 ? 420.0 : 360.0;
      return Scaffold(
        appBar: RmsAppBar(title: titleWidget, pageActions: _pageActions(), actions: _actions()),
        body: Row(
          children: [
            Expanded(child: _menuPane(menu, extent: w >= 1100 ? 210 : 190)),
            Container(
              width: cartW,
              decoration: BoxDecoration(
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
      appBar: RmsAppBar(
        title: titleWidget,
        pageActions: _pageActions(),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lihat pesanan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    rupiah.format(o.total),
                    style: GoogleFonts.plusJakartaSans(
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

  static List<({Color bg, Color fg})> get _palette => [ // getter: ikut tema aktif
    (bg: AppColors.primarySoft, fg: AppColors.primary),
    (bg: AppColors.roseSoft, fg: AppColors.rose),
    (bg: Color(0xFFF7EBD6), fg: Color(0xFF8A5A12)),
    (bg: AppColors.sageSoft, fg: AppColors.sageInk),
    (bg: AppColors.divider, fg: Color(0xFF1D4ED8)),
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
                      style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              Text(
                rupiah.format(m.price),
                style: GoogleFonts.plusJakartaSans(
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
                      tooltip: 'Hapus pencarian',
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
                  message: 'Owner/manager menambahkan menu lewat tab Menu.',
                )
              : shown.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Menu tidak ditemukan',
                  message: 'Coba kata lain atau pilih kategori "Semua".',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: extent,
                    // nama menu 2 baris tetap utuh, juga saat huruf HP diperbesar
                    mainAxisExtent: 120 * textScaleOf(context),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rupiah.format(it.price)} × ${it.qty}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  rupiah.format(it.total),
                  style: GoogleFonts.plusJakartaSans(
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
                  color: const Color(0xFFF7EBD6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 14,
                      color: Color(0xFF8A5A12),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        it.note,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF8A5A12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                // status mengisi sisa ruang (boleh menyusut) agar tombol tidak terdorong keluar
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: s == KitchenStatus.newItem
                        ? const SizedBox.shrink()
                        : StatusPill(
                            s.label,
                            tone: s == KitchenStatus.ready
                                ? Tone.success
                                : s == KitchenStatus.preparing
                                ? Tone.warning
                                : Tone.neutral,
                          ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: Text(it.note.isEmpty ? 'Catatan' : 'Ubah'),
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

    return LayoutBuilder(
      builder: (context, box) => Column(
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
        ConstrainedBox(
          // keyboard terbuka / HP pendek: ringkasan bisa digulir, daftar pesanan tetap terlihat
          constraints: BoxConstraints(
            maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.66 : double.infinity,
          ),
          child: SingleChildScrollView(
            child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_needsName) ...[
                    TextField(
                      controller: _name,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Atas nama',
                        hintText: 'Nama pelanggan takeaway',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        isDense: true,
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (noShift)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: InfoBanner(
                        'Pesanan tetap bisa disimpan. Buka kas di menu Kas sebelum menerima pembayaran.',
                        title: 'Kas belum dibuka',
                        tone: Tone.warning,
                      ),
                    ),
                  _line('Subtotal', o.subtotal),
                  if (o.discount > 0) _line('Diskon', -o.discount),
                  for (final a in o.appliedCharges) _line(a.line.label, a.amount),
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
                      if (!widget.foodcourt) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: o.items.isEmpty ? null : _save,
                            icon: const Icon(Icons.receipt_long_outlined, size: 19),
                            label: const Text('Open Bill'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: (o.items.isEmpty || !canPay) ? null : _pay,
                          icon: const Icon(Icons.payments_outlined, size: 20),
                          label: Text(
                            o.items.isEmpty
                                ? 'Bayar'
                                : 'Bayar ${rupiah.format(o.total)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ],
    ),
    );
  }

  Widget _line(String label, int value, {bool bold = false}) {
    final label0 = GoogleFonts.plusJakartaSans(
      fontSize: bold ? 16 : 13.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: bold ? AppColors.ink : AppColors.muted,
    );
    final value0 = GoogleFonts.plusJakartaSans(
      fontSize: bold ? 20 : 13.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: bold ? AppColors.primary : AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: label0),
          ),
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
          tooltip: 'Kurangi',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 20),
          onPressed: onDec,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Tambah',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.add, size: 20, color: AppColors.primary),
          onPressed: onInc,
        ),
      ],
    ),
  );
}

typedef PayResult = ({
  PayMethod method,
  int paid,
  bool hold,
  String? queueNo,
  String? customerName,
  OrderSource source,
  String? externalNo,
  bool? takeaway, // foodcourt: null = tidak ditanyakan
});

class _PayDialog extends StatefulWidget {
  const _PayDialog({
    required this.total,
    this.canHold = false,
    this.queueMode = false,
    this.sourceMode = false,
    this.activeQueues = const {},
    this.recentExternal = const {},
  });
  final int total;
  final bool canHold; // pesanan makan di tempat (punya meja)
  final bool queueMode; // outlet foodcourt: nomor antrian wajib diisi
  final bool sourceMode; // pesanan tanpa meja: pilih sumber (langsung / GoFood / ...)
  final Map<String, String>
  activeQueues; // nomor yang masih dipakai -> no. order
  final Map<String, String> recentExternal; // "gofood:f-123" -> no. order (2 hari terakhir)
  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  PayMethod _method = PayMethod.cash;
  late final TextEditingController _cash = TextEditingController(
    text: '${widget.total}',
  );
  bool _hold = false;
  final _queue = TextEditingController();
  final _ext = TextEditingController();
  // pilihan terakhir Nomor / Atas nama diingat selama aplikasi terbuka
  static bool _lastByName = false;
  bool _byName = _lastByName;
  OrderSource _source = OrderSource.walkin;
  bool _takeaway = false; // foodcourt: makan di sini (bawaan) / takeaway

  bool get _online => _source.isOnline;
  PayMethod get _effMethod => _online ? PayMethod.online : _method;
  int get _paid => _effMethod == PayMethod.cash
      ? (int.tryParse(_cash.text) ?? 0)
      : widget.total;
  bool get _ok =>
      _paid >= widget.total &&
      (!widget.queueMode || _queue.text.trim().isNotEmpty) &&
      (!_online || _ext.text.trim().isNotEmpty);

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
    _queue.dispose();
    _ext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ok;
    final dup = widget.queueMode
        ? widget.activeQueues[_queue.text.trim().toLowerCase()]
        : null;
    final extDup = _online
        ? widget.recentExternal['${_source.name}:${_ext.text.trim().toLowerCase()}']
        : null;
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rupiah.format(widget.total),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.sourceMode) ...[
                const SizedBox(height: 16),
                Text(
                  'Sumber pesanan',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final src in OrderSource.values)
                      ChoiceChip(
                        label: Text(src.label),
                        selected: _source == src,
                        onSelected: (_) => setState(() => _source = src),
                      ),
                  ],
                ),
                if (_online) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ext,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Nomor pesanan ${_source.label}',
                      hintText: 'Lihat di aplikasi ${_source.label}',
                      counterText: '',
                      helperText: extDup != null
                          ? 'Nomor ini sudah dicatat di pesanan $extDup. Pastikan tidak dobel.'
                          : 'Untuk cek silang dengan riwayat di aplikasi ${_source.label}.',
                      helperMaxLines: 2,
                      helperStyle: extDup != null ? const TextStyle(color: Color(0xFF8A5A12)) : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
              if (widget.queueMode && !_online) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.restaurant_outlined, size: 18), label: Text('Makan di sini')),
                    ButtonSegment(value: true, icon: Icon(Icons.shopping_bag_outlined, size: 18), label: Text('Takeaway')),
                  ],
                  selected: {_takeaway},
                  onSelectionChanged: (v) => setState(() => _takeaway = v.first),
                ),
              ],
              if (widget.queueMode) ...[
                const SizedBox(height: 16),
                // pelanggan dipanggil dengan nomor antrean atau namanya (dibacakan suara)
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.tag_rounded, size: 18), label: Text('Nomor')),
                    ButtonSegment(value: true, icon: Icon(Icons.person_outline_rounded, size: 18), label: Text('Atas nama')),
                  ],
                  selected: {_byName},
                  onSelectionChanged: (v) => setState(() {
                    _byName = v.first;
                    _lastByName = _byName;
                    _queue.clear();
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _queue,
                  autofocus: !widget.sourceMode,
                  maxLength: _byName ? 40 : 10,
                  textCapitalization: _byName ? TextCapitalization.words : TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: _byName ? 'Atas nama' : 'Nomor antrian',
                    hintText: _byName ? 'Nama pelanggan, mis. Budi' : 'Nomor yang diberikan ke pelanggan',
                    counterText: '',
                    helperText: dup != null
                        ? '${_byName ? 'Nama' : 'Nomor'} ini masih dipakai pesanan $dup yang belum selesai.'
                        : null,
                    helperMaxLines: 2,
                    helperStyle: const TextStyle(color: Color(0xFF8A5A12)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              if (!_online)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Metode pembayaran',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                ),
              if (_online)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.sageSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, color: AppColors.sageInk),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dibayar lewat aplikasi ${_source.label}. Tidak masuk uang laci.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.sageInk, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final m in PayMethod.values)
                      if (m != PayMethod.online)
                        ChoiceChip(
                          avatar: Icon(_icon(m), size: 18),
                          label: Text(m.label),
                          selected: _method == m,
                          onSelected: (_) => setState(() => _method = m),
                        ),
                  ],
                ),
              if (!_online && _method == PayMethod.cash) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _cash,
                  autofocus: !widget.queueMode,
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
                    color: ok ? AppColors.sageSoft : AppColors.roseSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                        ok ? 'Kembalian' : 'Uang kurang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ok
                              ? AppColors.sageInk
                              : AppColors.primary,
                        ),
                      ),
                      ),
                      Text(
                        rupiah.format(
                          ok
                              ? max(0, _paid - widget.total)
                              : widget.total - _paid,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ok
                              ? AppColors.sageInk
                              : AppColors.primary,
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
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 20),
          onPressed: ok
              ? () => Navigator.pop<PayResult>(context, (
                  method: _effMethod,
                  paid: _paid,
                  hold: _hold,
                  queueNo: widget.queueMode && !_byName ? _queue.text.trim() : null,
                  customerName: widget.queueMode && _byName ? _queue.text.trim() : null,
                  source: widget.sourceMode ? _source : OrderSource.walkin,
                  externalNo: _online ? _ext.text.trim() : null,
                  takeaway: widget.queueMode ? (_online || _takeaway) : null,
                ))
              : null,
          label: Text(dup != null ? 'Tetap pakai nomor ini' : 'Konfirmasi bayar'),
        ),
      ],
    );
  }
}
