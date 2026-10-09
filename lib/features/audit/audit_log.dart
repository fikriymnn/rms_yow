enum AuditAction {
  voidItem('Void item'),
  cancelOrder('Batal order'),
  refund('Refund'),
  discount('Diskon manual');

  const AuditAction(this.label);
  final String label;
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    required this.reason,
    required this.userId,
    required this.userName,
    required this.at,
    this.orderId = '',
    this.orderNumber = '',
    this.detail = '',
    this.amount = 0,
  });

  final String id;
  final AuditAction action;
  final String reason;
  final String userId;
  final String userName;
  final int at;
  final String orderId;
  final String orderNumber;
  final String detail;
  final int amount;

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
    id: m['id'] as String,
    action: AuditAction.values.firstWhere(
      (e) => e.name == m['action'],
      orElse: () => AuditAction.voidItem,
    ),
    reason: m['reason'] as String? ?? '',
    userId: m['userId'] as String? ?? '',
    userName: m['userName'] as String? ?? '',
    at: (m['at'] as num?)?.toInt() ?? 0,
    orderId: m['orderId'] as String? ?? '',
    orderNumber: m['orderNumber'] as String? ?? '',
    detail: m['detail'] as String? ?? '',
    amount: (m['amount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action.name,
    'reason': reason,
    'userId': userId,
    'userName': userName,
    'at': at,
    'orderId': orderId,
    'orderNumber': orderNumber,
    'detail': detail,
    'amount': amount,
  };
}
