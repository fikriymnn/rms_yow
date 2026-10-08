class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.available = true,
    this.description = '',
  });

  final String id;
  final String name;
  final String category;
  final int price; // Rupiah, integer (hindari floating point)
  final bool available;
  final String description;

  MenuItem copyWith({
    String? name,
    String? category,
    int? price,
    bool? available,
    String? description,
  }) =>
      MenuItem(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        available: available ?? this.available,
        description: description ?? this.description,
      );

  factory MenuItem.fromMap(Map<String, dynamic> m) => MenuItem(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        available: m['available'] as bool? ?? true,
        description: m['description'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'available': available,
        'description': description,
      };
}
