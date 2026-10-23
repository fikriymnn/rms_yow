import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../auth/auth_providers.dart';
import 'menu_proposal.dart';
import 'proposal_detail_page.dart';
import 'proposal_editor_page.dart';
import 'proposal_providers.dart';

class ProposalsPage extends ConsumerStatefulWidget {
  const ProposalsPage({super.key});
  @override
  ConsumerState<ProposalsPage> createState() => _ProposalsPageState();
}

class _ProposalsPageState extends ConsumerState<ProposalsPage> {
  ProposalStatus? _filter = ProposalStatus.pending;
  static final _fmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(appUserProvider).value?.role == AppRole.owner;
    final all = ref.watch(proposalsProvider).value ?? <MenuProposal>[];
    final list = _filter == null
        ? all
        : all.where((p) => p.status == _filter).toList();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(isOwner ? 'Persetujuan menu' : 'Usulan menu')),
      floatingActionButton: isOwner
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProposalEditorPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Usulan'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final s in ProposalStatus.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _filter == ProposalStatus.pending
                          ? (isOwner
                                ? 'Tidak ada usulan yang menunggu'
                                : 'Belum ada usulan menunggu')
                          : 'Tidak ada usulan',
                    ),
                  )
                : ListView(
                    children: [
                      for (final p in list)
                        ListTile(
                          isThreeLine: true,
                          leading: Icon(
                            p.isChange
                                ? Icons.edit_note
                                : Icons.restaurant_menu,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.isChange ? 'Perubahan menu/harga' : 'Menu baru'} • ${p.submittedByName} • '
                            '${_fmt.format(DateTime.fromMillisecondsSinceEpoch(p.createdAt))}\n'
                            '${rupiah.format(p.proposedPrice)}'
                            '${p.finalPrice == null ? '' : ' → ${rupiah.format(p.finalPrice)}'}',
                          ),
                          trailing: Chip(
                            label: Text(p.status.label),
                            backgroundColor: switch (p.status) {
                              ProposalStatus.approved => Colors.green.shade100,
                              ProposalStatus.rejected => cs.errorContainer,
                              _ => null,
                            },
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProposalDetailPage(proposalId: p.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
