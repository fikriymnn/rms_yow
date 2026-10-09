import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/local_first_repository.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import 'audit_log.dart';

class AuditRepository extends LocalFirstRepository<AuditLog> {
  AuditRepository(super.ref);
  @override
  String get collection => 'audit_logs';
  @override
  AuditLog fromMap(Map<String, dynamic> m) => AuditLog.fromMap(m);
  @override
  Map<String, dynamic> toMap(AuditLog l) => l.toMap();
  @override
  String idOf(AuditLog l) => l.id;

  Future<void> record(
    AuditAction action, {
    required String reason,
    Order? order,
    String detail = '',
    int amount = 0,
  }) {
    final u = ref.read(appUserProvider).value;
    return save(
      AuditLog(
        id: const Uuid().v4(),
        action: action,
        reason: reason,
        userId: u?.uid ?? '',
        userName: u?.name ?? '-',
        at: DateTime.now().millisecondsSinceEpoch,
        orderId: order?.id ?? '',
        orderNumber: order?.number ?? '',
        detail: detail,
        amount: amount,
      ),
    );
  }
}

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref),
);

final auditLogsProvider = StreamProvider<List<AuditLog>>(
  (ref) => ref
      .watch(auditRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.at.compareTo(a.at))),
);
