import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../approvals/approval_providers.dart';
import '../approvals/pending_requests_card.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import 'charge_models.dart';
import 'charge_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';

/// Master pajak & biaya layanan. Owner menyimpan langsung; manager mengajukan
/// perubahan yang baru berlaku setelah disetujui owner.
class ChargesTab extends ConsumerWidget {
  const ChargesTab({super.key});

  void _toast(BuildContext context, String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Charge? c, {
    required bool direct,
    required List<Charge> all,
  }) async {
    final name = TextEditingController(text: c?.name ?? '');
    final pct = TextEditingController(
      text: c == null ? '' : percentText(c.percent),
    );
    var kind = c?.kind ?? ChargeKind.tax;
    var onService = c?.onService ?? false;
    var active = c?.active ?? true;

    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(c == null ? 'Biaya baru' : 'Ubah biaya'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nama (mis. PB1, Service)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ChargeKind>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ChargeKind.tax,
                        label: Text('Pajak'),
                      ),
                      ButtonSegment(
                        value: ChargeKind.service,
                        label: Text('Service'),
                      ),
                    ],
                    selected: {kind},
                    onSelectionChanged: (s) => setS(() => kind = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pct,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Persentase',
                      suffixText: '%',
                    ),
                  ),
                  if (kind == ChargeKind.tax)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dihitung atas subtotal + service'),
                      subtitle: const Text(
                        'Bila mati, pajak hanya dihitung atas subtotal',
                      ),
                      value: onService,
                      onChanged: (v) => setS(() => onService = v),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    subtitle: const Text(
                      'Biaya nonaktif tidak dipakai di order',
                    ),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(direct ? 'Simpan' : 'Ajukan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final n = name.text.trim();
    final p = double.tryParse(pct.text.trim().replaceAll(',', '.'));
    if (n.isEmpty) {
      _toast(context, 'Nama wajib diisi');
      return;
    }
    if (p == null || p < 0 || p > 100) {
      _toast(context, 'Persentase harus 0 sampai 100');
      return;
    }
    if (all.any(
      (x) => x.id != c?.id && x.name.trim().toLowerCase() == n.toLowerCase(),
    )) {
      _toast(context, 'Biaya dengan nama itu sudah ada');
      return;
    }
    final useOnService = kind == ChargeKind.tax && onService;
    try {
      if (direct) {
        await ref
            .read(chargeRepositoryProvider)
            .save(
              Charge(
                id: c?.id ?? const Uuid().v4(),
                name: n,
                kind: kind,
                percent: p,
                onService: useOnService,
                active: active,
              ),
            );
        _toast(context, 'Disimpan');
      } else {
        await submitCharge(
          ref,
          action: c == null ? 'create' : 'update',
          chargeId: c?.id,
          name: n,
          kind: kind.name,
          percent: p,
          onService: useOnService,
          active: active,
        );
        _toast(context, 'Pengajuan dikirim. Menunggu persetujuan owner.');
      }
    } catch (e) {
      _toast(context, errorText(e));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Charge c, {
    required bool direct,
  }) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${c.name}?'),
        content: Text(
          direct
              ? 'Order yang sudah dibayar tidak berubah. Order baru tidak lagi '
                    'memakai biaya ini.'
              : 'Penghapusan dikirim sebagai pengajuan dan baru berlaku setelah '
                    'disetujui owner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(direct ? 'Hapus' : 'Ajukan hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (direct) {
        await ref.read(chargeRepositoryProvider).remove(c.id);
        _toast(context, 'Dihapus');
      } else {
        await submitCharge(ref, action: 'delete', chargeId: c.id);
        _toast(context, 'Pengajuan hapus dikirim. Menunggu persetujuan owner.');
      }
    } catch (e) {
      _toast(context, errorText(e));
    }
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    Charge c, {
    required bool canEdit,
    required bool direct,
    required List<Charge> all,
  }) {
    return Material(
      color: c.active ? AppColors.surface : AppColors.divider,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit
            ? () => _edit(context, ref, c, direct: direct, all: all)
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(
                          c.kindLabel,
                          tone: c.kind == ChargeKind.tax
                              ? Tone.info
                              : Tone.warning,
                        ),
                        StatusPill(
                          c.active ? 'Aktif' : 'Nonaktif',
                          tone: c.active ? Tone.success : Tone.neutral,
                        ),
                        if (c.onService)
                          const StatusPill('Atas subtotal + service'),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${percentText(c.percent)}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref, c, direct: direct),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contoh perhitungan memakai logika yang sama dengan POS.
  Widget _example(List<Charge> charges) {
    final sample = Order(
      id: 'contoh',
      number: '',
      type: OrderType.dineIn,
      createdAt: 0,
      items: const [
        OrderItem(id: '1', menuItemId: '', name: 'Contoh', price: 100000),
      ],
      charges: [
        for (final c in charges)
          if (c.active) c.toLine(),
      ],
    );
    Widget row(String k, int v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            rupiah.format(v),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return SectionCard(
      title: 'Contoh pesanan Rp100.000',
      child: Column(
        children: [
          row('Subtotal', sample.subtotal),
          for (final a in sample.appliedCharges) row(a.line.label, a.amount),
          const Divider(height: 16),
          row('Total', sample.total, bold: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final direct = user?.can('charges.create') ?? false;
    final request = !direct && (user?.can('charges.request') ?? false);
    final canEdit = direct || request;
    final charges = ref.watch(chargesProvider).value ?? const <Charge>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _edit(context, ref, null, direct: direct, all: charges),
              icon: const Icon(Icons.add),
              label: const Text('Biaya'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (request)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perubahan pajak dan biaya layanan dikirim sebagai pengajuan '
                      'dan baru berlaku setelah disetujui owner.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const PendingRequestsCard(type: 'charge'),
          if (charges.isEmpty)
            const EmptyState(
              icon: Icons.percent,
              title: 'Belum ada pajak atau biaya layanan',
              message: 'Order baru tidak dikenai pajak atau service',
            )
          else ...[
            for (final c in charges)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(
                  context,
                  ref,
                  c,
                  canEdit: canEdit,
                  direct: direct,
                  all: charges,
                ),
              ),
            const SizedBox(height: 6),
            _example(charges),
          ],
        ],
      ),
    );
  }
}
