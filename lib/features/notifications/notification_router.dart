import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../approvals/approval_detail_page.dart';
import '../kds/kds_page.dart';
import '../proposals/proposal_detail_page.dart';

class NotificationTap {
  const NotificationTap(this.type, this.id);
  final String type;
  final String id;
}

/// Ketukan notifikasi yang menunggu dibuka oleh cangkang aplikasi.
class NotificationTapNotifier extends Notifier<NotificationTap?> {
  @override
  NotificationTap? build() => null;
  void set(NotificationTap? v) => state = v;
}

final notificationTapProvider =
    NotifierProvider<NotificationTapNotifier, NotificationTap?>(
      NotificationTapNotifier.new,
    );

void openNotificationTarget(BuildContext context, NotificationTap tap) {
  final Widget? page = switch (tap.type) {
    'approval' => ApprovalDetailPage(approvalId: tap.id),
    'proposal' => ProposalDetailPage(proposalId: tap.id),
    'order' => const KdsPage(),
    _ => null,
  };
  if (page == null) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
