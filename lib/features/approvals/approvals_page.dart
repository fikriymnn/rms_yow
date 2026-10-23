import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_providers.dart';
import 'approval_detail_page.dart';
import 'approval_models.dart';
import 'approval_providers.dart';

class ApprovalsPage extends ConsumerWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(appUserProvider).value?.role;
    final isApprover =
        role == AppRole.owner ||
        role == AppRole.manager ||
        role == AppRole.head_chef;
    final tabs = <(String, String)>[
      if (isApprover) ('Menunggu saya', 'inbox'),
      if (role != AppRole.owner) ('Pengajuan saya', 'mine'),
      if (isApprover) ('Riwayat', 'history'),
    ];
    if (tabs.isEmpty)
      return const Scaffold(body: Center(child: Text('Tidak tersedia')));

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Persetujuan'),
          bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        ),
        body: TabBarView(
          children: [for (final t in tabs) _ApprovalList(scope: t.$2)],
        ),
      ),
    );
  }
}

class _ApprovalList extends ConsumerWidget {
  const _ApprovalList({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalsListProvider(scope));
    final fmt = DateFormat('d MMM yyyy HH:mm');
    final cs = Theme.of(context).colorScheme;

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
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(switch (scope) {
                        'inbox' => 'Tidak ada yang menunggu persetujuan Anda',
                        'mine' => 'Belum ada pengajuan',
                        _ => 'Belum ada riwayat',
                      }),
                    ),
                  ),
                ],
              )
            : ListView(
                children: [
                  for (final a in list)
                    ListTile(
                      isThreeLine: true,
                      leading: Icon(
                        a.type == 'purchase_order'
                            ? Icons.shopping_cart_outlined
                            : Icons.local_shipping_outlined,
                      ),
                      title: Text(a.title),
                      subtitle: Text(
                        '${a.requestedByName} • ${a.outletName} • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(a.createdAt))}\n${a.statusLabel}',
                      ),
                      trailing: Icon(switch (a.status) {
                        'approved' => Icons.check_circle_outline,
                        'rejected' => Icons.cancel_outlined,
                        'withdrawn' => Icons.undo,
                        _ => Icons.hourglass_top,
                      }, color: a.status == 'rejected' ? cs.error : null),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApprovalDetailPage(approvalId: a.id),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
