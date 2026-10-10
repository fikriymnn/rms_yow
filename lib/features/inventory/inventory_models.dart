double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

enum StockMoveType {
  purchase('Pembelian'),
  sale('Terjual'),
  waste('Waste'),
  opname('Opname'),
  adjust('Koreksi');

  const StockMoveType(this.label);
  final String label;
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    this.unit = 'g',
    this.minStock = 0,
    this.buyUnit = '',
    this.buyFactor = 1,
  });

  final String id;
  final String name;
  final String unit; // satuan dasar: g, ml, pcs
  final double minStock;
  final String buyUnit; // satuan beli, mis. "kg" (kosong = sama dengan dasar)
  final double buyFactor; // 1 satuan beli = ... satuan dasar

  factory Ingredient.fromMap(Map<String, dynamic> m) => Ingredient(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    unit: m['unit'] as String? ?? 'g',
    minStock: _d(m['minStock']),
    buyUnit: m['buyUnit'] as String? ?? '',
    buyFactor: _d(m['buyFactor']) > 0 ? _d(m['buyFactor']) : 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'unit': unit,
    'minStock': minStock,
    'buyUnit': buyUnit,
    'buyFactor': buyFactor,
  };
}

class RecipeLine {
  const RecipeLine({required this.ingredientId, required this.qty});
  final String ingredientId;
  final double qty; // per 1 porsi, dalam satuan dasar

  factory RecipeLine.fromMap(Map<String, dynamic> m) => RecipeLine(
    ingredientId: m['ingredientId'] as String? ?? '',
    qty: _d(m['qty']),
  );

  Map<String, dynamic> toMap() => {'ingredientId': ingredientId, 'qty': qty};
}

class Recipe {
  const Recipe({required this.id, this.lines = const []});
  final String id; // = id menu
  final List<RecipeLine> lines;

  factory Recipe.fromMap(Map<String, dynamic> m) => Recipe(
    id: m['id'] as String,
    lines: [
      for (final e in (m['lines'] as List? ?? []))
        RecipeLine.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'lines': [for (final l in lines) l.toMap()],
  };
}

class StockMove {
  const StockMove({
    required this.id,
    required this.ingredientId,
    required this.type,
    required this.qty,
    required this.at,
    this.unitCost,
    this.orderId = '',
    this.note = '',
    this.userName = '',
  });

  final String id;
  final String ingredientId;
  final StockMoveType type;
  final double qty; // + masuk, - keluar (satuan dasar)
  final int at;
  final double? unitCost; // harga per satuan dasar (khusus pembelian)
  final String orderId;
  final String note;
  final String userName;

  factory StockMove.fromMap(Map<String, dynamic> m) => StockMove(
    id: m['id'] as String,
    ingredientId: m['ingredientId'] as String? ?? '',
    type: StockMoveType.values.firstWhere(
      (e) => e.name == m['type'],
      orElse: () => StockMoveType.adjust,
    ),
    qty: _d(m['qty']),
    at: (m['at'] as num?)?.toInt() ?? 0,
    unitCost: (m['unitCost'] as num?)?.toDouble(),
    orderId: m['orderId'] as String? ?? '',
    note: m['note'] as String? ?? '',
    userName: m['userName'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'ingredientId': ingredientId,
    'type': type.name,
    'qty': qty,
    'at': at,
    'unitCost': unitCost,
    'orderId': orderId,
    'note': note,
    'userName': userName,
  };
}
