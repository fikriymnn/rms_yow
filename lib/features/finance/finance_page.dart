import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/features/finance/expenses_tab.dart';

import '../auth/auth_providers.dart';
import '../charges/charges_tab.dart';
import '../export/export_tab.dart';
import 'profit_loss_tab.dart';
import 'package:rms_yow/shell/app_bar.dart';

class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCharges =
        ref.watch(appUserProvider).value?.can('charges.read') ?? false;
    final tabs = [
      const Tab(text: 'Laba rugi'),
      const Tab(text: 'Biaya'),
      const Tab(text: 'Ekspor'),
      if (showCharges) const Tab(text: 'Pajak & biaya'),
    ];
    return DefaultTabController(
      key: ValueKey(tabs.length), // jumlah tab berubah bila izin berubah
      length: tabs.length,
      child: Scaffold(
        appBar: RmsAppBar(
          title: const Text('Keuangan'),
          bottom: TabBar(tabs: tabs),
        ),
        body: TabBarView(
          children: [
            const ProfitLossTab(),
            const ExpensesTab(),
            const ExportTab(),
            if (showCharges) const ChargesTab(),
          ],
        ),
      ),
    );
  }
}
