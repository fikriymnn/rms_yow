import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/reason_dialog.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../menu/menu_providers.dart';
import 'menu_proposal.dart';
import 'proposal_editor_page.dart';
import 'proposal_providers.dart';

class ProposalDetailPage extends ConsumerWidget {
  const ProposalDetailPage({super.key, required this.proposalId});
  final String proposalId;

  void _toast(BuildContext c, String m) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    MenuProposal p,
  ) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final r = await formDialog(
      context,
      'Setujui "${p.name}"',
      ['Harga final (Rp)', 'Catatan (opsional)'],
      initial: ['${p.proposedPrice}', ''],
      numeric: {0},
      okLabel: 'Setujui',
      hint: 'Setelah disetujui, menu terbit di semua outlet.',
    );
    if (r == null) return;
    final price = int.tryParse(r[0]) ?? 0;
    if (price <= 0) {
      _toast(context, 'Harga final harus diisi');
      return;
    }
    await ref
        .read(proposalRepositoryProvider)
        .save(
          p.decide(
            status: ProposalStatus.approved,
            finalPrice: price,
            by: user.uid,
            byName: user.name,
            note: r[1],
          ),
        );
    _toast(context, 'Disetujui. Menu terbit di semua outlet setelah sinkron.');
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    MenuProposal p,
  ) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final reason = await askReason(context, 'Alasan penolakan');
    if (reason == null) return;
    await ref
        .read(proposalRepositoryProvider)
        .save(
          p.decide(
            status: ProposalStatus.rejected,
            by: user.uid,
            byName: user.name,
            note: reason,
          ),
        );
    _toast(context, 'Usulan ditolak');
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    MenuProposal p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik usulan ini?'),
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
    if (ok != true) return;
    await ref.read(proposalRepositoryProvider).save(p.withdraw());
    _toast(context, 'Usulan ditarik');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref
        .watch(proposalsProvider)
        .value
        ?.where((x) => x.id == proposalId)
        .firstOrNull;
    if (p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = ref.watch(appUserProvider).value;
    final isOwner = user?.role == AppRole.owner;
    final isMine = user?.uid == p.submittedBy;
    final pending = p.status == ProposalStatus.pending;
    final ings = {
      for (final i in ref.watch(ingredientsProvider).value ?? <Ingredient>[])
        i.id: i,
    };
    final avg = ref.watch(avgCostProvider);
    final live = p.targetId == null
        ? null
        : ref
              .watch(menuMasterProvider)
              .value
              ?.where((m) => m.id == p.targetId)
              .firstOrNull;
    final cost = p.recipe == null ? null : foodCostOf(p.recipe!, avg);
    final fmt = DateFormat('d MMM yyyy HH:mm');
    final th = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget info(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Usulan menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(p.name, style: th.titleLarge),
          Text(p.isChange ? 'Perubahan menu / harga' : 'Menu baru'),
          const SizedBox(height: 12),
          info('Status', p.status.label),
          info(
            'Diajukan oleh',
            '${p.submittedByName} • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(p.createdAt))}',
          ),
          if (p.category.isNotEmpty) info('Kategori', p.category),
          if (p.description.isNotEmpty) info('Deskripsi', p.description),
          if (live != null) info('Harga saat ini', rupiah.format(live.price)),
          info('Harga usulan', rupiah.format(p.proposedPrice)),
          if (p.finalPrice != null)
            info('Harga final', rupiah.format(p.finalPrice)),
          if (p.decidedByName != null)
            info(
              'Diputuskan oleh',
              '${p.decidedByName}${p.decidedAt == null ? '' : ' • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(p.decidedAt!))}'}',
            ),
          if (p.decisionNote.isNotEmpty) info('Catatan', p.decisionNote),
          const Divider(height: 28),
          if (p.recipe == null)
            const Text('Resep tidak diubah pada usulan ini.')
          else ...[
            Text('Resep per porsi', style: th.titleMedium),
            for (final l in p.recipe!)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(ings[l.ingredientId]?.name ?? '(bahan dihapus)'),
                subtitle: avg[l.ingredientId] == null
                    ? Text(
                        'belum ada harga beli',
                        style: TextStyle(color: cs.error),
                      )
                    : null,
                trailing: Text(
                  '${qtyText(l.qty)} ${ings[l.ingredientId]?.unit ?? ''} • ${rupiah.format((l.qty * (avg[l.ingredientId] ?? 0)).round())}',
                ),
              ),
            const Divider(),
            info('Food cost', rupiah.format(cost!.round())),
            info(
              'Margin (harga usulan)',
              '${marginPct(p.proposedPrice, cost)}% • ${rupiah.format((p.proposedPrice - cost).round())}',
            ),
            if (p.finalPrice != null)
              info(
                'Margin (harga final)',
                '${marginPct(p.finalPrice!, cost)}% • ${rupiah.format((p.finalPrice! - cost).round())}',
              ),
          ],
          const SizedBox(height: 20),
          if (pending && isOwner)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context, ref, p),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approve(context, ref, p),
                    child: const Text('Setujui'),
                  ),
                ),
              ],
            ),
          if (pending && !isOwner && isMine)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _withdraw(context, ref, p),
                    child: const Text('Tarik usulan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProposalEditorPage(existing: p),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
