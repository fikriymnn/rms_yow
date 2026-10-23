import '../inventory/inventory_models.dart';

enum ProposalStatus {
  pending('Menunggu'),
  approved('Disetujui'),
  rejected('Ditolak'),
  withdrawn('Ditarik');

  const ProposalStatus(this.label);
  final String label;
}

class MenuProposal {
  const MenuProposal({
    required this.id,
    required this.kind, // 'new' | 'change'
    required this.name,
    required this.proposedPrice,
    required this.submittedBy,
    required this.submittedByName,
    required this.createdAt,
    this.targetId,
    this.category = '',
    this.description = '',
    this.finalPrice,
    this.recipe, // null = resep tidak diubah
    this.status = ProposalStatus.pending,
    this.decidedBy,
    this.decidedByName,
    this.decisionNote = '',
    this.decidedAt,
  });

  final String id;
  final String kind;
  final String? targetId;
  final String name;
  final String category;
  final String description;
  final int proposedPrice;
  final int? finalPrice;
  final List<RecipeLine>? recipe;
  final ProposalStatus status;
  final String submittedBy;
  final String submittedByName;
  final int createdAt;
  final String? decidedBy;
  final String? decidedByName;
  final String decisionNote;
  final int? decidedAt;

  bool get isChange => kind == 'change';

  MenuProposal _copy({
    ProposalStatus? status,
    int? finalPrice,
    String? decidedBy,
    String? decidedByName,
    String? decisionNote,
    int? decidedAt,
  }) => MenuProposal(
    id: id,
    kind: kind,
    targetId: targetId,
    name: name,
    category: category,
    description: description,
    proposedPrice: proposedPrice,
    finalPrice: finalPrice ?? this.finalPrice,
    recipe: recipe,
    status: status ?? this.status,
    submittedBy: submittedBy,
    submittedByName: submittedByName,
    createdAt: createdAt,
    decidedBy: decidedBy ?? this.decidedBy,
    decidedByName: decidedByName ?? this.decidedByName,
    decisionNote: decisionNote ?? this.decisionNote,
    decidedAt: decidedAt ?? this.decidedAt,
  );

  /// Keputusan owner. Server menerbitkan menu sendiri saat status menjadi approved.
  MenuProposal decide({
    required ProposalStatus status,
    int? finalPrice,
    required String by,
    required String byName,
    String note = '',
  }) => _copy(
    status: status,
    finalPrice: finalPrice,
    decidedBy: by,
    decidedByName: byName,
    decisionNote: note,
    decidedAt: DateTime.now().millisecondsSinceEpoch,
  );

  MenuProposal withdraw() => _copy(status: ProposalStatus.withdrawn);

  factory MenuProposal.fromMap(Map<String, dynamic> m) => MenuProposal(
    id: m['id'] as String,
    kind: m['kind'] as String? ?? 'new',
    targetId: m['targetId'] as String?,
    name: m['name'] as String? ?? '',
    category: m['category'] as String? ?? '',
    description: m['description'] as String? ?? '',
    proposedPrice: (m['proposedPrice'] as num?)?.toInt() ?? 0,
    finalPrice: (m['finalPrice'] as num?)?.toInt(),
    recipe: m['recipe'] is List
        ? [
            for (final e in m['recipe'] as List)
              RecipeLine.fromMap(Map<String, dynamic>.from(e as Map)),
          ]
        : null,
    status: ProposalStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => ProposalStatus.pending,
    ),
    submittedBy: m['submittedBy'] as String? ?? '',
    submittedByName: m['submittedByName'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    decidedBy: m['decidedBy'] as String?,
    decidedByName: m['decidedByName'] as String?,
    decisionNote: m['decisionNote'] as String? ?? '',
    decidedAt: (m['decidedAt'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind,
    'targetId': targetId,
    'name': name,
    'category': category,
    'description': description,
    'proposedPrice': proposedPrice,
    'finalPrice': finalPrice,
    'recipe': recipe?.map((l) => l.toMap()).toList(),
    'status': status.name,
    'submittedBy': submittedBy,
    'submittedByName': submittedByName,
    'createdAt': createdAt,
    'decidedBy': decidedBy,
    'decidedByName': decidedByName,
    'decisionNote': decisionNote,
    'decidedAt': decidedAt,
  };
}
