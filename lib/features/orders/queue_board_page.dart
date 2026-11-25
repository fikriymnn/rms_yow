import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../kitchen_kpi/kitchen_kpi_page.dart';
import '../voice/order_announcer.dart';
import '../voice/voice_service.dart';
import 'order_models.dart';
import 'order_providers.dart';

/// Pesanan foodcourt yang sudah dibayar dan belum diambil.
/// [ready] = semua item siap (dipanggil), belum diambil pelanggan.
typedef QueueEntry = ({Order order, bool ready, int readyCount});

final queueBoardProvider = Provider<List<QueueEntry>>((ref) {
  final orders = ref.watch(ordersProvider).value ?? const <Order>[];
  final status = ref.watch(itemStatusProvider).value ?? const <String, KitchenStatus>{};
  final cutoff = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
  final out = <QueueEntry>[];
  for (final o in orders) {
    if (o.status != OrderStatus.paid || o.createdAt < cutoff || o.items.isEmpty) continue;
    final st = [for (final i in o.items) status[i.id] ?? KitchenStatus.newItem];
    if (st.every((s) => s == KitchenStatus.served)) continue;
    final ready = st.where((s) => s == KitchenStatus.ready || s == KitchenStatus.served).length;
    out.add((order: o, ready: ready == st.length, readyCount: ready));
  }
  out.sort((a, b) => (a.order.paidAt ?? a.order.createdAt).compareTo(b.order.paidAt ?? b.order.createdAt));
  return out;
});

/// Antrean foodcourt: kasir menekan Panggil saat dapur selesai (walau modul KDS mati),
/// lalu Sudah diambil saat pelanggan mengambil pesanan (nomor antrean bebas dipakai lagi).
class QueueBoardPage extends ConsumerStatefulWidget {
  const QueueBoardPage({super.key});
  @override
  ConsumerState<QueueBoardPage> createState() => _QueueBoardPageState();
}

class _QueueBoardPageState extends ConsumerState<QueueBoardPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _call(Order o) async {
    final status = ref.read(itemStatusProvider).value ?? const <String, KitchenStatus>{};
    final pending = o.items.where((i) {
      final s = status[i.id] ?? KitchenStatus.newItem;
      return s != KitchenStatus.ready && s != KitchenStatus.served;
    });
    // pengumuman suara datang dari OrderAnnouncer (bila "Pesanan siap" aktif di perangkat ini)
    await ref.read(itemStatusRepositoryProvider).setStatus(o.id, pending, KitchenStatus.ready);
  }

  Future<void> _taken(Order o) =>
      ref.read(itemStatusRepositoryProvider).setStatus(o.id, o.items, KitchenStatus.served);

  void _recall(Order o) => ref.read(voiceServiceProvider).say(readySentence(o, const {}), chime: Chime.ready);

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(queueBoardProvider);
    final voiceOn = ref.watch(voiceSettingsProvider).value?.ready ?? false;
    final waiting = entries.where((e) => !e.ready).toList();
    final ready = entries.where((e) => e.ready).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrean pesanan'),
        actions: [
          IconButton(
            tooltip: 'Riwayat & KPI dapur',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const KitchenKpiPage()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 840;
          final cols = [
            _column('Sedang disiapkan', waiting, false),
            _column('Siap diambil', ready, true),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!voiceOn) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EBD6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_off_outlined, color: Color(0xFF8A5A12)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Suara panggilan mati di perangkat ini.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF8A5A12)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final s = ref.read(voiceSettingsProvider).value;
                          if (s != null) ref.read(voiceSettingsProvider.notifier).save(s.copyWith(ready: true));
                        },
                        child: const Text('Aktifkan'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cols[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cols[1]),
                  ],
                )
              else ...[
                cols[1],
                const SizedBox(height: 16),
                cols[0],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _column(String title, List<QueueEntry> list, bool ready) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.faint,
            ),
          ),
          const SizedBox(width: 8),
          StatusPill('${list.length}', tone: ready ? Tone.success : Tone.warning),
        ],
      ),
      const SizedBox(height: 10),
      if (list.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            ready ? 'Belum ada yang dipanggil' : 'Tidak ada pesanan menunggu',
            style: GoogleFonts.plusJakartaSans(color: AppColors.faint),
          ),
        )
      else
        for (var i = 0; i < list.length; i++)
          Entrance(index: i, child: _card(list[i], ready)),
    ],
  );

  Widget _card(QueueEntry e, bool ready) {
    final o = e.order;
    final since = o.paidAt ?? o.createdAt;
    final mins = ((DateTime.now().millisecondsSinceEpoch - since) / 60000).floor().clamp(0, 9999);
    final late = !ready && mins >= 15;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ready ? AppColors.sageSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: late ? AppColors.primary : (ready ? AppColors.sage : AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ready ? AppColors.sageInk : AppColors.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  o.queueNo ?? '-',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ),
                    Text(
                      '$mins mnt',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: late ? AppColors.primary : AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final it in o.items)
                  Text(
                    '${it.qty}× ${it.name}${it.note.isEmpty ? '' : ' (${it.note})'}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                if (!ready && e.readyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${e.readyCount}/${o.items.length} item sudah siap',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.sageInk),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ready
                      ? [
                          OutlinedButton.icon(
                            onPressed: () => _recall(o),
                            icon: const Icon(Icons.campaign_outlined, size: 18),
                            label: const Text('Panggil ulang'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _taken(o),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Sudah diambil'),
                          ),
                        ]
                      : [
                          FilledButton.icon(
                            onPressed: () => _call(o),
                            icon: const Icon(Icons.campaign_rounded, size: 18),
                            label: const Text('Panggil'),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol app bar POS foodcourt: buka antrean, dengan jumlah pesanan yang belum diambil.
class QueueBoardButton extends ConsumerWidget {
  const QueueBoardButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(queueBoardProvider).length;
    final canUse = ref.watch(appUserProvider).value?.canAny(const ['orders.update', 'kitchen.update']) ?? false;
    if (!canUse) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        backgroundColor: AppColors.primary,
        child: IconButton(
          tooltip: 'Antrean pesanan',
          icon: const Icon(Icons.campaign_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const QueueBoardPage()),
          ),
        ),
      ),
    );
  }
}
