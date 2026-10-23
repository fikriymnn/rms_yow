import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../purchasing/purchasing_page.dart';
import 'ingredients_tab.dart';
import 'recipes_tab.dart';
import 'stock_tab.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(appUserProvider).value?.role;
    final showRecipes =
        role == AppRole.owner ||
        role == AppRole.manager ||
        role == AppRole.head_chef;

    return DefaultTabController(
      length: showRecipes ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory'),
          actions: [
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
