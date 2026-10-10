import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import 'expense.dart';

class ExpenseRepository extends LocalFirstRepository<Expense> {
  ExpenseRepository(super.ref);
  @override
  String get collection => 'expenses';
  @override
  Expense fromMap(Map<String, dynamic> m) => Expense.fromMap(m);
  @override
  Map<String, dynamic> toMap(Expense e) => e.toMap();
  @override
  String idOf(Expense e) => e.id;
}

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref),
);

final expensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref
      .watch(expenseRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.at.compareTo(a.at))),
);
