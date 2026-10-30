import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/reason_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../menu/menu_providers.dart';
import '../notifications/mark_read_on_open.dart';
import 'menu_proposal.dart';
import 'proposal_editor_page.dart';
import 'proposal_providers.dart';
import 'proposals_page.dart' show proposalTone;

/// Halaman penuh (HP). Di Tab lanskap dan Web, ProposalDetailView dipakai di panel kanan.
class ProposalDetailPage extends StatelessWidget {
  const ProposalDetailPage({super.key, required this.proposalId});
  final String proposalId;

  @override
  Widget build(BuildContext context) => MarkReadOnOpen(
    type: 'proposal',
    refId: proposalId,
    child: Scaffold(
      appBar: AppBar(title: const Text('Usulan menu')),
      body: ProposalDetailView(proposalId: proposalId),
    ),
  );
}

class ProposalDetailView extends ConsumerWidget {
  const ProposalDetailView({super.key, required this.proposalId});
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
    if (p == null) return const Center(child: CircularProgressIndicator());

    final user = ref.watch(appUserProvider).value;
    final isOwner = user?.can('proposals.decide') ?? false;
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
    String at(int ms) => fmt.format(DateTime.fromMillisecondsSinceEpoch(ms));

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    Widget metric(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );

    final showActions = pending && (isOwner || isMine);

    return Column(
      children: [
        Expanded(
          child: ListView(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.isChange ? 'Perubahan menu / harga' : 'Menu baru',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(p.status.label, tone: proposalTone(p.status)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Informasi',
                child: Column(
                  children: [
                    row(
                      'Diajukan oleh',
                      '${p.submittedByName} • ${at(p.createdAt)}',
                    ),
                    if (p.category.isNotEmpty) row('Kategori', p.category),
                    if (p.description.isNotEmpty)
                      row('Deskripsi', p.description),
                    if (live != null)
                      row('Harga saat ini', rupiah.format(live.price)),
                    row('Harga usulan', rupiah.format(p.proposedPrice)),
                    if (p.finalPrice != null)
                      row('Harga final', rupiah.format(p.finalPrice)),
                    if (p.decidedByName != null)
                      row(
                        'Diputuskan oleh',
                        '${p.decidedByName}${p.decidedAt == null ? '' : ' • ${at(p.decidedAt!)}'}',
                      ),
                    if (p.decisionNote.isNotEmpty)
                      row('Catatan', p.decisionNote),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Resep per porsi',
                child: p.recipe == null
                    ? Text(
                        'Resep tidak diubah pada usulan ini.',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: AppColors.muted,
                        ),
                      )
                    : Column(
                        children: [
                          for (final l in p.recipe!)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ings[l.ingredientId]?.name ??
                                              '(bahan dihapus)',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (avg[l.ingredientId] == null)
                                          Text(
                                            'belum ada harga beli',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.danger,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${qtyText(l.qty)} ${ings[l.ingredientId]?.unit ?? ''} • ${rupiah.format((l.qty * (avg[l.ingredientId] ?? 0)).round())}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              metric('Food cost', rupiah.format(cost!.round())),
                              metric(
                                'Margin usulan',
                                '${marginPct(p.proposedPrice, cost)}%',
                                color: AppColors.primary,
                              ),
                              if (p.finalPrice != null)
                                metric(
                                  'Margin final',
                                  '${marginPct(p.finalPrice!, cost)}%',
                                  color: AppColors.success,
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (showActions)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: isOwner
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
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
                    )
                  : Row(
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
            ),
          ),
      ],
    );
  }
}
