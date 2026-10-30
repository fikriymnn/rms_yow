import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'approval_detail_page.dart';
import 'approval_providers.dart';
import 'approval_ui.dart';
import 'approvals_page.dart';

/// Pengajuan yang masih menunggu: milik sendiri (gudang) atau semuanya (penyetuju).
/// Tersembunyi otomatis bila tidak ada.
class PendingRequestsCard extends ConsumerWidget {
  const PendingRequestsCard({super.key, required this.type, this.maxItems = 5});
  final String type; // supplier | purchase_order | ingredient
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approver =
        ref.watch(appUserProvider).value?.canAny(const [
          'approvals.approve_l1',
          'approvals.approve_final',
        ]) ??
        false;
    final scope = approver ? 'pending' : 'mine';
    final items = (ref.watch(approvalsListProvider(scope)).value ?? [])
        .where((a) => a.type == type && a.isPending)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: 'Pengajuan menunggu persetujuan (${items.length})',
        trailing: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApprovalsPage()),
          ),
          child: const Text('Lihat semua'),
        ),
        child: Column(
          children: [
            for (final a in items.take(maxItems))
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApprovalDetailPage(approvalId: a.id),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(a.typeIcon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${a.requestedByName} • ${a.outletName}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(a.shortStatus, tone: a.tone),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
