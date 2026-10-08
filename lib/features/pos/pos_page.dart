import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/features/shifts/shift_providers.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../auth/auth_providers.dart';
import '../menu/menu_item.dart';
import '../menu/menu_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/dining_table.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key, this.table, this.order});
  final DiningTable? table; // null = takeaway
  final Order? order; // null = order baru

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  late Order _order;
  String _category = 'Semua';

  @override
  void initState() {
    super.initState();
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

  void _dec(int i) {
    final items = [..._order.items];
    final it = items[i];
    if (_st(it) != KitchenStatus.newItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item sudah diproses dapur, tidak bisa dikurangi'),
        ),
      );
      return;
    }
    if (it.qty > 1) {
      items[i] = it.copyWith(qty: it.qty - 1);
    } else {
      items.removeAt(i);
    }
    _setItems(items);
  }

  Future<void> _save() async {
    if (_order.items.isEmpty) return;
    await ref.read(orderRepositoryProvider).save(_order);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pay() async {
    if (_order.items.isEmpty) return;
    final shift = ref.read(currentShiftProvider);
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buka shift dulu di tab Kas')),
      );
      return;
    }
    final r = await showDialog<({PayMethod method, int paid})>(
      context: context,
      builder: (_) => _PayDialog(total: _order.total),
    );
    if (r == null) return;
    final paid = _order.copyWith(
      shiftId: shift.id,
      status: OrderStatus.paid,
      payMethod: r.method,
      paidAmount: r.paid,
      paidAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(orderRepositoryProvider).save(paid);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(itemStatusProvider);
    final menu = ref.watch(menuItemsProvider).value ?? [];
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final title = widget.table?.name ?? 'Takeaway';
    final qtyAll = _order.items.fold<int>(0, (s, i) => s + i.qty);

    if (wide) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Row(
          children: [
            Expanded(flex: 3, child: _menuPane(menu)),
            const VerticalDivider(width: 1),
            Expanded(flex: 2, child: _cartPane()),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Menu'),
              Tab(text: 'Pesanan ($qtyAll)'),
            ],
          ),
        ),
        body: TabBarView(children: [_menuPane(menu), _cartPane()]),
      ),
    );
  }

  Widget _menuPane(List<MenuItem> menu) {
    final cats = [
      'Semua',
      ...{for (final m in menu) m.category},
    ];
    final shown = menu
        .where(
          (m) =>
              m.available && (_category == 'Semua' || m.category == _category),
        )
        .toList();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
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
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 90,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final m = shown[i];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _add(m),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(rupiah.format(m.price)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cartPane() {
    final o = _order;
    final canPay = ref.watch(appUserProvider).value?.canPay ?? false;
    return Column(
      children: [
        Expanded(
          child: o.items.isEmpty
              ? const Center(child: Text('Belum ada item'))
              : ListView.separated(
                  itemCount: o.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = o.items[i];
                    return ListTile(
                      title: Text(it.name),
                      onLongPress: () => _note(i),
                      subtitle: Text(
                        '${rupiah.format(it.price)} × ${it.qty} = ${rupiah.format(it.total)}'
                        '${_st(it) == KitchenStatus.newItem ? '' : '  • ${_st(it).label}'}'
                        '${it.note.isEmpty ? '' : '\nCatatan: ${it.note}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _dec(i),
                          ),
                          Text('${it.qty}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _inc(i),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _line('Subtotal', o.subtotal),
              if (o.discount > 0) _line('Diskon', -o.discount),
              if (kTaxPercent > 0) _line('Pajak $kTaxPercent%', o.tax),
              if (kServicePercent > 0)
                _line('Service $kServicePercent%', o.service),
              _line('Total', o.total, bold: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: o.items.isEmpty ? null : _save,
                      child: const Text('Simpan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: (o.items.isEmpty || !canPay) ? null : _pay,
                      child: const Text('Bayar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String label, int value, {bool bold = false}) {
    final s = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: s),
          Text(rupiah.format(value), style: s),
        ],
      ),
    );
  }
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.total});
  final int total;
  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  PayMethod _method = PayMethod.cash;
  final _cash = TextEditingController();

  int get _paid => _method == PayMethod.cash
      ? (int.tryParse(_cash.text) ?? 0)
      : widget.total;
  bool get _ok => _paid >= widget.total;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Bayar ${rupiah.format(widget.total)}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final m in PayMethod.values)
              ChoiceChip(
                label: Text(m.name.toUpperCase()),
                selected: _method == m,
                onSelected: (_) => setState(() => _method = m),
              ),
          ],
        ),
        if (_method == PayMethod.cash) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _cash,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Uang diterima'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text('Kembalian: ${rupiah.format(max(0, _paid - widget.total))}'),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _ok
            ? () => Navigator.pop(context, (method: _method, paid: _paid))
            : null,
        child: const Text('Konfirmasi'),
      ),
    ],
  );
}
