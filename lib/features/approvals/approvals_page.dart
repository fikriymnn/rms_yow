import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../notifications/mark_read_on_open.dart';
import 'approval_detail_page.dart';
import 'approval_models.dart';
import 'approval_providers.dart';
import 'approval_ui.dart';

class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key});
  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  String? _selected;

  void _open(ApprovalRequest a, bool wide) {
    if (wide) {
      setState(() => _selected = a.id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApprovalDetailPage(approvalId: a.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final isApprover =
        user?.canAny(const [
          'approvals.approve_l1',
          'approvals.approve_final',
        ]) ??
        false;
    final tabs = <(String, String)>[
      if (isApprover) ('Menunggu saya', 'inbox'),
      if (user?.can('approvals.create') ?? false) ('Pengajuan saya', 'mine'),
      if (isApprover) ('Semua menunggu', 'pending'),
      if (isApprover) ('Riwayat', 'history'),
    ];
    if (tabs.isEmpty)
      return const Scaffold(body: Center(child: Text('Tidak tersedia')));

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final list = DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Persetujuan'),
              bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
            ),
            body: TabBarView(
              children: [
                for (final t in tabs)
                  _ApprovalList(
                    scope: t.$2,
                    selectedId: wide ? _selected : null,
                    onOpen: (a) => _open(a, wide),
                  ),
              ],
            ),
          ),
        );
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: 400, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: AppBar(title: const Text('Detail pengajuan')),
                body: _selected == null
                    ? const EmptyState(
                        icon: Icons.touch_app_outlined,
                        title: 'Pilih pengajuan',
                        message: 'Rinciannya tampil di sini',
                      )
                    : MarkReadOnOpen(
                        key: ValueKey(_selected),
                        type: 'approval',
                        refId: _selected,
                        child: ApprovalDetailView(approvalId: _selected!),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApprovalList extends ConsumerWidget {
  const _ApprovalList({
    required this.scope,
    required this.selectedId,
    required this.onOpen,
  });
  final String scope;
  final String? selectedId;
  final ValueChanged<ApprovalRequest> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalsListProvider(scope));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(approvalsListProvider(scope));
        await ref.read(approvalsListProvider(scope).future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat. Tarik ke bawah untuk mencoba lagi.\n$e',
              ),
            ),
          ],
        ),
        data: (list) => list.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.inbox_outlined,
                    title: switch (scope) {
                      'inbox' => 'Tidak ada yang menunggu Anda',
                      'mine' => 'Belum ada pengajuan',
                      'pending' => 'Tidak ada pengajuan yang menunggu',
                      _ => 'Belum ada riwayat',
                    },
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ApprovalTile(
                  a: list[i],
                  selected: list[i].id == selectedId,
                  onTap: () => onOpen(list[i]),
                ),
              ),
      ),
    );
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.a,
    required this.selected,
    required this.onTap,
  });
  final ApprovalRequest a;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM HH:mm');
    final tone = toneColors(Tone.info);
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.typeIcon, size: 20, color: tone.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.requestedByName} • ${a.outletName} • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(a.createdAt))}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(a.shortStatus, tone: a.tone),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
