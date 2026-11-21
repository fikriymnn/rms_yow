import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../purchasing/purchasing_page.dart';
import 'ingredients_tab.dart';
import 'recipes_tab.dart';
import 'stock_history_page.dart';
import 'stock_tab.dart';
import 'package:rms_yow/shell/app_bar.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final showRecipes = user?.can('recipes.read') ?? false;
    // modul Pembelian dimatikan -> izinnya dicabut -> tombol Pembelian hilang
    final showPurchasing =
        user?.canAny(const ['purchase_orders.read', 'suppliers.read', 'goods_receipts.read']) ?? false;

    return DefaultTabController(
      length: showRecipes ? 3 : 2,
      child: Scaffold(
        appBar: RmsAppBar(
          title: const Text('Inventory'),
          actions: [
            IconButton(
              tooltip: 'Riwayat stok',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockHistoryPage()),
              ),
            ),
            if (showPurchasing)
            IconButton(
              tooltip: 'Pembelian',
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchasingPage()),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Stok'),
              const Tab(text: 'Bahan'),
              if (showRecipes) const Tab(text: 'Resep'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const StockTab(),
            const IngredientsTab(),
            if (showRecipes) const RecipesTab(),
          ],
        ),
      ),
    );
  }
}
