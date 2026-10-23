class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.type,
    required this.outletName,
    required this.requestedByName,
    required this.title,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.l1ByName,
    this.l1At,
    this.l1Note = '',
    this.ownerByName,
    this.ownerAt,
    this.ownerNote = '',
    this.canApprove = false,
    this.canReject = false,
    this.canWithdraw = false,
  });

  final String id;
  final String type; // purchase_order | supplier
  final String outletName;
  final String requestedByName;
  final String title;
  final Map<String, dynamic> payload;
  final String status;
  final int createdAt;
  final String? l1ByName;
  final int? l1At;
  final String l1Note;
  final String? ownerByName;
  final int? ownerAt;
  final String ownerNote;
  final bool canApprove;
  final bool canReject;
  final bool canWithdraw;

  bool get isPending => status == 'pending_l1' || status == 'pending_owner';

  String get statusLabel => switch (status) {
    'pending_l1' => 'Menunggu manager / head chef',
    'pending_owner' => 'Menunggu owner',
    'approved' => 'Disetujui',
    'rejected' => 'Ditolak',
    'withdrawn' => 'Ditarik',
    _ => status,
  };

  factory ApprovalRequest.fromJson(Map<String, dynamic> m) => ApprovalRequest(
    id: m['id'] as String,
    type: m['type'] as String? ?? '',
    outletName: m['outlet_name'] as String? ?? '',
    requestedByName: m['requested_by_name'] as String? ?? '',
    title: m['title'] as String? ?? '',
    payload: Map<String, dynamic>.from(m['payload'] as Map? ?? {}),
    status: m['status'] as String? ?? '',
    createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
    l1ByName: m['l1_by_name'] as String?,
    l1At: (m['l1_at'] as num?)?.toInt(),
    l1Note: m['l1_note'] as String? ?? '',
    ownerByName: m['owner_by_name'] as String?,
    ownerAt: (m['owner_at'] as num?)?.toInt(),
    ownerNote: m['owner_note'] as String? ?? '',
    canApprove: m['can_approve'] == true,
    canReject: m['can_reject'] == true,
    canWithdraw: m['can_withdraw'] == true,
  );
}

class ApprovalCounts {
  const ApprovalCounts({this.inbox = 0, this.mineOpen = 0});
  final int inbox;
  final int mineOpen;

  @override
  bool operator ==(Object other) =>
      other is ApprovalCounts &&
      other.inbox == inbox &&
      other.mineOpen == mineOpen;
  @override
  int get hashCode => Object.hash(inbox, mineOpen);
}
