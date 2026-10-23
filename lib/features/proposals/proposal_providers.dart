import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import 'menu_proposal.dart';

class ProposalRepository extends LocalFirstRepository<MenuProposal> {
  ProposalRepository(super.ref);
  @override
  String get collection => 'menu_proposals';
  @override
  MenuProposal fromMap(Map<String, dynamic> m) => MenuProposal.fromMap(m);
  @override
  Map<String, dynamic> toMap(MenuProposal p) => p.toMap();
  @override
  String idOf(MenuProposal p) => p.id;
}

final proposalRepositoryProvider = Provider<ProposalRepository>(
  (ref) => ProposalRepository(ref),
);

final proposalsProvider = StreamProvider<List<MenuProposal>>(
  (ref) => ref
      .watch(proposalRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
);

/// Jumlah usulan menunggu (penanda di navigasi); hanya untuk owner.
final pendingProposalsCountProvider = Provider<int>((ref) {
  final role = ref.watch(appUserProvider).value?.role;
  if (role != AppRole.owner) return 0;
  return (ref.watch(proposalsProvider).value ?? <MenuProposal>[])
      .where((p) => p.status == ProposalStatus.pending)
      .length;
});

double foodCostOf(List<RecipeLine> lines, Map<String, double> avgCost) =>
    lines.fold(0.0, (s, l) => s + l.qty * (avgCost[l.ingredientId] ?? 0));

int marginPct(int price, double cost) =>
    price > 0 ? ((price - cost) / price * 100).round() : 0;
