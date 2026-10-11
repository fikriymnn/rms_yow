import 'package:flutter/material.dart';
import 'package:rms_yow/features/finance/expenses_tab.dart';

import '../export/export_tab.dart';
import 'profit_loss_tab.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Laba rugi'),
            Tab(text: 'Biaya'),
            Tab(text: 'Ekspor'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [ProfitLossTab(), ExpensesTab(), ExportTab()],
      ),
    ),
  );
}
