import 'package:flutter/material.dart';

import '../purchasing/purchasing_page.dart';
import 'ingredients_tab.dart';
import 'recipes_tab.dart';
import 'stock_tab.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
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
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Stok'),
            Tab(text: 'Bahan'),
            Tab(text: 'Resep'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [StockTab(), IngredientsTab(), RecipesTab()],
      ),
    ),
  );
}
