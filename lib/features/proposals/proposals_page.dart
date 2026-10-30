import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../notifications/mark_read_on_open.dart';
import 'menu_proposal.dart';
import 'proposal_detail_page.dart';
import 'proposal_editor_page.dart';
import 'proposal_providers.dart';

Tone proposalTone(ProposalStatus s) => switch (s) {
  ProposalStatus.approved => Tone.success,
  ProposalStatus.rejected => Tone.danger,
  ProposalStatus.pending => Tone.warning,
  ProposalStatus.withdrawn => Tone.neutral,
};

class ProposalsPage extends ConsumerStatefulWidget {
  const ProposalsPage({super.key});
  @override
  ConsumerState<ProposalsPage> createState() => _ProposalsPageState();
}

class _ProposalsPageState extends ConsumerState<ProposalsPage> {
  ProposalStatus? _filter = ProposalStatus.pending;
  String? _selected;
  static final _fmt = DateFormat('d MMM yyyy');

  void _open(MenuProposal p, bool wide) {
    if (wide) {
      setState(() => _selected = p.id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProposalDetailPage(proposalId: p.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        ref.watch(appUserProvider).value?.can('proposals.decide') ?? false;
    final all = ref.watch(proposalsProvider).value ?? <MenuProposal>[];
    final list = _filter == null
        ? all
        : all.where((p) => p.status == _filter).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final master = Scaffold(
          appBar: AppBar(
            title: Text(isOwner ? 'Persetujuan menu' : 'Usulan menu'),
          ),
          floatingActionButton: isOwner
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProposalEditorPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Usulan'),
                ),
          body: Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  children: [
                    for (final s in <ProposalStatus?>[
                      null,
                      ...ProposalStatus.values,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s?.label ?? 'Semua'),
                          selected: _filter == s,
                          onSelected: (_) => setState(() => _filter = s),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.lightbulb_outline,
                        title: _filter == ProposalStatus.pending
                            ? (isOwner
                                  ? 'Tidak ada usulan menunggu'
                                  : 'Belum ada usulan menunggu')
                            : 'Tidak ada usulan',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          final selected = wide && p.id == _selected;
                          return Material(
                            color: selected
                                ? AppColors.primarySoft
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _open(p, wide),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        StatusPill(
                                          p.status.label,
                                          tone: proposalTone(p.status),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${p.isChange ? 'Perubahan menu/harga' : 'Menu baru'} • ${p.submittedByName} • ${_fmt.format(DateTime.fromMillisecondsSinceEpoch(p.createdAt))}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${rupiah.format(p.proposedPrice)}${p.finalPrice == null ? '' : '  →  ${rupiah.format(p.finalPrice)}'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
        if (!wide) return master;
        return Row(
          children: [
            SizedBox(width: 400, child: master),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: AppBar(title: const Text('Detail usulan')),
                body: _selected == null
                    ? const EmptyState(
                        icon: Icons.touch_app_outlined,
                        title: 'Pilih usulan',
                        message: 'Rinciannya tampil di sini',
                      )
                    : MarkReadOnOpen(
                        key: ValueKey(_selected),
                        type: 'proposal',
                        refId: _selected,
                        child: ProposalDetailView(proposalId: _selected!),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
