import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/sync/sync_controller.dart';
import '../auth/auth_providers.dart';
import 'approval_models.dart';

const _approvalRoles = {
  AppRole.owner,
  AppRole.manager,
  AppRole.head_chef,
  AppRole.warehouse,
};

/// Jumlah di kotak masuk dan pengajuan terbuka, disegarkan tiap 20 detik.
final approvalCountsProvider = StreamProvider<ApprovalCounts>((ref) async* {
  final session = ref.watch(sessionProvider).value;
  if (session == null || !_approvalRoles.contains(session.user.role)) {
    yield const ApprovalCounts();
    return;
  }
  var last = const ApprovalCounts();
  while (true) {
    try {
      final m =
          await ref.read(apiClientProvider).get('/approvals/counts')
              as Map<String, dynamic>;
      last = ApprovalCounts(
        inbox: (m['inbox'] as num).toInt(),
        mineOpen: (m['mine_open'] as num).toInt(),
      );
    } catch (_) {
      /* offline: pakai angka terakhir */
    }
    yield last;
    await Future<void>.delayed(const Duration(seconds: 20));
  }
});

final approvalsListProvider = FutureProvider.autoDispose
    .family<List<ApprovalRequest>, String>((ref, scope) async {
      ref.watch(approvalCountsProvider); // muat ulang saat angka berubah
      final data =
          await ref
                  .read(apiClientProvider)
                  .get('/approvals', query: {'scope': scope, 'limit': 100})
              as List<dynamic>;
      return [
        for (final m in data)
          ApprovalRequest.fromJson(m as Map<String, dynamic>),
      ];
    });

final approvalDetailProvider = FutureProvider.autoDispose
    .family<ApprovalRequest, String>((ref, id) async {
      ref.watch(approvalCountsProvider);
      final m =
          await ref.read(apiClientProvider).get('/approvals/$id')
              as Map<String, dynamic>;
      return ApprovalRequest.fromJson(m);
    });

void _refresh(WidgetRef ref) {
  ref.invalidate(approvalsListProvider);
  ref.invalidate(approvalDetailProvider);
  ref.invalidate(approvalCountsProvider);
}

/// Aksi: approve | reject | withdraw
Future<ApprovalRequest> decideApproval(
  WidgetRef ref,
  String id,
  String action, {
  String note = '',
}) async {
  final m =
      await ref
              .read(apiClientProvider)
              .post('/approvals/$id/$action', data: {'note': note})
          as Map<String, dynamic>;
  _refresh(ref);
  return ApprovalRequest.fromJson(m);
}

/// Tunggu sampai dokumen lokal sudah terkirim ke server (maks. ±12 detik).
Future<bool> waitUntilSynced(
  WidgetRef ref,
  String collection,
  String id,
) async {
  final db = ref.read(databaseProvider);
  for (var i = 0; i < 12; i++) {
    final row = await db.find(collection, id);
    if (row != null && !row.dirty) return true;
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

Future<ApprovalRequest> submitPurchaseOrder(WidgetRef ref, String poId) async {
  if (!await waitUntilSynced(ref, 'purchase_orders', poId)) {
    throw ApiException(
      null,
      'Draf PO belum tersinkron ke server. Periksa koneksi lalu coba lagi.',
    );
  }
  final m =
      await ref
              .read(apiClientProvider)
              .post(
                '/approvals',
                data: {'type': 'purchase_order', 'ref_id': poId},
              )
          as Map<String, dynamic>;
  _refresh(ref);
  return ApprovalRequest.fromJson(m);
}

Future<ApprovalRequest> submitSupplier(
  WidgetRef ref, {
  required String action, // create | update
  String? supplierId,
  required String name,
  String phone = '',
  String note = '',
}) async {
  final m =
      await ref
              .read(apiClientProvider)
              .post(
                '/approvals',
                data: {
                  'type': 'supplier',
                  'supplier': {
                    'action': action,
                    'supplier_id': supplierId,
                    'name': name,
                    'phone': phone,
                    'note': note,
                  },
                },
              )
          as Map<String, dynamic>;
  _refresh(ref);
  return ApprovalRequest.fromJson(m);
}
