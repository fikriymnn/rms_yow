import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'direct_purchase.dart';
import 'direct_purchase_page.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

enum _Period {
  week('7 hari', 7),
  month('30 hari', 30),
  quarter('90 hari', 90),
  all('Semua', 0);

  const _Period(this.label, this.days);
  final String label;
  final int days;
}

/// Riwayat belanja langsung (tanpa PO) outlet aktif.
class DirectPurchasesPage extends ConsumerStatefulWidget {
  const DirectPurchasesPage({super.key});
  @override
  ConsumerState<DirectPurchasesPage> createState() => _DirectPurchasesPageState();
}

class _DirectPurchasesPageState extends ConsumerState<DirectPurchasesPage> {
  _Period _period = _Period.month;
  String _q = '';

  void _detail(DirectPurchase p) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(p.number, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            [
              _dateFmt.format(DateTime.fromMillisecondsSinceEpoch(p.at)),
              if (p.place.isNotEmpty) p.place,
              if (p.createdByName.isNotEmpty) p.createdByName,
            ].join(' · '),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted),
          ),
          if (p.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.note, style: GoogleFonts.plusJakartaSans(fontSize: 13.5)),
          ],
          const Divider(height: 28),
          for (final l in p.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        Text(
                          '${qtyText(l.qty)} ${l.unit}'
                          '${l.qty > 0 && l.price > 0 ? ' · ${rupiah.format(l.price / l.qty)}/${l.unit}' : ''}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                        ),
                        if (l.note.isNotEmpty)
                          Text(l.note, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.faint)),
                      ],
                    ),
                  ),
                  Text(rupiah.format(l.price), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              Text('Total', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                rupiah.format(p.total),
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Belanja yang sudah dicatat tidak bisa diubah. Salah jumlah? Koreksi lewat Waste atau Stok opname.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.faint, height: 1.4),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(directPurchasesProvider).value ?? const <DirectPurchase>[];
    final canBuy = ref.watch(appUserProvider).value?.can('stock.purchase_direct') ?? false;
    final from = _period.days == 0
        ? 0
        : DateTime.now().subtract(Duration(days: _period.days)).millisecondsSinceEpoch;
    final shown = all
        .where((p) => p.at >= from)
        .where(
          (p) =>
              _q.isEmpty ||
              p.number.toLowerCase().contains(_q) ||
              p.place.toLowerCase().contains(_q) ||
              p.lines.any((l) => l.name.toLowerCase().contains(_q)),
        )
        .toList();
    final total = shown.fold<double>(0, (s, p) => s + p.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Belanja langsung')),
      floatingActionButton: canBuy
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const DirectPurchasePage()),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Belanja baru'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _Period.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Cari tempat, nomor, atau bahan',
              isDense: true,
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          AdaptiveGrid(
            minTileWidth: 200,
            maxColumns: 2,
            children: [
              StatTile(icon: Icons.shopping_bag_outlined, label: 'Jumlah belanja', value: '${shown.length}'),
              StatTile(icon: Icons.payments_outlined, label: 'Total belanja', value: rupiah.format(total)),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: all.isEmpty ? 'Belum ada belanja' : 'Tidak ada yang cocok',
              message: all.isEmpty && canBuy ? 'Catat belanja ke pasar / toko tanpa PO di sini.' : null,
            )
          else
            for (var i = 0; i < shown.length; i++)
              Entrance(
                index: i,
                child: Pressable(
                  onTap: () => _detail(shown[i]),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shown[i].place.isEmpty ? shown[i].number : shown[i].place,
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${_dateFmt.format(DateTime.fromMillisecondsSinceEpoch(shown[i].at))} · '
                                '${shown[i].lines.length} bahan'
                                '${shown[i].place.isEmpty ? '' : ' · ${shown[i].number}'}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shown[i].lines.map((l) => l.name).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.faint),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          rupiah.format(shown[i].total),
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
