import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/reason_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../notifications/mark_read_on_open.dart';
import 'approval_models.dart';
import 'approval_providers.dart';
import 'approval_ui.dart';
import '../charges/charge_models.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

/// Halaman penuh (HP). Di Tab lanskap dan Web, ApprovalDetailView dipakai langsung di panel kanan.
class ApprovalDetailPage extends StatelessWidget {
  const ApprovalDetailPage({super.key, required this.approvalId});
  final String approvalId;

  @override
  Widget build(BuildContext context) => MarkReadOnOpen(
    type: 'approval',
    refId: approvalId,
    child: Scaffold(
      appBar: RmsAppBar(title: const Text('Detail pengajuan')),
      body: ApprovalDetailView(approvalId: approvalId),
    ),
  );
}

class ApprovalDetailView extends ConsumerWidget {
  const ApprovalDetailView({super.key, required this.approvalId});
  final String approvalId;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    String action, {
    String note = '',
    required String done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await decideApproval(ref, approvalId, action, note: note);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest a,
  ) async {
    final r = await formDialog(context, 'Setujui pengajuan', [
      'Catatan (opsional)',
    ], okLabel: 'Setujui');
    if (r == null || !context.mounted) return;
    await _run(
      context,
      ref,
      'approve',
      note: r[0],
      done: a.status == 'pending_l1'
          ? 'Disetujui. Diteruskan ke owner.'
          : 'Disetujui dan diterapkan.',
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await askReason(context, 'Alasan penolakan');
    if (reason == null || !context.mounted) return;
    await _run(context, ref, 'reject', note: reason, done: 'Pengajuan ditolak');
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik pengajuan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tarik'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, ref, 'withdraw', done: 'Pengajuan ditarik');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalDetailProvider(approvalId));
    return async.when(
      loading: () => const Center(child: AppLoader()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorText(e)),
        ),
      ),
      data: (a) => Column(
        children: [
          Expanded(child: _content(context, a)),
          _actions(context, ref, a),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, ApprovalRequest a) {
    if (!(a.canApprove || a.canReject || a.canWithdraw))
      return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (a.canWithdraw)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _withdraw(context, ref),
                  child: const Text('Tarik pengajuan'),
                ),
              ),
            if (a.canReject)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: () => _reject(context, ref),
                  child: const Text('Tolak'),
                ),
              ),
            if (a.canReject && a.canApprove) const SizedBox(width: 12),
            if (a.canApprove)
              Expanded(
                child: FilledButton(
                  onPressed: () => _approve(context, ref, a),
                  child: const Text('Setujui'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ApprovalRequest a) {
    final fmt = DateFormat('d MMM yyyy HH:mm');
    String t(int? ms) => ms == null
        ? ''
        : ' • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(ms))}';
    final tone = toneColors(Tone.info);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(a.typeIcon, color: tone.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${a.requestedByName} • ${a.outletName}${t(a.createdAt)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusPill(a.shortStatus, tone: a.tone),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(title: 'Alur persetujuan', child: _Timeline(_steps(a, t))),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Rincian',
          child: switch (a.type) {
            'purchase_order' => _po(a),
            'ingredient' => _ingredient(a),
            'charge' => _charge(a),
            _ => _supplier(a),
          },
        ),
      ],
    );
  }

  List<_Step> _steps(ApprovalRequest a, String Function(int?) t) {
    final s = a.status;
    final steps = <_Step>[
      _Step(
        'Diajukan',
        '${a.requestedByName}${t(a.createdAt)}',
        '',
        Tone.success,
        Icons.check_circle,
      ),
    ];
    if (a.l1ByName != null) {
      final rejected = s == 'rejected' && a.ownerByName == null;
      steps.add(
        _Step(
          rejected ? 'Ditolak tingkat 1' : 'Disetujui tingkat 1',
          '${a.l1ByName}${t(a.l1At)}',
          a.l1Note,
          rejected ? Tone.danger : Tone.success,
          rejected ? Icons.cancel : Icons.check_circle,
        ),
      );
    } else if (s == 'pending_l1') {
      steps.add(
        _Step(
          a.statusLabel,
          null,
          '',
          Tone.warning,
          Icons.hourglass_top,
        ),
      );
    }
    if (s == 'withdrawn') {
      steps.add(
        _Step('Ditarik oleh pemohon', null, '', Tone.neutral, Icons.undo),
      );
    } else if (a.ownerByName != null) {
      final rejected = s == 'rejected';
      steps.add(
        _Step(
          rejected ? 'Ditolak owner' : 'Disetujui owner',
          '${a.ownerByName}${t(a.ownerAt)}',
          a.ownerNote,
          rejected ? Tone.danger : Tone.success,
          rejected ? Icons.cancel : Icons.check_circle,
        ),
      );
    } else if (s != 'rejected') {
      final now = s == 'pending_owner';
      steps.add(
        _Step(
          'Menunggu owner',
          null,
          '',
          now ? Tone.warning : Tone.neutral,
          now ? Icons.hourglass_top : Icons.radio_button_unchecked,
        ),
      );
    }
    return steps;
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _po(ApprovalRequest a) {
    final p = a.payload;
    final lines = [
      for (final l in (p['lines'] as List? ?? []))
        Map<String, dynamic>.from(l as Map),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Supplier', '${p['supplierName'] ?? ''}'),
        _row('Nomor PO', '${p['number'] ?? ''}'),
        const Divider(height: 24),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l['name'] ?? l['ingredientId']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${qtyText((l['qty'] as num).toDouble())} ${l['unitLabel'] ?? ''} × ${rupiah.format((l['unitPrice'] as num?) ?? 0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  rupiah.format(
                    (((l['qty'] as num?) ?? 0) *
                            ((l['unitPrice'] as num?) ?? 0))
                        .round(),
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Text(
              'Total',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              rupiah.format((p['total'] as num?) ?? 0),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if ('${p['note'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          _row('Catatan', '${p['note']}'),
        ],
      ],
    );
  }

  Widget _supplier(ApprovalRequest a) {
    final p = a.payload;
    final before = p['before'] as Map?;
    String change(String key) {
      final now = '${p[key] ?? ''}';
      final old = before == null ? null : '${before[key] ?? ''}';
      return old == null || old == now ? now : '$now  (sebelumnya: $old)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          'Jenis',
          p['action'] == 'create' ? 'Supplier baru' : 'Ubah supplier',
        ),
        _row('Nama', change('name')),
        _row('Telepon', change('phone')),
        if ('${p['note'] ?? ''}'.isNotEmpty) _row('Catatan', change('note')),
      ],
    );
  }

  Widget _charge(ApprovalRequest a) {
    final p = a.payload;
    final before = p['before'] as Map?;
    String pct(Object? v) => '${percentText((v as num?) ?? 0)}%';
    String kind(Object? k) => k == 'service' ? 'Service' : 'Pajak';
    String base(Object? on) => on == true ? 'Subtotal + service' : 'Subtotal';
    String status(Object? on) => on == false ? 'Nonaktif' : 'Aktif';
    String change(String now, String? old) =>
        old == null || old == now ? now : '$now  (sebelumnya: $old)';
    final action = p['action'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Jenis', switch (action) {
          'create' => 'Biaya baru',
          'delete' => 'Hapus biaya',
          _ => 'Ubah biaya',
        }),
        _row(
          'Nama',
          change(
            '${p['name'] ?? ''}',
            before == null ? null : '${before['name']}',
          ),
        ),
        _row(
          'Kategori',
          change(kind(p['kind']), before == null ? null : kind(before['kind'])),
        ),
        _row(
          'Persentase',
          change(
            pct(p['percent']),
            before == null ? null : pct(before['percent']),
          ),
        ),
        if (action != 'delete') ...[
          _row(
            'Dihitung atas',
            change(
              base(p['onService']),
              before == null ? null : base(before['onService']),
            ),
          ),
          _row(
            'Status',
            change(
              status(p['active']),
              before == null ? null : status(before['active']),
            ),
          ),
        ],
      ],
    );
  }

  Widget _ingredient(ApprovalRequest a) {
    final p = a.payload;
    final before = p['before'] as Map?;
    String q(Object? v) => qtyText((v as num?)?.toDouble() ?? 0);
    String change(String now, String? old) =>
        old == null || old == now ? now : '$now  (sebelumnya: $old)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Jenis', p['action'] == 'create' ? 'Bahan baru' : 'Ubah bahan'),
        _row(
          'Nama',
          change(
            '${p['name'] ?? ''}',
            before == null ? null : '${before['name']}',
          ),
        ),
        _row('Satuan dasar', '${p['unit'] ?? ''}'),
        _row(
          'Stok minimum',
          change(
            '${q(p['minStock'])} ${p['unit'] ?? ''}',
            before == null
                ? null
                : '${q(before['minStock'])} ${before['unit'] ?? ''}',
          ),
        ),
        if ('${p['buyUnit'] ?? ''}'.isNotEmpty)
          _row(
            'Satuan beli',
            'per ${p['buyUnit']} (= ${q(p['buyFactor'])} ${p['unit']})',
          ),
      ],
    );
  }
}

class _Step {
  const _Step(this.title, this.meta, this.note, this.tone, this.icon);
  final String title;
  final String? meta;
  final String note;
  final Tone tone;
  final IconData icon;
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.steps);
  final List<_Step> steps;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Column(
                  children: [
                    Icon(
                      steps[i].icon,
                      size: 22,
                      color: toneColors(steps[i].tone).fg,
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(width: 2, color: AppColors.border),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (steps[i].meta != null)
                        Text(
                          steps[i].meta!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      if (steps[i].note.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            steps[i].note,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
