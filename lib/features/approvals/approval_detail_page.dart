import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/reason_dialog.dart';
import 'approval_models.dart';
import 'approval_providers.dart';

class ApprovalDetailPage extends ConsumerWidget {
  const ApprovalDetailPage({super.key, required this.approvalId});
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
    final ok = await showDialog<bool>(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Detail pengajuan')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (a) => _body(context, ref, a),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ApprovalRequest a) {
    final fmt = DateFormat('d MMM yyyy HH:mm');
    String t(int? ms) => ms == null
        ? ''
        : ' • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(ms))}';
    final th = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );

    final p = a.payload;
    final children = <Widget>[
      Text(a.title, style: th.titleMedium),
      const SizedBox(height: 4),
      Chip(
        label: Text(a.statusLabel),
        backgroundColor: switch (a.status) {
          'approved' => Colors.green.shade100,
          'rejected' => cs.errorContainer,
          _ => null,
        },
      ),
      const Divider(),
      row(
        'Diajukan oleh',
        '${a.requestedByName} (${a.outletName})${t(a.createdAt)}',
      ),
      if (a.l1ByName != null)
        row(
          'Tingkat 1',
          '${a.l1ByName}${t(a.l1At)}${a.l1Note.isEmpty ? '' : '\n${a.l1Note}'}',
        ),
      if (a.ownerByName != null)
        row(
          'Owner',
          '${a.ownerByName}${t(a.ownerAt)}${a.ownerNote.isEmpty ? '' : '\n${a.ownerNote}'}',
        ),
      const Divider(),
    ];

    if (a.type == 'purchase_order') {
      final lines = [
        for (final l in (p['lines'] as List? ?? []))
          Map<String, dynamic>.from(l as Map),
      ];
      children.addAll([
        row('Supplier', '${p['supplierName'] ?? ''}'),
        row('Nomor PO', '${p['number'] ?? ''}'),
        const SizedBox(height: 8),
        Text('Item', style: th.titleSmall),
        for (final l in lines)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${l['name'] ?? l['ingredientId']}'),
            subtitle: Text(
              '${qtyText((l['qty'] as num).toDouble())} ${l['unitLabel'] ?? ''} × ${rupiah.format((l['unitPrice'] as num?) ?? 0)}',
            ),
            trailing: Text(
              rupiah.format(
                (((l['qty'] as num?) ?? 0) * ((l['unitPrice'] as num?) ?? 0))
                    .round(),
              ),
            ),
          ),
        const Divider(),
        row('Total', rupiah.format((p['total'] as num?) ?? 0)),
        if ('${p['note'] ?? ''}'.isNotEmpty) row('Catatan', '${p['note']}'),
      ]);
    } else {
      final before = p['before'] as Map?;
      children.addAll([
        row(
          'Jenis',
          p['action'] == 'create' ? 'Supplier baru' : 'Ubah supplier',
        ),
        row(
          'Nama',
          '${p['name'] ?? ''}${before == null ? '' : '  (sebelumnya: ${before['name']})'}',
        ),
        row(
          'Telepon',
          '${p['phone'] ?? ''}${before == null ? '' : '  (sebelumnya: ${before['phone']})'}',
        ),
        if ('${p['note'] ?? ''}'.isNotEmpty) row('Catatan', '${p['note']}'),
      ]);
    }

    children.add(const SizedBox(height: 20));
    if (a.canApprove || a.canReject) {
      children.add(
        Row(
          children: [
            if (a.canReject)
              Expanded(
                child: OutlinedButton(
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
      );
    }
    if (a.canWithdraw) {
      children.add(
        OutlinedButton(
          onPressed: () => _withdraw(context, ref),
          child: const Text('Tarik pengajuan'),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}
